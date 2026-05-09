import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import '../services/gemini_service.dart';
import '../services/voice_trigger_service.dart';
import '../services/firebase_service.dart';

class FaceScreen extends StatefulWidget {
  @override
  _FaceScreenState createState() => _FaceScreenState();
}

class _FaceScreenState extends State<FaceScreen> {
  // 1. Initialize the Services
  final GeminiService _ai = GeminiService();
  final PixieVoiceService _voice = PixieVoiceService();
  final FirebaseService _storage = FirebaseService();
  final FlutterTts _tts = FlutterTts();

  late CameraController _cameraController;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _setupRobot();
  }

  // Initial setup for the Eye (Camera) and Ear (Voice)
  Future<void> _setupRobot() async {
    // Initialize Camera
    final cameras = await availableCameras();
    _cameraController = CameraController(cameras[1], ResolutionPreset.medium);
    await _cameraController.initialize();

    // Initialize Voice Ear
    await _voice.initializeSpeech();
    _voice.startListening(handleWakeWord);

    setState(() => _isInitialized = true);
  }

  // The Main Controller (Orchestration)
  void handleWakeWord() async {
    try {
      // Step 1: Camera Snapshot (The Eye)
      XFile img = await _cameraController.takePicture();

      // Step 2: AI Brain & Database (The Brain)
      // This single call now handles Gemini AND saving to Firestore
      String result = await _ai.processWithGemini(img);

      // Step 3: Speak (The Voice)
      await _speak(result);

      // Step 4: Resume Listening
      _voice.startListening(handleWakeWord);
    } catch (e) {
      print("Robot Loop Error: $e");
      _voice.startListening(handleWakeWord); // Restart if something fails
    }
  }

  Future<void> _speak(String text) async {
    // Clean text to remove the (emotion) tag before speaking
    String cleanText = text.split('(').first.trim();
    await _tts.setPitch(1.3);
    await _tts.speak(cleanText);
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized)
      return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      appBar: AppBar(title: const Text("Pixie Robot Cam")),
      body: CameraPreview(_cameraController), // Show what Pixie sees
    );
  }

  @override
  void dispose() {
    _cameraController.dispose();
    _voice.stopListening();
    super.dispose();
  }
}
