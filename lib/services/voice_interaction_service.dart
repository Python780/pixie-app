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
    // FIX 1: Only reset sound level and fire callback if we were actually listening.
    // Previously this fired onSoundLevelChange even on the early-return path,
    // causing unexpected UI updates when already stopped.
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
      // Small cooldown to allow native hardware resources to recycle cleanly.
      await Future.delayed(const Duration(milliseconds: 300));

      // FIX 2: Initialize lastWordDetectedAt AFTER the cooldown delay so the
      // 2-second inactivity clock doesn't start 300ms early.
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

          // If the native engine says it's done, we MUST close our loop,
          // regardless of whether the text is empty or valid.
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
        pauseFor: const Duration(seconds: 4), // Native silence cutoff threshold
        listenFor: Duration(seconds: maxDurationSeconds),
      );

      // Monitoring Safety Loop
      int loopCounter = 0;
      // FIX 3: Guard against maxDurationSeconds == 0 producing a zero maxLoops,
      // which would trigger the force-stop on the very first iteration.
      final int maxLoops = math.max(1, (maxDurationSeconds * 1000) ~/ 200);

      while (isListening) {
        await Future.delayed(const Duration(milliseconds: 200));
        loopCounter++;

        // Smart Text Inactivity Timeout (2000ms):
        // If the user has spoken, wait 2 seconds after their last word before
        // closing the microphone, so we don't cut them off mid-sentence.
        if (_currentInput.trim().isNotEmpty) {
          final msSinceLastWord = DateTime.now()
              .difference(lastWordDetectedAt)
              .inMilliseconds;
          if (msSinceLastWord >= 2000) {
            dev.log(
              "🤫 2s speech finish gap detected. Closing microphone early.",
            );
            await stopListening();
            break;
          }
        }

        // Global fallback safety constraint loop.
        if (loopCounter > maxLoops) {
          dev.log("⚠️ Force stop loop guard triggered");
          await stopListening();
          break;
        }
      }

      // Strip out low-amplitude junk, background whispers, or accidental static.
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

  // FIX 4: Made async and awaited stopListening() so sound-level reset and
  // onSoundLevelChange callback are guaranteed to complete before the caller
  // continues. Previously fire-and-forget could leave stale UI state.
  Future<void> endConversation() async {
    _currentInput = "";
    await stopListening();
    dev.log("👋 Conversation ended");
  }
}
