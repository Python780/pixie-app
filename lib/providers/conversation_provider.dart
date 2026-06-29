import 'dart:developer' as dev;
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';

import '../services/voice_trigger_service.dart';
import '../services/voice_interaction_service.dart';
import '../services/text_to_speech_service.dart';
import '../services/gemini_service.dart';
import '../services/camera_service.dart';
import '../services/pixie_speech_service.dart';
import '../services/firebase_service.dart';
import '../services/analytics_service.dart';

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
  final AnalyticsService _analyticsService = AnalyticsService();
  final FirebaseService _dbService = FirebaseService();
  
  StreamSubscription? _interactionsSub;

  double _currentListeningLevel = 0.0;
  String? _listeningPrompt;
  String _geminiApiKey = '';
  PixieState _state = PixieState.idle;

  ConversationProvider() {
    _voiceService.onSoundLevelChange = _updateListeningLevel;
  }

  PixieState get state => _state;

  void _setState(PixieState newState) {
    _state = newState;
    dev.log("🤖 Pixie State Changed To: $newState");
    notifyListeners();
  }

  List<Message> _messages = [];
  bool _isActive = false;
  bool _isProcessing = false;
  bool _isSpeaking = false;
  bool _cameraActive = false;
  bool _listeningForWakeWord = false;
  bool _geminiAvailable = true;
  String? _geminiErrorMessage;
  int _inactivityTimeoutSeconds = 30;
  DateTime? _lastInteractionTime;

  // Callbacks for UI updates
  void Function(List<Message>)? onMessagesUpdated;
  void Function(bool)? onStatusChanged;

  void _updateListeningLevel(double level) {
    _currentListeningLevel = level;
    notifyListeners();
  }

  void _updateListeningPrompt(String? message) {
    _listeningPrompt = message;
    notifyListeners();
  }

  Future<void> initialize() async {
    try {
      dev.log("🚀 Initializing Pixie Engine...");
      await PixieSpeechService().initialize();
      await _ttsService.initialize();
      await _cameraService.initializeCamera();
      await _geminiService.initialize();
      
      // Subscribe to Firestore interactions
      try {
        _interactionsSub = _dbService.getRecentInteractions().listen((snapshot) {
          final List<Message> loaded = [];
          final docs = List.from(snapshot.docs.reversed);
          for (final d in docs) {
            final data = d.data() as Map<String, dynamic>? ?? {};
            final raw = data['response'] as String? ?? '';
            String userText = '';
            String pixieText = '';
            String facial = '';

            for (final line in raw.split('\n')) {
              final trimmed = line.trim();
              if (trimmed.startsWith('User:')) {
                userText = trimmed.replaceFirst('User:', '').trim();
              } else if (trimmed.startsWith('Facial:')) {
                facial = trimmed.replaceFirst('Facial:', '').trim();
              } else if (trimmed.startsWith('Pixie:')) {
                pixieText = trimmed.replaceFirst('Pixie:', '').trim();
              }
            }

            final when = data['timestamp'] is Timestamp
                ? (data['timestamp'] as Timestamp).toDate()
                : null;

            if (userText.isNotEmpty) {
              loaded.add(Message(text: userText, isUser: true, timestamp: when));
            }
            if (pixieText.isNotEmpty) {
              loaded.add(
                Message(
                  text: pixieText,
                  isUser: false,
                  facialAnalysis: facial.isNotEmpty ? facial : null,
                  timestamp: when,
                ),
              );
            }
          }

          _messages = loaded;
          onMessagesUpdated?.call(_messages);
          notifyListeners();
        });
      } catch (e) {
        dev.log('Failed to subscribe to interactions: $e');
      }

      await _loadGeminiApiKey();
      dev.log("✅ Pixie ready!");
      
      // Auto-start continuous wake word sensing
      await startWakeWordDetection();
    } catch (e) {
      dev.log("Initialization error: $e");
      _setState(PixieState.error);
    }
  }

  /// Start continuous listening for wake word (microphone always on)
  Future<void> startWakeWordDetection() async {
    if (_listeningForWakeWord) return;

    _listeningForWakeWord = true;
    _listenForWakeWordLoop();
  }

  /// Continuous loop for wake word detection
  void _listenForWakeWordLoop() {
    if (!_listeningForWakeWord) return;

    _setState(PixieState.wakeListening);
    dev.log("👂 Background Engine: Monitoring for 'Hi Pixie'...");
    
    _triggerService.startWakeWordListening(() async {
      if (_isActive) return; // Guard against multi-triggering
      
      // Wake word matched! Break loop and escalate to active session.
      await _startConversation();
      
      // After active conversation loop ends completely, fall back into monitoring mode
      if (_listeningForWakeWord) {
        Future.delayed(const Duration(milliseconds: 600), () {
          _listenForWakeWordLoop();
        });
      }
    }).whenComplete(() {
      // Loop recovery safety net
      if (_listeningForWakeWord && !_isActive) {
        dev.log("🔁 Wake word system cycled or timed out; restarting monitor loop...");
        Future.delayed(const Duration(milliseconds: 500), () {
          _listenForWakeWordLoop();
        });
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
    
    // Switch state to speaking for greeting
    _isSpeaking = true;
    _setState(PixieState.speaking);

    await _ttsService.speak("Hi! I'm listening. What would you like to talk about?");
    await _ttsService.waitForCompletion();

    _isSpeaking = false;
    _setState(PixieState.idle);

    // Enter active conversation exchange
    await _conversationLoop();
  }

  /// Main conversation loop - runs until conversation times out or user leaves
  Future<void> _conversationLoop() async {
    while (_isActive) {
      // 1. Check for manual or clock-based camera/inactivity timeout
      if (_cameraActive && _lastInteractionTime != null) {
        final elapsed = DateTime.now().difference(_lastInteractionTime!);
        if (elapsed.inSeconds > _inactivityTimeoutSeconds) {
          dev.log("⏱️ Inactivity limit reached (${_inactivityTimeoutSeconds}s). Sleeping active session.");
          break; 
        }
      }

      // 2. Open active window listening
      _setState(PixieState.userListening);
      _updateListeningPrompt("Listening for your response...");
      dev.log("🎤 Capturing prompt payload (📹 camera=${_cameraActive ? 'ON' : 'OFF'})...");
      
      String userInput = await _voiceService.listenForInput(maxDurationSeconds: 15);

      // Retry mechanism if first collection was blank
      if (userInput.isEmpty) {
        _updateListeningPrompt("No speech detected. Listening again...");
        dev.log("⚠️ Silence encountered. Retrying audio window capture once...");
        userInput = await _voiceService.listenForInput(maxDurationSeconds: 15);
      }

      // 🛠️ FIX: If still empty after a retry, the user has walked away. 
      if (userInput.isEmpty) {
        dev.log("🛑 No continuous speech input confirmed. Closing active session.");
        _updateListeningPrompt("Going back to sleep...");
        
        // Pause here so the user can actually read the "Going back to sleep..." message.
        await Future.delayed(const Duration(seconds: 2));
        break;
      }

      _updateListeningPrompt(null);
      _lastInteractionTime = DateTime.now();

      // Add user message to UI pipeline
      _messages.add(Message(text: userInput, isUser: true));
      onMessagesUpdated?.call(_messages);
      dev.log("User Input Text: $userInput");

      // 3. Transition to Thinking (Mouth closed, processing animation active)
      _isProcessing = true;
      _setState(PixieState.thinking);
      onStatusChanged?.call(false);

      XFile? capturedImage;
      if (_cameraActive) {
        try {
          capturedImage = await _cameraService.captureFrame();
          if (capturedImage != null) {
            dev.log("📷 Frame successfully sent to Gemini payload matrix");
          }
        } catch (e) {
          dev.log("Camera hardware capture failure: $e");
        }
      }

      // 4. Run Cloud Inference request via Gemini
      final conversationHistory = _buildConversationHistory();
      final responseMap = await _geminiService.conversationWithGemini(
        userInput: userInput,
        imageFile: capturedImage,
        conversationHistory: conversationHistory,
      );

      final response = responseMap['response'] ?? "I'm processing that. Let's try again.";
      final facialAnalysis = responseMap['facial'] ?? "Unable to analyze frame context.";
      final faceEmotion = responseMap['faceEmotion'] ?? "neutral";
      final faceConfidence = responseMap['faceConfidence'] ?? "low";
      final bool geminiAvailable = responseMap['geminiAvailable'] != false;
      final String? geminiError = responseMap['error']?.toString();

      // Log Interaction Metrics
      await _analyticsService.logInteraction(
        userQuery: userInput,
        pixieResponse: response,
        emotion: responseMap['emotion']?.toString() ?? 'neutral',
      );

      if (responseMap.containsKey('geminiAvailable')) {
        _geminiAvailable = geminiAvailable;
        _geminiErrorMessage = geminiAvailable ? null : geminiError;
      }

      final pixieEmotion = responseMap['emotion'] ?? 'neutral';
      final String? emotionToDisplay = _resolveDisplayEmotion(
        pixieEmotion: pixieEmotion,
        faceEmotion: faceEmotion,
        faceConfidence: faceConfidence,
      );

      // Append Response to Dataset
      _messages.add(
        Message(
          text: response,
          isUser: false,
          emotion: emotionToDisplay,
          facialAnalysis: facialAnalysis,
        ),
      );
      onMessagesUpdated?.call(_messages);

      // 5. Transition to Speaking (Mouth animation activated via TTS playback)
      _isProcessing = false;
      _isSpeaking = true;
      _setState(PixieState.speaking);

      await _ttsService.speak(response);
      await _ttsService.waitForCompletion();

      // Reset individual sequence back to baseline checking
      _isSpeaking = false;
      _setState(PixieState.idle);
    }

    // 6. Loop Terminated. Safely teardown active state and step down to sleep monitor
    dev.log("💤 Shutting down active loop components...");
    _isActive = false;
    _cameraActive = false;
    _isProcessing = false;
    _isSpeaking = false;
    _updateListeningPrompt(null);
    _setState(PixieState.sleeping);
    onStatusChanged?.call(false);
  }

  /// Decide which emotion the robot face should display.
  String? _resolveDisplayEmotion({
    String? pixieEmotion,
    required String faceEmotion,
    required String faceConfidence,
  }) {
    if (pixieEmotion != null && pixieEmotion != 'neutral') {
      return pixieEmotion;
    }

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

  String _buildConversationHistory() {
    return _messages
        .map((m) => "${m.isUser ? 'User' : 'Pixie'}: ${m.text}")
        .join('\n');
  }

  Future<void> _loadGeminiApiKey() async {
    _geminiApiKey = await _geminiService.getStoredApiKey();
    notifyListeners();
  }

  Future<void> updateGeminiApiKey(String apiKey) async {
    try {
      await _geminiService.saveStoredApiKey(apiKey);
      _geminiApiKey = apiKey.trim();
      if (apiKey.isNotEmpty) {
        _geminiAvailable = true;
        _geminiErrorMessage = null;
      }
      await _geminiService.initialize();
      notifyListeners();
    } catch (e) {
      dev.log('Error updating Gemini API key: $e');
      _geminiErrorMessage = 'Failed to save API key: $e';
      _geminiAvailable = false;
      notifyListeners();
      rethrow;
    }
  }

  /// End the conversation gracefully (camera off, microphone drops back down to wake detection)
  Future<void> endConversation() async {
    if (!_isActive) return;
    _isActive = false; // Breaking out of while() loop flags this instantly
    _updateListeningPrompt(null);
    await _ttsService.stop();
    await _cameraService.disposeCamera();
    _setState(PixieState.idle);
  }

  /// Complete structural shutdown (when app lifecycle terminates)
  Future<void> shutdown() async {
    _listeningForWakeWord = false;
    _isActive = false;
    _cameraActive = false;
    _isSpeaking = false;
    _updateListeningPrompt(null);
    
    try {
      if (_interactionsSub != null) {
        await _interactionsSub!.cancel();
        _interactionsSub = null;
      }
    } catch (e) {
      dev.log('Error cancelling interactions subscription: $e');
    }
    
    await _voiceService.stopListening();
    await _triggerService.stopListening();
    _voiceService.endConversation();
    await _ttsService.stop();
    _setState(PixieState.idle);
    dev.log("🛑 Pixie architecture offline.");
  }

  // Getters
  List<Message> get messages => _messages;
  bool get isActive => _isActive;
  bool get isProcessing => _isProcessing;
  bool get isSpeaking => _isSpeaking;
  bool get isCameraActive => _cameraActive;
  bool get isListeningForWakeWord => _listeningForWakeWord;
  bool get isGeminiAvailable => _geminiAvailable;
  String? get geminiErrorMessage => _geminiErrorMessage;
  String get geminiApiKey => _geminiApiKey;
  bool get hasSavedGeminiApiKey => _geminiApiKey.isNotEmpty;
  double get listeningLevel => _currentListeningLevel;
  String? get listeningPrompt => _listeningPrompt;
  int get inactivityTimeoutSeconds => _inactivityTimeoutSeconds;

  set inactivityTimeoutSeconds(int seconds) {
    _inactivityTimeoutSeconds = seconds;
    notifyListeners();
  }
}