import 'dart:developer' as dev;
import 'package:flutter/foundation.dart' show VoidCallback;
import 'package:speech_to_text/speech_to_text.dart';
import 'base_voice_service.dart';

class PixieVoiceTriggerService extends BaseVoiceService {
  double _currentSoundLevel = 0.0;
  static const double _wakeWordMinLevel = 4.0;

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

          dev.log(
            "🎤 Heard: $words "
            "[final=${result.finalResult} soundLevel=${_currentSoundLevel.toStringAsFixed(1)}]",
          );

          if (words.contains('hi pixie') &&
              _currentSoundLevel >= _wakeWordMinLevel) {
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
