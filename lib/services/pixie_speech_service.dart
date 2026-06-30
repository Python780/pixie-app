import 'package:speech_to_text/speech_to_text.dart';
import 'dart:developer' as dev;
import 'package:flutter/foundation.dart' show kIsWeb, VoidCallback;
import 'package:permission_handler/permission_handler.dart';

class PixieSpeechService {
  static final PixieSpeechService _instance = PixieSpeechService._internal();

  factory PixieSpeechService() => _instance;
  PixieSpeechService._internal();
  final SpeechToText stt = SpeechToText();
  bool _initialized = false;

  /// Status listeners registered by other services (e.g. wake word trigger
  /// service) that want to react to STT lifecycle changes such as 'done'
  /// or 'notListening'. Since speech_to_text only allows ONE onStatus
  /// callback (set once during initialize() and never reset), this acts
  /// as a fan-out so multiple services can each get notified.
  final List<void Function(String status)> _statusListeners = [];

  /// Register a callback to be notified whenever the STT engine's status
  /// changes. Returns a function you can call to unregister.
  VoidCallback addStatusListener(void Function(String status) listener) {
    _statusListeners.add(listener);
    return () => _statusListeners.remove(listener);
  }

  Future<bool> initialize() async {
    if (_initialized) {
      return true;
    }

    if (kIsWeb) {
      dev.log("Speech-to-Text skipped on Web");
      return false;
    }

    try {
      // Ensure microphone permission is granted at runtime
      final micStatus = await Permission.microphone.request();
      if (!micStatus.isGranted) {
        dev.log('Microphone permission not granted: $micStatus');
        return false;
      }

      _initialized = await stt.initialize(
        onError: (val) => dev.log("❌ STT Error: $val"),
        onStatus: (status) {
          dev.log("🎤 STT Status: $status");
          // Fan out to every registered listener (e.g. wake word service).
          for (final listener in List.of(_statusListeners)) {
            try {
              listener(status);
            } catch (e) {
              dev.log("Status listener error: $e");
            }
          }
        },
      );

      dev.log("✅ Speech initialized: $_initialized");

      return _initialized;
    } catch (e) {
      dev.log("Speech init failed: $e");
      return false;
    }
  }
}