import 'dart:developer' as dev;
import 'package:flutter/foundation.dart' show VoidCallback;
import 'package:speech_to_text/speech_to_text.dart';
import 'base_voice_service.dart';

class PixieVoiceTriggerService extends BaseVoiceService {

  Future<void> startWakeWordListening(
    VoidCallback onWakeWord,
  ) async {

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

          String words =
              result.recognizedWords.toLowerCase();

          dev.log("🎤 Heard: $words");

          if (words.contains('hi pixie')) {

            dev.log("🎯 Wake word detected!");

            await stopListening();

            await Future.delayed(
              const Duration(milliseconds: 500),
            );

            onWakeWord();
          }
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