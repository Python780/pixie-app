import 'dart:developer' as dev;
import 'package:flutter/foundation.dart' show VoidCallback;
import 'package:speech_to_text/speech_to_text.dart';
import 'base_voice_service.dart';
import 'pixie_speech_service.dart';

class PixieVoiceTriggerService extends BaseVoiceService {
  double _currentSoundLevel = 0.0;
  // Sound level threshold is device-dependent; prefer a lower threshold
  // and also accept final results or reasonable confidence levels.
  static const double _wakeWordMinLevel = 0.4;

  bool _shouldKeepListening = false;
  VoidCallback? _onWakeWordCallback;
  bool _wakeWordFired = false;
  VoidCallback? _unregisterStatusListener;

  /// Starts continuous wake word detection. The mic stays effectively
  /// "always on" because every time the underlying speech recognizer
  /// naturally stops (silence timeout, OS cutoff, etc.) this service
  /// automatically restarts it, triggered via PixieSpeechService's shared
  /// status listener fan-out (since speech_to_text only allows a single
  /// onStatus callback set once at initialize() time).
  ///
  /// Call [stopListening] to fully disable continuous monitoring.
  Future<void> startWakeWordListening(VoidCallback onWakeWord) async {
    _onWakeWordCallback = onWakeWord;
    _shouldKeepListening = true;
    _wakeWordFired = false;

    // Register for STT status updates once per session start.
    _unregisterStatusListener?.call();
    _unregisterStatusListener =
        PixieSpeechService().addStatusListener(_handleStatusChange);

    if (isListening) {
      dev.log("👂 Wake word listening already active — skipping duplicate start.");
      return;
    }

    await _beginListenSession();
  }

  void _handleStatusChange(String status) {
    if (!_shouldKeepListening || _wakeWordFired) return;

    if (status == 'done' || status == 'notListening') {
      isListening = false;
      // Tiny delay avoids hammering the platform channel back-to-back.
      Future.delayed(const Duration(milliseconds: 150), () {
        if (_shouldKeepListening && !_wakeWordFired) {
          _beginListenSession();
        }
      });
    }
  }

  Future<void> _beginListenSession() async {
    if (!_shouldKeepListening) return;
    if (isListening) return; // Already running a session, don't double-start

    bool available = await initSpeech();
    if (!available) {
      dev.log("STT unavailable");
      isListening = false;
      return;
    }

    try {
      isListening = true;
      dev.log("👂 Wake word listening session (re)started");

      await stt.listen(
        onResult: (result) async {
          if (_wakeWordFired) return; // Already triggered, ignore stray results

          String words = result.recognizedWords.toLowerCase();
          final confidence = result.confidence;

          dev.log(
            "🎤 Heard: $words "
            "[final=${result.finalResult} confidence=${confidence.toStringAsFixed(2)} soundLevel=${_currentSoundLevel.toStringAsFixed(2)}]",
          );

          final bool trusted =
              result.finalResult ||
              (confidence > 0.45) ||
              _currentSoundLevel >= _wakeWordMinLevel;

          if (words.contains('hi pixie') && trusted) {
            dev.log("🎯 Wake word detected!");
            _wakeWordFired = true;
            await _stopCurrentSession();
            // Short handoff gap — listenForInput() in the conversation
            // service already adds its own short cooldown before calling
            // stt.listen() again, so we don't need to double up here.
            await Future.delayed(const Duration(milliseconds: 150));
            _onWakeWordCallback?.call();
          }
        },
        onSoundLevelChange: (level) {
          _currentSoundLevel = level;
        },
        listenMode: ListenMode.confirmation,
        partialResults: true,
        cancelOnError: false,
        pauseFor: const Duration(seconds: 8),
        listenFor: const Duration(seconds: 55),
      );
    } catch (e) {
      dev.log("Wake word listening failed: $e");
      isListening = false;
      // Even on failure, try to recover after a short delay rather than dying silently.
      if (_shouldKeepListening) {
        Future.delayed(const Duration(milliseconds: 800), () {
          if (_shouldKeepListening) _beginListenSession();
        });
      }
    }
  }

  /// Internal: stop the current STT session without disabling continuous
  /// monitoring. Used between auto-restart cycles.
  Future<void> _stopCurrentSession() async {
    try {
      await stt.stop();
    } catch (e) {
      dev.log("Error stopping STT session: $e");
    }
    isListening = false;
  }

  /// Fully stop continuous wake word monitoring (e.g. on app shutdown).
  /// Overrides [BaseVoiceService.stopListening] to also disable auto-restart.
  @override
  Future<void> stopListening() async {
    _shouldKeepListening = false;
    _onWakeWordCallback = null;
    _unregisterStatusListener?.call();
    _unregisterStatusListener = null;
    await _stopCurrentSession();
    dev.log("👂 Wake word monitoring fully stopped.");
  }

  /// Call this once a conversation session has fully ended and you want
  /// the service ready to detect the wake word again.
  void resetForNextCycle() {
    _wakeWordFired = false;
  }
}