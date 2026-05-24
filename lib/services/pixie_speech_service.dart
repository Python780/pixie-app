import 'package:speech_to_text/speech_to_text.dart';
import 'dart:developer' as dev;
import 'package:flutter/foundation.dart' show kIsWeb;

class PixieSpeechService {
  static final PixieSpeechService _instance =
      PixieSpeechService._internal();

  factory PixieSpeechService() => _instance;
  PixieSpeechService._internal();
  final SpeechToText stt = SpeechToText();
  bool _initialized = false;

  Future<bool> initialize() async {
    if (_initialized) {
      return true;
    }

    if (kIsWeb) {
      dev.log("Speech-to-Text skipped on Web");
      return false;
    }

    try {
      _initialized = await stt.initialize(
        onError: (val) => dev.log("❌ STT Error: $val"),
        onStatus: (val) => dev.log("🎤 STT Status: $val"),
      );

      dev.log("✅ Speech initialized: $_initialized");

      return _initialized;
    } catch (e) {
      dev.log("Speech init failed: $e");
      return false;
    }
  }
}