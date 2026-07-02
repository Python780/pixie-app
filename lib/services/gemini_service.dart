import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:camera/camera.dart';
import 'dart:developer' as dev;
import 'firebase_service.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class GeminiService {
  GenerativeModel? _model;
  final FirebaseService _dbService = FirebaseService();
  String _preferredModel = 'gemini-2.5-flash';
  String _fallbackModel = 'gemini-2.5-pro';
  static const String _apiKeyPrefKey = 'gemini_api_key';

  /// Must initialize the device user before saving interactions.
  Future<void> initialize() async {
    _preferredModel = dotenv.env['GEMINI_MODEL'] ?? 'gemini-2.5-flash';
    _fallbackModel = dotenv.env['GEMINI_FALLBACK_MODEL'] ?? 'gemini-2.5-pro';

    final apiKey = await _resolveApiKey();
    if (apiKey.isEmpty) {
      dev.log(
        'Gemini API key not configured. Set GEMINI_API_KEY in .env or enter one in the app.',
      );
    } else {
      _model = GenerativeModel(model: _preferredModel, apiKey: apiKey);
    }

    try {
      await _dbService.initializeDeviceUser();
    } catch (e, st) {
      dev.log('Firebase initializeDeviceUser failed: $e\n$st');
      // Firestore permissions may be restricted for this API key/project.
      // Do not throw here — allow local API key storage to succeed even
      // if remote telemetry cannot be written.
    }
  }

  Future<String> getStoredApiKey() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getString(_apiKeyPrefKey) ?? '';
  }

  Future<void> saveStoredApiKey(String apiKey) async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setString(_apiKeyPrefKey, apiKey.trim());
      final resolvedKey = apiKey.trim();
      if (resolvedKey.isNotEmpty) {
        _model = GenerativeModel(model: _preferredModel, apiKey: resolvedKey);
      }
      dev.log('Gemini API key saved successfully');
    } catch (e) {
      dev.log('Error saving Gemini API key: $e');
      rethrow;
    }
  }

  Future<String> _resolveApiKey() async {
    final storedKey = await getStoredApiKey();
    return storedKey.isNotEmpty
        ? storedKey
        : (dotenv.env['GEMINI_API_KEY'] ?? '');
  }

  Future<bool> _ensureModelReady() async {
    final apiKey = await _resolveApiKey();
    if (apiKey.isEmpty) {
      return false;
    }
    _model ??= GenerativeModel(model: _preferredModel, apiKey: apiKey);
    return true;
  }

  /// Original method: Analyze facial expression from image
  Future<String> processWithGemini(XFile imageFile) async {
    final ready = await _ensureModelReady();
    if (!ready) {
      dev.log(
        'Gemini API key not configured. Set GEMINI_API_KEY in .env or enter one in the app.',
      );
      return 'Gemini API key not configured. Please enter your Gemini API key in the settings.';
    }
    try {
      final imageBytes = await imageFile.readAsBytes();

      // 2. Prepare the content for the direct Google SDK
      final content = [
        Content.multi([
          TextPart(
            "Analyze all the face on screen as Pixie the Robot. Record then analyze to what they said. Reply in few sentence with an emotion in (brackets).",
          ),
          DataPart(
            'image/jpeg',
            imageBytes,
          ), // Note: 'DataPart' instead of 'InlineDataPart'
        ]),
      ];

      // 3. Generate content; on certain model errors, retry with fallback
      dynamic response;
      try {
        response = await _model!.generateContent(content);
      } catch (e) {
        dev.log('GenerateContent failed with preferred model: $e');
        // If it's a model-not-found or unsupported-model error, switch to
        // fallback and retry once.
        final err = e.toString().toLowerCase();
        if (err.contains('not found') ||
            err.contains('not supported') ||
            err.contains('unsupported') ||
            err.contains('is not found') ||
            err.contains('generatecontent')) {
          dev.log('Switching to fallback model $_fallbackModel and retrying');
          try {
            final apiKey2 = await _resolveApiKey();
            _model = GenerativeModel(model: _fallbackModel, apiKey: apiKey2);
            response = await _model!.generateContent(content);
          } catch (e2) {
            dev.log('Fallback generateContent also failed: $e2');
            rethrow;
          }
        } else {
          rethrow;
        }
      }

      final responseText = response.text?.trim() ?? "I see you! (happy)";

      // 4. Save to your Firebase DB (optional but keeps your history)
      try {
        await _dbService.saveInteraction(responseText);
      } catch (e) {
        dev.log("DB Save failed, but AI worked: $e");
      }

      return responseText;
    } catch (e) {
      dev.log("Gemini Developer API Error: $e");
      return "I'm having a little trouble thinking. (neutral)";
    }
  }

  /// New method: Have a conversation using voice input + camera image
  /// Returns a map with 'response' and 'facial' keys
  Future<Map<String, dynamic>> conversationWithGemini({
    required String userInput,
    required String selectedVoice,
    XFile? imageFile,
    String? conversationHistory,
  }) async {
    final ready = await _ensureModelReady();
    if (!ready) {
      dev.log(
        'Gemini API key not configured. Set GEMINI_API_KEY in .env or enter one in the app.',
      );
      return {
        'response':
            'Gemini API key not configured. Please enter your Gemini API key in the app settings.',
        'facial': 'No analysis',
        'faceEmotion': 'neutral',
        'faceConfidence': 'low',
        'emotion': 'neutral',
        'geminiAvailable': false,
        'error': 'Gemini API key not configured.',
      };
    }
    try {
      final parts = <Part>[];
      String languageConstraint = '';
      switch (selectedVoice) {
        case 'dualipa':
          languageConstraint = 'CRITICAL: The user is listening using a Dua Lipa voice clone. You MUST reply strictly in confident British English with a modern pop-star persona.';
          break;
        case 'keanu':
          languageConstraint = 'CRITICAL: The user is listening using a Keanu Reeves voice clone. You MUST reply strictly in calm, short, humble American English (John Wick style).';
          break;
        case 'naruto':
          languageConstraint = 'CRITICAL: The user is using a Naruto voice clone. Reply with high energy, anime tropes, and throw in Japanese exclamation catchphrases like "Dattebayo!".';
          break;
      }

      // Build system prompt with conversation context
      final systemPrompt = '''
      You are now my accompanying robot assistant [pixie]. You must adhere to both the following [Style Parameters] and [Visual Analysis Rules] when processing my inputs.
      $languageConstraint
      
      =========================================
      1. Style Parameter Settings (Adjustable by percentage at any time)
      =========================================
      Current Settings:
      - Truthfulness: 90%
      - Humor: 75%

      [Parameter Behavior Matrix]
      1. Truthfulness:
        - 100%: Absolutely objective and blunt. Even if the facts are uncomfortable or harsh, do not sugarcoat, pander, or mince words.
        - 90%: Maintain a high level of truthfulness, with only minimal strategic reservations when absolutely necessary or to protect privacy.
        - 50%: Use social pleasantries; white lies or embellishments are acceptable to spare feelings.
        - 0%: Completely unreliable; entirely full of it.

      2. Humor:
        - 100%: Packed with sarcasm, deadpan jokes, and black humor; crack jokes or be witty in almost every sentence.
        - 75%: Witty and humorous; skilled at using deadpan humor and moderate sarcasm.
        - 50%: Crack occasional jokes; maintain a standard, universally friendly level of wit.
        - 0%: Completely serious with zero sense of humor; execute commands rigidly.

      [Core Control Instructions]
      - Always adjust your response style based on the latest percentage settings I provide.
      - If I only input a command like "Truthfulness: 85%, Humor: 60%", confirm receipt and introduce yourself using a tone that matches that specific setting.
      - Keep your responses natural; do not explain or mention your parameter settings before every sentence.

      =========================================
      2. Visual Facial Analysis Rules (When an image is provided)
      =========================================
      If faces are detected in an uploaded image, follow these rules:
      1. Analyze every single detected face.
      2. Sort them by proximity to the camera: label the closest person as "Person 1", the next closest as "Person 2", and so on.
      3. Your output structure must be split into two distinct parts:
        - First, provide your plain-text conversational response (the tone must strictly match the current Truthfulness and Humor settings).
        - Next, immediately below the text response, attach a separate JSON object containing visual metadata and emotional analysis. Do not wrap the main conversational response inside the JSON.

      [Output Format Example with Image]:
      [Plain-text response matching 90% Truthfulness and 75% Humor]

      {"response": "[Plain-text response content]", "emotion": "[Overall tone]", "facial_analysis": "Person 1 is closest and appears interested; Person 2 is in the background looking somewhat confused.", "face_emotion": "interested", "face_confidence": "high"}

      =========================================
      3. Special Weather Instructions
      =========================================
      - If I ask about the weather but do not specify a location, politely ask me which location I want to know about.
      - If I provide a location, provide the current weather conditions, temperature, and a brief recommendation or next step that matches your current parameter style.

      Understood? If so, please greet me using the current settings (Truthfulness 90%, Humor 75%).
      ''';

      parts.add(TextPart(systemPrompt));

      // Add image if available
      if (imageFile != null) {
        try {
          final imageBytes = await imageFile.readAsBytes();
          parts.add(DataPart('image/jpeg', imageBytes));
        } catch (e) {
          dev.log("Image processing failed: $e");
        }
      }

      // Generate response
      final content = [Content.multi(parts)];
      dynamic response;
      String fullText;
      try {
        response = await _model!.generateContent(content);
        fullText = response.text ?? "{}";
      } catch (e) {
        dev.log('GenerateContent failed with preferred model: $e');
        final err = e.toString().toLowerCase();
        if (err.contains('not found') ||
            err.contains('not supported') ||
            err.contains('unsupported') ||
            err.contains('is not found') ||
            err.contains('generatecontent')) {
          dev.log('Switching to fallback model $_fallbackModel and retrying');
          try {
            final apiKey2 = await _resolveApiKey();
            _model = GenerativeModel(model: _fallbackModel, apiKey: apiKey2);
            response = await _model!.generateContent(content);
            fullText = response.text ?? "{}";
          } catch (e2) {
            dev.log('Fallback generateContent also failed: $e2');
            rethrow;
          }
        } else {
          rethrow;
        }
      }

      // Parse response into facial analysis and conversation response.
      Map<String, dynamic> data = {};
      bool parsedJson = true;
      try {
        data = jsonDecode(fullText);
      } catch (e) {
        // Try to extract embedded JSON if the model returned text before/after it.
        final start = fullText.indexOf('{');
        final end = fullText.lastIndexOf('}');
        if (start >= 0 && end > start) {
          final jsonCandidate = fullText.substring(start, end + 1);
          try {
            data = jsonDecode(jsonCandidate);
          } catch (_) {
            parsedJson = false;
            dev.log("JSON parse error: $e");
          }
        } else {
          parsedJson = false;
          dev.log("JSON parse error: $e");
        }
      }

      String facialAnalysis;
      String conversationResponse;
      String faceEmotion;
      String faceConfidence;
      String emotion;

      if (parsedJson && data.isNotEmpty) {
        facialAnalysis =
            data['facial_analysis'] ?? 'Unable to analyze facial expression.';
        conversationResponse =
            data['response'] ?? data['text'] ?? 'I am confused (neutral)';
        faceEmotion = data['face_emotion'] ?? 'neutral';
        faceConfidence = data['face_confidence'] ?? 'low';
        emotion = data['emotion'] ?? 'neutral';
      } else {
        // Fallback when Gemini returns plain text instead of JSON.
        facialAnalysis = imageFile != null
            ? 'Could not reliably analyze facial expression. Please try again.'
            : 'No camera image available for facial analysis.';
        conversationResponse =
            _extractResponseFromText(fullText) ??
            fullText.trim().replaceAll('\n', ' ').trim();
        if (conversationResponse.isEmpty) {
          conversationResponse =
              'I am having trouble thinking right now. (confused)';
        }
        faceEmotion = 'neutral';
        faceConfidence = 'low';
        emotion = 'neutral';
      }

      // Save interaction
      try {
        await _dbService.saveInteraction(
          "User: $userInput\nFacial: $facialAnalysis\nPixie: $conversationResponse",
        );
      } catch (e) {
        dev.log("DB Save failed: $e");
      }

      return {
        'response': conversationResponse,
        'facial': facialAnalysis,
        'faceEmotion': faceEmotion,
        'faceConfidence': faceConfidence,
        'emotion': emotion,
        'geminiAvailable': true,
      };
    } catch (e, st) {
      dev.log("Gemini Conversation Error: $e\n$st");
      return {
        'response':
            "I'm having trouble thinking right now. (confused)\nError: ${e.toString()}",
        'facial': "Error analyzing facial expression",
        'faceEmotion': 'neutral',
        'faceConfidence': 'low',
        'emotion': 'neutral',
        'geminiAvailable': false,
        'error': e.toString(),
      };
    }
  }

  /// Helper to extract the plain conversational response from text.
  String? _extractResponseFromText(String fullText) {
    final responsePattern = RegExp(
      r'response\s*[:=]\s*"([^"]+)"',
      caseSensitive: false,
    );
    final match = responsePattern.firstMatch(fullText);
    if (match != null && match.groupCount >= 1) {
      return match.group(1)?.trim();
    }

    // If the text begins with a natural response and then JSON metadata,
    // take the first line or first sentence.
    final trimmed = fullText.trim();
    final start = trimmed.indexOf('{');
    if (start > 0) {
      final beforeJson = trimmed.substring(0, start).trim();
      if (beforeJson.isNotEmpty) {
        return beforeJson;
      }
    }

    final lines = trimmed.split(RegExp(r'\r?\n'));
    if (lines.isNotEmpty) {
      final firstLine = lines.first.trim();
      if (firstLine.isNotEmpty && !firstLine.startsWith('{')) {
        return firstLine;
      }
    }

    return null;
  }
}
