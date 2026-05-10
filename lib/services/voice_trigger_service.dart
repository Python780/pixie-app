import 'package:speech_to_text/speech_to_text.dart';
import 'dart:developer' as dev;
import 'package:flutter/foundation.dart' show kIsWeb;

typedef WakeWordCallback = void Function();

class PixieVoiceService {
  final SpeechToText _stt = SpeechToText();
  bool _isListening = false;

  Future<void> initializeSpeech() async {
    // 1. Prevent Web Crash: SpeechToText often fails on web drivers
    if (kIsWeb) {
      dev.log("Speech-to-Text skipped: Web platform detected.");
      return;
    }

    try {
      bool available = await _stt.initialize(
        onError: (val) => dev.log('STT Error: $val'),
        onStatus: (val) => dev.log('STT Status: $val'),
      );

      if (!available) {
        dev.log('Speech recognition hardware unavailable');
      }
    } catch (e) {
      // 2. Log error but don't rethrow, so the rest of the app can load
      dev.log('Speech Init Failed: $e');
    }
  }

  Future<void> startListening(WakeWordCallback onWakeWord) async {
    // 3. Prevent multiple listeners and check web safety again
    if (_isListening || kIsWeb) return;

    try {
      await _stt.listen(
        onResult: (result) {
          String words = result.recognizedWords.toLowerCase();

          // 4. Wake-word logic
          if (words.contains('hi pixie')) {
            stopListening();
            onWakeWord(); // Triggers the Gemini/Camera phase
          }
        },
        listenMode: ListenMode.deviceDefault,
        cancelOnError: false,
      );
      _isListening = true;
    } catch (e) {
      dev.log("Listening failed to start: $e");
    }
  }

  Future<void> stopListening() async {
    if (!_isListening || kIsWeb) return;

    await _stt.stop();
    _isListening = false;
  }
}
