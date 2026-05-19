import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'dart:developer' as dev;
import '../services/voice_trigger_service.dart';
import '../services/voice_interaction_service.dart';
import '../services/text_to_speech_service.dart';
import '../services/gemini_service.dart';
import '../services/camera_service.dart';

class Message {
  final String text;
  final bool isUser;
  final String? emotion;
  final String? facialAnalysis; // Facial expression/emotion from camera
  final DateTime timestamp;

  Message({
    required this.text,
    required this.isUser,
    this.emotion,
    this.facialAnalysis,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();
}

class ConversationProvider with ChangeNotifier {
  final PixieVoiceTriggerService _triggerService = PixieVoiceTriggerService();
  final PixieVoiceInteractionService _voiceService =
      PixieVoiceInteractionService();
  final PixieTextToSpeechService _ttsService = PixieTextToSpeechService();
  final GeminiService _geminiService = GeminiService();
  final PixieCameraService _cameraService = PixieCameraService();

  List<Message> _messages = [];
  bool _isActive = false;
  bool _isProcessing = false;
  bool _cameraActive = false;
  bool _listeningForWakeWord = false;
  int _inactivityTimeoutSeconds = 30;
  DateTime? _lastInteractionTime;

  // Callbacks for UI updates
  void Function(List<Message>)? onMessagesUpdated;
  void Function(bool)? onStatusChanged;

  Future<void> initialize() async {
    try {
      dev.log("🚀 Initializing Pixie...");
      await _triggerService.initializeSpeech();
      await _voiceService.initializeSpeech();
      await _ttsService.initialize();
      dev.log("✅ Pixie ready!");
      dev.log("🎤 Microphone always ON - waiting for 'Hi Pixie'...");
    } catch (e) {
      dev.log("Initialization error: $e");
    }
  }

  /// Start continuous listening for wake word (microphone always on)
  Future<void> startWakeWordDetection() async {
    if (_listeningForWakeWord) return;

    _listeningForWakeWord = true;
    _listenForWakeWordLoop();
    notifyListeners();
  }

  /// Continuous loop for wake word detection
  void _listenForWakeWordLoop() {
    if (!_listeningForWakeWord) return;

    dev.log("👂 Microphone active - listening for 'Hi Pixie'...");
    _triggerService.startWakeWordListening(() async {
      if (!_isActive) {
        await _startConversation();
        // After conversation ends, loop back to wake word listening
        _listenForWakeWordLoop();
      }
    });
  }

  /// Private: Initialize a new conversation with camera ON
  Future<void> _startConversation() async {
    _isActive = true;
    _cameraActive = true;
    _messages = [];
    _lastInteractionTime = DateTime.now();
    onStatusChanged?.call(true);
    notifyListeners();

    await _ttsService.speak(
      "Hi! I'm listening. What would you like to talk about?",
    );
    await _ttsService.waitForCompletion();

    // Start conversation loop
    await _conversationLoop();
  }

  /// Main conversation loop - runs until camera timeout
  Future<void> _conversationLoop() async {
    while (_isActive) {
      // Check for camera inactivity timeout
      if (_cameraActive && _lastInteractionTime != null) {
        final elapsed = DateTime.now().difference(_lastInteractionTime!);
        if (elapsed.inSeconds > _inactivityTimeoutSeconds) {
          dev.log("⏱️ Camera timeout reached - turning off camera");
          dev.log(
            "🎤 Microphone still active, listening for user or 'Hi Pixie'",
          );
          _cameraActive = false;
          onStatusChanged?.call(false);
          notifyListeners();
          // Exit conversation, return to wake word listening
          break;
        }
      }

      // Listen for user input
      dev.log(
        "🎤 Waiting for user input${_cameraActive ? ' (📹 camera on)' : ' (📹 camera off)'}...",
      );
      final userInput = await _voiceService.listenForInput();

      if (userInput.isEmpty) {
        continue; // Timeout or no input, check camera timeout again
      }

      _lastInteractionTime = DateTime.now();

      // Add user message
      _messages.add(Message(text: userInput, isUser: true));
      onMessagesUpdated?.call(_messages);
      dev.log("👤 User: $userInput");

      // Set processing state
      _isProcessing = true;
      onStatusChanged?.call(false);
      notifyListeners();

      // Capture image for context (only if camera is still active)
      XFile? capturedImage;
      if (_cameraActive) {
        try {
          await _cameraService.triggerVision((image) async {
            capturedImage = image;
          });
          dev.log("📷 Image captured for analysis");
        } catch (e) {
          dev.log("Camera capture error: $e");
        }
      } else {
        dev.log("📷 Camera is off - voice-only response");
      }

      // Get Gemini response
      final conversationHistory = _buildConversationHistory();
      final responseMap = await _geminiService.conversationWithGemini(
        userInput: userInput,
        imageFile: capturedImage,
        conversationHistory: conversationHistory,
      );

      final response =
          responseMap['response'] ?? "That's interesting! (thoughtful)";
      final facialAnalysis = responseMap['facial'] ?? "Unable to analyze";

      // Extract emotion from response if present
      String? emotion;
      final emotionRegex = RegExp(r'\(([^)]+)\)');
      final match = emotionRegex.firstMatch(response);
      if (match != null) {
        emotion = match.group(1);
      }

      // Add Pixie message with facial analysis
      _messages.add(
        Message(
          text: response,
          isUser: false,
          emotion: emotion,
          facialAnalysis: facialAnalysis,
        ),
      );
      onMessagesUpdated?.call(_messages);
      dev.log("🤖 Pixie: $response");
      dev.log("👁️ Facial Analysis: $facialAnalysis");

      // Speak response
      await _ttsService.speak(response);
      await _ttsService.waitForCompletion();

      _isProcessing = false;
      notifyListeners();
    }

    // Conversation ended, reset flags
    _isActive = false;
    _cameraActive = false;
    notifyListeners();
  }

  /// Build conversation history for context
  String _buildConversationHistory() {
    return _messages
        .map((m) => "${m.isUser ? 'User' : 'Pixie'}: ${m.text}")
        .join('\n');
  }

  /// End the conversation gracefully (camera off, microphone keeps listening)
  Future<void> endConversation() async {
    if (!_isActive) return;

    _isActive = false;
    _cameraActive = false;
    await _ttsService.stop();

    dev.log("👋 Conversation ended");
    dev.log("🎤 Microphone still listening for next 'Hi Pixie'");
    onStatusChanged?.call(false);
    notifyListeners();
  }

  /// Complete shutdown (when exiting app)
  Future<void> shutdown() async {
    _listeningForWakeWord = false;
    _isActive = false;
    _cameraActive = false;
    await _voiceService.stopListening();
    _voiceService.endConversation();
    await _ttsService.stop();
    dev.log("🛑 Pixie shutdown complete");
    notifyListeners();
  }

  // Getters
  List<Message> get messages => _messages;
  bool get isActive => _isActive;
  bool get isProcessing => _isProcessing;
  bool get isCameraActive => _cameraActive;
  bool get isListeningForWakeWord => _listeningForWakeWord;
  int get inactivityTimeoutSeconds => _inactivityTimeoutSeconds;

  set inactivityTimeoutSeconds(int seconds) {
    _inactivityTimeoutSeconds = seconds;
    notifyListeners();
  }
}
