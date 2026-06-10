import 'dart:async';
import 'dart:developer' as dev;
import 'dart:math' as math;
import 'package:speech_to_text/speech_to_text.dart';
import 'base_voice_service.dart';

class PixieVoiceInteractionService extends BaseVoiceService {
  String _currentInput = "";
  double _maxSoundLevel = 0.0;
  double _currentSoundLevel = 0.0;
  static const double _minSpeechLevel = 4.0;
  static const double _maxDisplaySoundLevel = 8.0;

  void Function(double)? onSoundLevelChange;

  double get currentSoundLevel => _currentSoundLevel;
  double get normalizedSoundLevel =>
      (_currentSoundLevel / _maxDisplaySoundLevel).clamp(0.0, 1.0);

  @override
  Future<void> stopListening() async {
    if (!isListening) {
      _currentSoundLevel = 0.0;
      onSoundLevelChange?.call(normalizedSoundLevel);
      return;
    }

    await super.stopListening();
    _currentSoundLevel = 0.0;
    onSoundLevelChange?.call(normalizedSoundLevel);
  }

  Future<String> listenForInput({int maxDurationSeconds = 10}) async {
    if (isListening) {
      await stopListening();
      return "";
    }

    bool available = await initSpeech();
    if (!available) {
      return "";
    }

    _currentInput = "";
    _currentSoundLevel = 0.0;
    _maxSoundLevel = 0.0;
    onSoundLevelChange?.call(normalizedSoundLevel);

    // NEW: Timestamps to track when the user *actually* stopped adding new words
    DateTime lastWordDetectedAt = DateTime.now();
    
    Timer? timeoutTimer;
    try {
      await Future.delayed(const Duration(milliseconds: 300));

      isListening = true;
      dev.log("🎤 Conversation listening START");

      timeoutTimer = Timer(Duration(seconds: maxDurationSeconds), () {
        if (isListening) {
          dev.log("⏱️ Hard timeout reached; stopping listener");
          stopListening();
        }
      });

      await stt.listen(
        onResult: (result) async {
          final String newWords = result.recognizedWords.trim();
          
          // NEW: If the text changed, update our timestamp. 
          // This proves the user is actively talking, not just ambient static.
          if (newWords != _currentInput.trim() && newWords.isNotEmpty) {
            lastWordDetectedAt = DateTime.now();
          }

          _currentInput = result.recognizedWords;
          dev.log(
            "🎤 User said: $_currentInput"
            " [final=${result.finalResult} confidence=${result.confidence}]",
          );

          if (result.finalResult) {
            final bool loudEnough = _maxSoundLevel >= _minSpeechLevel;
            final bool confidentEnough = result.confidence > 0.5;
            if (_currentInput.trim().isNotEmpty && (loudEnough || confidentEnough)) {
              dev.log("✅ Final result received and accepted");
              await stopListening();
            }
          }
        },
        onSoundLevelChange: (level) {
          _currentSoundLevel = level;
          _maxSoundLevel = math.max(_maxSoundLevel, level);
          onSoundLevelChange?.call(normalizedSoundLevel);
        },
        listenMode: ListenMode.dictation,
        partialResults: true,
        cancelOnError: false,
        // CHANGED: Reduced from 5s to 2s. If the OS detects silence, cut off faster.
        pauseFor: const Duration(seconds: 2), 
        listenFor: Duration(seconds: maxDurationSeconds),
      );

      // CHANGED: Smarter polling check inside the safety loop
      int loopCounter = 0;
      while (isListening) {
        await Future.delayed(const Duration(milliseconds: 200));
        loopCounter++;

        // NEW: Check for text silence. If 1.5 seconds pass without new words 
        // AND we have captured some input, manually cut it off.
        if (_currentInput.trim().isNotEmpty) {
          final msSinceLastWord = DateTime.now().difference(lastWordDetectedAt).inMilliseconds;
          if (msSinceLastWord >= 1500) {
            dev.log("🤫 Text inactivity detected (${msSinceLastWord}ms). Closing microphone early.");
            await stopListening();
            break;
          }
        }

        // Global fallback safety (approx 15 seconds)
        if (loopCounter > 75) {
          dev.log("⚠️ Force stop loop guard triggered");
          await stopListening();
          break;
        }
      }

      return _currentInput;
    } catch (e) {
      dev.log("Conversation listening failed: $e");
      isListening = false;
      return "";
    } finally {
      timeoutTimer?.cancel();
    }
  }

  void endConversation() {
    _currentInput = "";
    stopListening();
    dev.log("👋 Conversation ended");
  }
}