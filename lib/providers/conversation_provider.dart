import 'dart:developer' as dev;

import 'package:flutter/material.dart';
import 'package:camera/camera.dart';

import '../services/voice_trigger_service.dart';
import '../services/voice_interaction_service.dart';
import '../services/text_to_speech_service.dart';
import '../services/gemini_service.dart';
import '../services/camera_service.dart';
import '../services/pixie_speech_service.dart';

enum PixieState {
  idle,
  wakeListening,
  userListening,
  thinking,
  speaking,
  sleeping,
  error,
}

class Message {
  final String text;
  final bool isUser;
  final String? emotion;
  final String? facialAnalysis;
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
  final PixieVoiceInteractionService _voiceService = PixieVoiceInteractionService();
  final PixieTextToSpeechService _ttsService = PixieTextToSpeechService();
  final GeminiService _geminiService = GeminiService();
  final PixieCameraService _cameraService = PixieCameraService();

  PixieState _state = PixieState.idle;

  PixieState get state => _state;

  void _setState(PixieState newState) {
    _state = newState;
    notifyListeners();
  }

  List<Message> _messages = [];
  bool _isActive = false;
  bool _isProcessing = false;

  // made the mouth animate during Gemini thinking — not during actual speech.
  // Now _isSpeaking tracks TTS playback separately from Gemini processing.
  bool _isSpeaking = false;
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
      await PixieSpeechService().initialize();
      await _ttsService.initialize();
      await _cameraService.initializeCamera();
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
    _setState(PixieState.wakeListening);
    _listenForWakeWordLoop();
    notifyListeners();
  }

  /// Continuous loop for wake word detection
  void _listenForWakeWordLoop() {
    if (!_listeningForWakeWord) return;

    dev.log("👂 Microphone active - listening for 'Hi Pixie'...");
    _triggerService.startWakeWordListening(() async {
      if (_isActive) return;
      await _startConversation();
        // Restart wake word safely after conversation ends
      if (_listeningForWakeWord) {
        Future.delayed(
          const Duration(milliseconds: 500),
          () {

            _listenForWakeWordLoop();
          },
        );
      }    
    });
  }

  /// Private: Initialize a new conversation with camera ON
  Future<void> _startConversation() async {
    _isActive = true;
    _cameraActive = true; // camera disabled for testing voice-only first
    _messages = [];
    _lastInteractionTime = DateTime.now();
    onStatusChanged?.call(true);
    notifyListeners();

    // BUG FIX: Set _isSpeaking before greeting, clear after
    _isSpeaking = true;
    notifyListeners();

    await _ttsService.speak(
      "Hi! I'm listening. What would you like to talk about?",
    );
    await _ttsService.waitForCompletion();
    
    _isSpeaking = false;
    notifyListeners();

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
          break;
        }
      }

      // Listen for user input
      dev.log(
        "🎤 Waiting for user input${_cameraActive ? ' (📹 camera on)' : ' (📹 camera off)'}...",
      );
      final userInput = await _voiceService
        .listenForInput()
        .timeout(const Duration(seconds: 15), onTimeout: () => "");

      if (userInput.isEmpty) {
        continue;
      }

      _lastInteractionTime = DateTime.now();

      // Add user message
      _messages.add(Message(text: userInput, isUser: true));
      onMessagesUpdated?.call(_messages);
      dev.log("👤 User: $userInput");

      // Set processing state (Gemini thinking — mouth stays closed)
      _isProcessing = true;
      _setState(PixieState.thinking);
      onStatusChanged?.call(false);
      notifyListeners();

      // Capture image for context (only if camera is still active)
      XFile? capturedImage;
      
      if (_cameraActive) {
        try {
          capturedImage = await _cameraService.captureFrame();

          if (capturedImage != null) {
            dev.log("📷 Image captured for analysis");
          }
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
      final facialAnalysis  = responseMap['facial']         ?? "Unable to analyze";
      final faceEmotion     = responseMap['faceEmotion']    ?? "neutral";
      final faceConfidence  = responseMap['faceConfidence'] ?? "low";

      // Extract Pixie's own emotion from her response tag e.g. "(happy)"
      final pixieEmotion = responseMap['emotion'] ?? 'neutral';

      // If Gemini detected user's face with high confidence, let it influence
      // Pixie's displayed emotion when Pixie has no strong emotion of her own.
      // e.g. user looks sad → Pixie shows (concerned) face automatically.
      final String? emotionToDisplay = _resolveDisplayEmotion(
        pixieEmotion: pixieEmotion,
        faceEmotion: faceEmotion,
        faceConfidence: faceConfidence,
      );

      // Add Pixie message with facial analysis
      _messages.add(
        Message(
          text: response,
          isUser: false,
          emotion: emotionToDisplay,
          facialAnalysis: facialAnalysis,
        ),
      );
      onMessagesUpdated?.call(_messages);
      dev.log("🤖 Pixie: $response");
      dev.log("👁️ Facial Analysis: $facialAnalysis");
      dev.log("😊 Display emotion: $emotionToDisplay (pixie=$pixieEmotion, user=$faceEmotion)");

      // BUG FIX: Processing ends here; speaking begins separately
      // This means the mouth only opens when TTS is actually playing
      _isProcessing = false;
      _isSpeaking = true;
      _setState(PixieState.speaking);
      notifyListeners();

      await _ttsService.speak(response);
      await _ttsService.waitForCompletion();

      _isSpeaking = false;
      notifyListeners();
      _setState(PixieState.idle);
    }

    // Conversation ended, reset all flags
    _isActive = false;
    _cameraActive = false;
    _isProcessing = false;
    _isSpeaking = false;
    notifyListeners();
  }

  /// Decide which emotion the robot face should display.
  /// Pixie's own emotion tag takes priority. If she's neutral, mirror the
  /// user's detected face emotion (only when confidence is high).
  String? _resolveDisplayEmotion({
    String? pixieEmotion,
    required String faceEmotion,
    required String faceConfidence,
  }) {
    // Pixie has a strong emotion — use it
    if (pixieEmotion != null && pixieEmotion != 'neutral') {
      return pixieEmotion;
    }

    // Pixie is neutral — mirror user's face if confident
    if (faceConfidence == 'high') {
      switch (faceEmotion.toLowerCase()) {
        case 'sad':
        case 'fearful':
          return 'concerned';
        case 'angry':
        case 'disgusted':
          return 'confused';
        case 'happy':
        case 'excited':
          return 'happy';
        case 'surprised':
          return 'surprised';
        case 'tired':
          return 'thoughtful';
        default:
          return pixieEmotion ?? 'neutral';
      }
    }

    return pixieEmotion ?? 'neutral';
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
    _isSpeaking = false;
    await _ttsService.stop();
    await _cameraService.disposeCamera();

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
    _isSpeaking = false;
    await _voiceService.stopListening();
    await _triggerService.stopListening();
    _voiceService.endConversation();
    await _ttsService.stop();
    dev.log("🛑 Pixie shutdown complete");
    notifyListeners();
  }

  // Getters
  List<Message> get messages => _messages;
  bool get isActive => _isActive;
  bool get isProcessing => _isProcessing;

  // BUG FIX: Expose isSpeaking separately so face_screen.dart can wire
  // isTalking = provider.isSpeaking  (mouth moves only during TTS)
  // isProcessing = provider.isProcessing  (glow effect during Gemini thinking)
  bool get isSpeaking => _isSpeaking;

  bool get isCameraActive => _cameraActive;
  bool get isListeningForWakeWord => _listeningForWakeWord;
  int get inactivityTimeoutSeconds => _inactivityTimeoutSeconds;

  set inactivityTimeoutSeconds(int seconds) {
    _inactivityTimeoutSeconds = seconds;
    notifyListeners();
  }
}
