import 'package:speech_to_text/speech_to_text.dart';
import 'dart:developer' as dev;
//import 'package:flutter/foundation.dart' show VoidCallback;

//typedef ConversationCallback = Future<void> Function(String userInput);

class PixieVoiceInteractionService {
  final SpeechToText _stt = SpeechToText();
  bool _isListening = false;
  bool _inConversation = false;
  String _currentInput = "";

  Future<void> initializeSpeech() async {
    try {
      bool available = await _stt.initialize(
        onError: (val) => dev.log('STT Error: $val'),
        onStatus: (val) => dev.log('STT Status: $val'),
      );

      if (!available) {
        dev.log('Speech recognition hardware unavailable');
      }
    } catch (e) {
      dev.log('Speech Init Failed: $e');
    }
  }

 
  /// Listen only for user input during active conversation
  Future<String> listenForInput({int maxDurationSeconds = 10}) async {
    if (_isListening || !_inConversation) return "";

    _currentInput = "";

    try {
      await _stt.listen(
        onResult: (result) {
          _currentInput = result.recognizedWords;
          dev.log(
            "🎤 User said: $_currentInput (isFinal: ${result.finalResult})",
          );
        },
        listenMode: ListenMode.deviceDefault,
        cancelOnError: false,
        pauseFor: Duration(
          seconds: 3,
        ), // Stop listening after 3 seconds of silence
      );
      _isListening = true;

      // Wait for the timeout or until listening stops
      await Future.delayed(Duration(seconds: maxDurationSeconds));
      await stopListening();

      return _currentInput;
    } catch (e) {
      dev.log("Conversation listening failed: $e");
      return "";
    }
  }

  /// Process a round of conversation (listen → wait for response)
  Future<String> conversationRound({int maxDurationSeconds = 10}) async {
    if (!_inConversation) return "";
    return await listenForInput(maxDurationSeconds: maxDurationSeconds);
  }

  Future<void> stopListening() async {
    if (!_isListening) return;
    await _stt.stop();
    _isListening = false;
  }

  void endConversation() {
    _inConversation = false;
    _currentInput = "";
    stopListening();
    dev.log("👋 Conversation ended");
  }

  bool get isInConversation => _inConversation;
  bool get isListening => _isListening;
}
