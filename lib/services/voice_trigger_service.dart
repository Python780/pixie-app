import 'dart:developer' as dev;
import 'package:flutter/foundation.dart' show VoidCallback;
import 'package:speech_to_text/speech_to_text.dart';
import 'base_voice_service.dart';

class PixieVoiceTriggerService extends BaseVoiceService {
  double _currentSoundLevel = 0.0;
  // Sound level threshold is device-dependent; prefer a lower threshold
  // and also accept final results or reasonable confidence levels.
  static const double _wakeWordMinLevel = 0.4;

  Future<void> startWakeWordListening(VoidCallback onWakeWord) async {
    if (isListening) return;

    bool available = await initSpeech();
    if (!available) {
      dev.log("STT unavailable");
      return;
    }

    try {
      isListening = true;
      dev.log("👂 Wake word listening started");

      await stt.listen(
        onResult: (result) async {
          String words = result.recognizedWords.toLowerCase();
          final confidence = result.confidence;

          dev.log(
            "🎤 Heard: $words "
            "[final=${result.finalResult} confidence=${confidence.toStringAsFixed(2)} soundLevel=${_currentSoundLevel.toStringAsFixed(2)}]",
          );

          // Trigger if phrase detected and one of these is true:
          // - loud enough sound level,
          // - speech final result,
          // - or reasonable confidence from recognizer.
          final bool trusted =
              result.finalResult ||
              (confidence != null && confidence > 0.45) ||
              _currentSoundLevel >= _wakeWordMinLevel;

          if (words.contains('hi pixie') && trusted) {
            dev.log("🎯 Wake word detected!");
            await stopListening();
            await Future.delayed(const Duration(milliseconds: 500));
            onWakeWord();
          }
        },
        onSoundLevelChange: (level) {
          _currentSoundLevel = level;
        },
        listenMode: ListenMode.dictation,
        partialResults: true,
        cancelOnError: false,
        pauseFor: const Duration(seconds: 5),
        listenFor: const Duration(minutes: 5),
      );
    } catch (e) {
      dev.log("Wake word listening failed: $e");
      isListening = false;
    }
  }
}
