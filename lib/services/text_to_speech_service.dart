import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:developer' as dev;
import 'package:flutter_tts/flutter_tts.dart';
import 'package:http/http.dart' as http;
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart'; // Safe token manager

class PixieTextToSpeechService {
  final FlutterTts _tts = FlutterTts();
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isSpeaking = false;
  
  // Store API key once it's loaded
  late String _cachedApiKey;

  // Configuration URLs and Key extraction mappings
  final String _fishAudioBaseUrl = "https://api.fish.audio/v1/tts";
  String get _fishAudioApiKey {
    // Try to get from cache first, fallback to dotenv
    if (_cachedApiKey.isNotEmpty) {
      return _cachedApiKey;
    }
    final key = dotenv.env['FISH_AUDIO_API_KEY'] ?? '';
    if (key.isNotEmpty) {
      _cachedApiKey = key;
    }
    return key;
  }

  // Local Privacy Shield: Blocks high-risk text variations from hitting cloud networks
  final List<String> _sensitiveKeywords = [
    "password", "secret key", "credit card", "identity card", "pin number",
    "身份证", "银行卡", "密码"
  ];
  
  PixieTextToSpeechService() {
    _cachedApiKey = '';
  }

  Future<void> initialize() async {
    try {
      // Debug: Check if API key is available
      print('🔍 DEBUG TTS Init - Checking API key...');
      print('🔍 dotenv.env keys: ${dotenv.env.keys.toList()}');
      print('🔍 FISH_AUDIO_API_KEY = ${_fishAudioApiKey}');
      
      if (_fishAudioApiKey.isEmpty) {
        print('⚠️ WARNING: FISH_AUDIO_API_KEY is empty at TTS initialization!');
      } else {
        print('✅ FISH_AUDIO_API_KEY loaded successfully');
      }
      
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

      // Track playback states of custom-cloned voice tracks
      _audioPlayer.onPlayerStateChanged.listen((state) {
        if (state == PlayerState.completed || state == PlayerState.stopped) {
          _isSpeaking = false;
          dev.log("🔊 Fish Audio complete");
        } else if (state == PlayerState.playing) {
          _isSpeaking = true;
        }
      });

      dev.log("✅ Text-to-Speech initialized");
    } catch (e) {
      dev.log("TTS Initialization Failed: $e");
    }
  }

  /// Speak text aloud using native system voice (100% Offline & Private)
  Future<void> speak(String text) async {
    if (text.isEmpty) return;

    try {
      _isSpeaking = true;
      dev.log("🔊 Pixie (Native System Voice) says: $text");
      await _tts.speak(text);
    } catch (e) {
      dev.log("TTS Error: $e");
      _isSpeaking = false;
    }
  }

  /// High-fidelity AI Voice Cloning synthesis via Fish Audio cloud processing
  Future<void> speakWithFishSpeech(String text, String voiceId) async {
    if (text.isEmpty) return;

    // [PRIVACY FILTER LAYER] Scan string blocks locally before dispatching to web
    for (var keyword in _sensitiveKeywords) {
      if (text.toLowerCase().contains(keyword)) {
        dev.log("🔒 Privacy Shield: Detected sensitive keyword '$keyword'. Dropping cloud API request.");
        // Instantly fallback to device-localized native TTS processing to isolate data
        await speak(text);
        return;
      }
    }

    try {
      await stop();
      _isSpeaking = true;
      dev.log("🔊 Contacting Fish Audio cloud interface for target: $voiceId");
      print('🔍 DEBUG: speakWithFishSpeech called with voiceId: $voiceId');
      print('🔍 DEBUG: _fishAudioApiKey = ${_fishAudioApiKey}');

      if (_fishAudioApiKey.isEmpty) {
        dev.log("❌ Configuration Error: API key is empty inside .env file!");
        print('❌ ERROR: API key is empty!');
        _isSpeaking = false;
        await speak(text);
        return;
      }

      String referenceId = _mapVoiceIdToFishAudioId(voiceId);
      print('🔍 DEBUG: Mapped voiceId "$voiceId" to referenceId "$referenceId"');

      // Structure request payload matching Fish Audio OpenAPI contract
      final Map<String, dynamic> requestBody = {
        "text": text,
        "model": "s2.1-pro-free", 
        "reference_id": referenceId,
        "format": "mp3",
        "latency": "balanced"
      };

      print('🔍 DEBUG: Sending request to $_fishAudioBaseUrl with headers...');
      final response = await http.post(
        Uri.parse(_fishAudioBaseUrl),
        headers: {
          "Authorization": "Bearer $_fishAudioApiKey",
          "Content-Type": "application/json",
        },
        body: jsonEncode(requestBody),
      );

      print('🔍 DEBUG: Response status code: ${response.statusCode}');
      print('🔍 DEBUG: Response body length: ${response.body.length}');

      // [ROBUST EXCEPTION & RESPONSE CODE INTERCEPTORS]
      if (response.statusCode == 200) {
        final Uint8List audioBytes = response.bodyBytes;
        final tempDir = await getTemporaryDirectory();
        final tempFile = File('${tempDir.path}/fish_audio_cache.mp3');
        await tempFile.writeAsBytes(audioBytes);

        await _audioPlayer.play(DeviceFileSource(tempFile.path));
        dev.log("▶️ Playing custom voice signature simulation.");
        print('✅ SUCCESS: Playing Fish Audio response');
      } 
      else if (response.statusCode == 401) {
        dev.log("❌ [401 Unauthorized]: Invalid API Key. Check your .env setup or Fish Audio dashboard configuration.");
        print('❌ [401] Response: ${response.body}');
        _isSpeaking = false;
        await speak(text); // Fallback to avoid dead app silence
      } 
      else if (response.statusCode == 403 || response.statusCode == 404) {
        dev.log("❌ [${response.statusCode} Error]: Voice Character UUID '$referenceId' missing, privatized, or disabled via copyright protection checks.");
        print('❌ [${response.statusCode}] Response: ${response.body}');
        _isSpeaking = false;
        await speak(text); // Fallback to avoid dead app silence
      } 
      else if (response.statusCode == 429) {
        dev.log("❌ [429 Rate Limit]: Account API synthesis credits exhausted or frequency limits hit.");
        print('❌ [429] Response: ${response.body}');
        _isSpeaking = false;
        await speak(text); // Fallback to avoid dead app silence
      } 
      else {
        dev.log("❌ [${response.statusCode} Server Error]: ${response.body}");
        print('❌ [${response.statusCode}] Response: ${response.body}');
        _isSpeaking = false;
        await speak(text); // Fallback
      }
    } catch (e) {
      _isSpeaking = false;
      await speak("Network pipeline failed due to $e");
      dev.log("⚠️ Pipeline crash: $e");
    }
  }

  /// Stop current speech from either engine
  Future<void> stop() async {
    try {
      await _tts.stop();
      await _audioPlayer.stop();
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

  /// Maps your provider string IDs to corresponding Fish Audio Character UUIDs
  String _mapVoiceIdToFishAudioId(String voiceId) {
    switch (voiceId) {
      case 'Sarah (American English)': 
        return 'c8f64deb39914cfca7f47ccfc3bca82f';  // Sarah voice ID
      case 'glinda': 
        return 'c8f64deb39914cfca7f47ccfc3bca82f';
      case 'keanu reeves': 
        return 'b3f50c9e578f48e9a7db2f86cb3edde8';
      case 'yuta': 
        return '633aed63573a4fe7ba4c2ba8c410a0e2';
      case 'misa':
        return '651539914d6445d5adf9b203962fc71a';
      case 'sponge bob':
        return 'f2e56a18ede949129257ea66be6ef2c2';
      default: 
        return 'c8f64deb39914cfca7f47ccfc3bca82f';  // Default to Sarah
    }
  }
}