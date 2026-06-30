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

// ---------------------------------------------------------------------------
// ConversationProvider
// ---------------------------------------------------------------------------

class ConversationProvider with ChangeNotifier {
  final PixieVoiceTriggerService _triggerService = PixieVoiceTriggerService();
  final PixieVoiceInteractionService _voiceService =
      PixieVoiceInteractionService();
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
    dev.log("🤖 Pixie State: $newState");
    notifyListeners();
  }

  List<Message> _messages = [];
  bool _isActive = false;
  bool _isProcessing = false;
  bool _isSpeaking = false;
  bool _cameraActive = false;
  bool _listeningForWakeWord = false;
  bool _hasCompletedAtLeastOneSession = false;
  bool _geminiAvailable = true;
  String? _geminiErrorMessage;
  int _inactivityTimeoutSeconds = 30;
  DateTime? _lastInteractionTime;

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

  // ---------------------------------------------------------------------------
  // Initialization
  // ---------------------------------------------------------------------------

  Future<void> initialize() async {
    try {
      dev.log("🚀 Initializing Pixie Engine...");
      await PixieSpeechService().initialize();
      await _ttsService.initialize();
      await _cameraService.initializeCamera();
      await _geminiService.initialize();

      try {
        _interactionsSub =
            _dbService.getRecentInteractions().listen((snapshot) {
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
              loaded.add(
                  Message(text: userText, isUser: true, timestamp: when));
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

      await startWakeWordDetection();
    } catch (e) {
      dev.log("Initialization error: $e");
      _setState(PixieState.error);
    }
  }

  // ---------------------------------------------------------------------------
  // Wake Word Detection — endless automatic loop
  // ---------------------------------------------------------------------------

  /// Begins the endless cycle:
  ///   wakeListening → conversation → sleep → wakeListening → …
  ///
  /// Safe to call multiple times — guards against double-start.
  Future<void> startWakeWordDetection() async {
    if (_listeningForWakeWord) return;
    _listeningForWakeWord = true;
    _listenForWakeWordLoop();
  }

  /// The core loop. After every conversation ends (by inactivity or silence)
  /// this method is called again automatically — no button or manual trigger needed.
  void _listenForWakeWordLoop() {
    if (!_listeningForWakeWord) return;

    _setState(PixieState.wakeListening);
    dev.log("👂 Monitoring for 'Hi Pixie'...");

    _triggerService.startWakeWordListening(() async {
      if (_isActive) return; // Guard: ignore if already in a session

      // Wake word heard → run a full conversation session
      await _startConversation();

      // Conversation finished (silence / inactivity) → loop back automatically
      if (_listeningForWakeWord) {
        dev.log("🔁 Session ended — back to wake word monitoring.");
        Future.delayed(const Duration(milliseconds: 200), () {
          _listenForWakeWordLoop();
        });
      }
    }).whenComplete(() {
      // Safety net: trigger service timed out by itself
      if (_listeningForWakeWord && !_isActive) {
        dev.log("🔁 Trigger service cycled — restarting wake word loop.");
        Future.delayed(const Duration(milliseconds: 200), () {
          _listenForWakeWordLoop();
        });
      }
    });
  }

  // ---------------------------------------------------------------------------
  // Conversation Lifecycle
  // ---------------------------------------------------------------------------

  /// Starts a new conversation session.
  ///
  /// Camera is always re-initialised here because [_conversationLoop] calls
  /// disposeCamera() during teardown — without this the second+ sessions
  /// would have no vision.
  Future<void> _startConversation() async {
    _isActive = true;
    _cameraActive = true;
    _messages = [];
    _lastInteractionTime = DateTime.now();
    onStatusChanged?.call(true);

    // Re-init camera every session — safe even if already initialised
    try {
      await _cameraService.initializeCamera();
      dev.log("📷 Camera ready.");
    } catch (e) {
      dev.log("⚠️ Camera init failed — continuing without vision: $e");
      _cameraActive = false;
    }

    // Greeting
    _isSpeaking = true;
    _setState(PixieState.speaking);
    await _ttsService.speak(
        "Hi! I'm listening. What would you like to talk about?");
    await _ttsService.waitForCompletion();
    _isSpeaking = false;
    _setState(PixieState.idle);

    await _conversationLoop();
  }

  /// Main conversation loop.
  ///
  /// Exits when:
  ///   • inactivity timeout is reached, or
  ///   • two consecutive silent audio windows are detected.
  ///
  /// After it returns, [_listenForWakeWordLoop] resumes automatically.
  Future<void> _conversationLoop() async {
    while (_isActive) {
      // 1. Inactivity timeout
      if (_lastInteractionTime != null) {
        final elapsed = DateTime.now().difference(_lastInteractionTime!);
        if (elapsed.inSeconds > _inactivityTimeoutSeconds) {
          dev.log("⏱️ Inactivity timeout (${_inactivityTimeoutSeconds}s) — "
              "ending session.");
          break;
        }
      }

      // 2. Listen for user speech
      _setState(PixieState.userListening);
      _updateListeningPrompt("Listening...");
      dev.log(
          "🎤 Listening (camera=${_cameraActive ? 'ON' : 'OFF'})...");

      String userInput =
          await _voiceService.listenForInput(maxDurationSeconds: 15);

      // Single retry on silence
      if (userInput.isEmpty) {
        _updateListeningPrompt("No speech detected. Listening again...");
        dev.log("⚠️ Silence — retrying once...");
        userInput =
            await _voiceService.listenForInput(maxDurationSeconds: 15);
      }

      // Still silent → end session, return to wake word loop
      if (userInput.isEmpty) {
        dev.log("🛑 No speech after retry — ending session.");
        _updateListeningPrompt("Going back to sleep...");
        break;
      }

      _updateListeningPrompt(null);
      _lastInteractionTime = DateTime.now();

      _messages.add(Message(text: userInput, isUser: true));
      onMessagesUpdated?.call(_messages);
      dev.log("User: $userInput");

      // 3. Thinking
      _isProcessing = true;
      _setState(PixieState.thinking);
      onStatusChanged?.call(false);

      XFile? capturedImage;
      if (_cameraActive) {
        try {
          capturedImage = await _cameraService.captureFrame();
          if (capturedImage != null) dev.log("📷 Frame captured.");
        } catch (e) {
          dev.log("📷 Capture error: $e");
        }
      }

      // 4. Gemini inference
      final responseMap = await _geminiService.conversationWithGemini(
        userInput: userInput,
        imageFile: capturedImage,
        conversationHistory: _buildConversationHistory(),
      );

      final response =
          responseMap['response'] ?? "I'm processing that. Let's try again.";
      final facialAnalysis =
          responseMap['facial'] ?? "Unable to analyze frame context.";
      final faceEmotion = responseMap['faceEmotion'] ?? "neutral";
      final faceConfidence = responseMap['faceConfidence'] ?? "low";
      final bool geminiAvailable = responseMap['geminiAvailable'] != false;
      final String? geminiError = responseMap['error']?.toString();

      await _analyticsService.logInteraction(
        userQuery: userInput,
        pixieResponse: response,
        emotion: responseMap['emotion']?.toString() ?? 'neutral',
      );

      if (responseMap.containsKey('geminiAvailable')) {
        _geminiAvailable = geminiAvailable;
        _geminiErrorMessage = geminiAvailable ? null : geminiError;
      }

      final String? emotionToDisplay = _resolveDisplayEmotion(
        pixieEmotion: responseMap['emotion']?.toString() ?? 'neutral',
        faceEmotion: faceEmotion,
        faceConfidence: faceConfidence,
      );

      _messages.add(
        Message(
          text: response,
          isUser: false,
          emotion: emotionToDisplay,
          facialAnalysis: facialAnalysis,
        ),
      );
      onMessagesUpdated?.call(_messages);

      // 5. Speaking
      _isProcessing = false;
      _isSpeaking = true;
      _setState(PixieState.speaking);
      await _ttsService.speak(response);
      await _ttsService.waitForCompletion();
      _isSpeaking = false;
      _setState(PixieState.idle);
    }

    // 6. Session teardown → sleeping
    dev.log("💤 Tearing down session → sleeping.");
    _isActive = false;
    _cameraActive = false;
    _isProcessing = false;
    _isSpeaking = false;
    _hasCompletedAtLeastOneSession = true;
    _updateListeningPrompt(null);

    try {
      await _cameraService.disposeCamera();
    } catch (e) {
      dev.log("Camera dispose (non-fatal): $e");
    }

    _setState(PixieState.sleeping);
    onStatusChanged?.call(false);
    // _listenForWakeWordLoop() resumes automatically from the caller.
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

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

  // ---------------------------------------------------------------------------
  // End / Shutdown
  // ---------------------------------------------------------------------------

  /// Manually restart a conversation — called by the UI restart button.
  ///
  /// Bypasses wake word detection since the user's intent is already explicit.
  /// After the conversation ends naturally the system automatically falls back
  /// into wake word monitoring as usual.
  Future<void> restartConversation() async {
    if (_isActive) {
      dev.log("⚠️ restartConversation() ignored — session already active.");
      return;
    }

    dev.log("🔄 Manual restart — starting new conversation session.");

    // Clear stale state from previous session
    _messages = [];
    _geminiErrorMessage = null;
    _updateListeningPrompt(null);
    onMessagesUpdated?.call(_messages);

    // Start conversation directly (camera re-init happens inside _startConversation)
    await _startConversation();

    // When conversation ends, fall back into wake word monitoring as normal
    if (_listeningForWakeWord) {
      Future.delayed(const Duration(milliseconds: 600), () {
        _listenForWakeWordLoop();
      });
    }
  }

  /// Gracefully end the active conversation early.
  /// The wake word loop will resume automatically.
  Future<void> endConversation() async {
    if (!_isActive) return;
    _isActive = false;
    _updateListeningPrompt(null);
    await _ttsService.stop();
    try {
      await _cameraService.disposeCamera();
    } catch (e) {
      dev.log("Camera dispose on endConversation (non-fatal): $e");
    }
    _setState(PixieState.idle);
  }

  /// Full shutdown — call only when the app is terminating.
  Future<void> shutdown() async {
    _listeningForWakeWord = false;
    _isActive = false;
    _cameraActive = false;
    _isSpeaking = false;
    _updateListeningPrompt(null);

    try {
      await _interactionsSub?.cancel();
      _interactionsSub = null;
    } catch (e) {
      dev.log('Subscription cancel error: $e');
    }

    await _voiceService.stopListening();
    await _triggerService.stopListening();
    _voiceService.endConversation();
    await _ttsService.stop();

    try {
      await _cameraService.disposeCamera();
    } catch (e) {
      dev.log("Camera dispose on shutdown (non-fatal): $e");
    }

    _setState(PixieState.idle);
    dev.log("🛑 Pixie offline.");
  }

  // ---------------------------------------------------------------------------
  // Getters
  // ---------------------------------------------------------------------------

  List<Message> get messages => _messages;
  bool get isActive => _isActive;
  bool get isProcessing => _isProcessing;
  bool get isSpeaking => _isSpeaking;
  bool get isCameraActive => _cameraActive;
  bool get isListeningForWakeWord => _listeningForWakeWord;
  bool get hasCompletedAtLeastOneSession => _hasCompletedAtLeastOneSession;
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