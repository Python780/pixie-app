import 'dart:developer' as dev;
import 'package:speech_to_text/speech_to_text.dart';
import 'pixie_speech_service.dart';

abstract class BaseVoiceService {
  final SpeechToText stt = PixieSpeechService().stt;

  bool isListening = false;

  Future<bool> initSpeech() async {
    return await PixieSpeechService().initialize();
  }

  Future<void> stopListening() async {
    if (!isListening) return;

    try {
      await stt.stop();

      dev.log("🛑 Listener stopped");
    } catch (e) {
      dev.log("Stop listening error: $e");
    }

    isListening = false;
  }
}