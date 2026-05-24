import 'package:flutter_tts/flutter_tts.dart';
import 'dart:developer' as dev;

class PixieTextToSpeechService {
  final FlutterTts _tts = FlutterTts();
  bool _isSpeaking = false;

  Future<void> initialize() async {
    try {
      // Set up TTS parameters for a friendly robot voice
      await _tts.setLanguage("en-US");
      await _tts.setSpeechRate(0.8); // Slightly slower for clarity
      await _tts.setVolume(1.0); // Maximum volume
      await _tts.setPitch(1.0); // Normal pitch

      // Set up completion listener
      _tts.setCompletionHandler(() {
        _isSpeaking = false;
        dev.log("🔊 Speech complete");
      });

      // Set up error listener
      _tts.setErrorHandler((msg) {
        dev.log("🔊 TTS Error event: $msg");
        _isSpeaking = false;
      });

      dev.log("✅ Text-to-Speech initialized");
    } catch (e) {
      dev.log("TTS Initialization Failed: $e");
    }
  }

  /// Speak text aloud
  Future<void> speak(String text) async {
    if (text.isEmpty) return;

    try {
      _isSpeaking = true;
      dev.log("🔊 Pixie says: $text");
      await _tts.speak(text);
    } catch (e) {
      dev.log("TTS Error: $e");
      _isSpeaking = false;
    }
  }

  /// Stop current speech
  Future<void> stop() async {
    try {
      await _tts.stop();
      _isSpeaking = false;
    } catch (e) {
      dev.log("TTS Stop Error: $e");
    }
  }

  /// Wait for speech to complete
  Future<void> waitForCompletion({
    Duration timeout = const Duration(seconds: 30),
  }) async {
    int attempts = 0;
    while (_isSpeaking && attempts < (timeout.inMilliseconds ~/ 100)) {
      await Future.delayed(const Duration(milliseconds: 100));
      attempts++;
    }
  }

  bool get isSpeaking => _isSpeaking;
}
