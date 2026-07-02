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
    if (!isListening) return;

    await super.stopListening();
    _currentSoundLevel = 0.0;
    onSoundLevelChange?.call(normalizedSoundLevel);
  }

  Future<String> listenForInput({int maxDurationSeconds = 15}) async {
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

    Timer? timeoutTimer;

    try {
      // Reduced cooldown: 300ms -> 80ms. Speech_to_text on most modern
      // devices handles back-to-back listen() calls fine with a minimal gap;
      // the longer delay was adding cumulative latency every single turn.
      await Future.delayed(const Duration(milliseconds: 80));

      DateTime lastWordDetectedAt = DateTime.now();

      isListening = true;
      dev.log("🎤 Conversation listening START (Max: ${maxDurationSeconds}s)");

      timeoutTimer = Timer(Duration(seconds: maxDurationSeconds), () {
        if (isListening) {
          dev.log("⏱️ Hard timeout reached; stopping listener");
          stopListening();
        }
      });

      await stt.listen(
        onResult: (result) async {
          final String newWords = result.recognizedWords.trim();

          if (newWords != _currentInput.trim() && newWords.isNotEmpty) {
            lastWordDetectedAt = DateTime.now();
          }

          _currentInput = result.recognizedWords;
          dev.log(
            "🎤 User said: $_currentInput"
            " [final=${result.finalResult} confidence=${result.confidence}]",
          );

          if (result.finalResult) {
            dev.log("🏁 Native engine finalized session channel.");
            await stopListening();
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
        pauseFor: const Duration(seconds: 4),
        listenFor: Duration(seconds: maxDurationSeconds),
      );

      // Monitoring Safety Loop
      int loopCounter = 0;
      final int maxLoops = math.max(1, (maxDurationSeconds * 1000) ~/ 150);

      while (isListening) {
        // Tighter poll interval: 200ms -> 150ms for quicker reaction to
        // both the inactivity gap and the loop guard.
        await Future.delayed(const Duration(milliseconds: 150));
        loopCounter++;

        // Reduced inactivity gap: 2000ms -> 1200ms. Still long enough to
        // avoid cutting someone off mid-sentence, but noticeably snappier
        // for the common case of short, complete answers.
        if (_currentInput.trim().isNotEmpty) {
          final msSinceLastWord = DateTime.now()
              .difference(lastWordDetectedAt)
              .inMilliseconds;
          if (msSinceLastWord >= 1200) {
            dev.log(
              "🤫 Speech finish gap detected. Closing microphone early.",
            );
            await stopListening();
            break;
          }
        }

        if (loopCounter > maxLoops) {
          dev.log("⚠️ Force stop loop guard triggered");
          await stopListening();
          break;
        }
      }

      if (_currentInput.trim().isNotEmpty && _maxSoundLevel < _minSpeechLevel) {
        dev.log(
          "🗑️ Discarding payload: Sound levels too faint "
          "(${_maxSoundLevel.toStringAsFixed(1)} dB)",
        );
        return "";
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

  Future<void> endConversation() async {
    _currentInput = "";
    await stopListening();
    dev.log("👋 Conversation ended");
  }
}