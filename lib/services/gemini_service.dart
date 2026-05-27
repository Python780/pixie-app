import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:camera/camera.dart';
import 'dart:developer' as dev;
import 'firebase_service.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'dart:convert';

class GeminiService {
  late GenerativeModel _model;
  final FirebaseService _dbService = FirebaseService();
  late final String _preferredModel;
  late final String _fallbackModel;

  /// Must initialize the device user before saving interactions.
  Future<void> initialize() async {
    final apiKey = dotenv.env['GEMINI_API_KEY'] ?? '';
    if (apiKey.isEmpty) {
      dev.log('Gemini API key not configured. Set GEMINI_API_KEY in .env');
    }
    // Use a supported Gemini model for the current v1beta API.
    // If the preferred model is unavailable, fall back to another compatible
    // Gemini model instead of the deprecated chat-bison model.
    _preferredModel = dotenv.env['GEMINI_MODEL'] ?? 'gemini-2.5-flash';
    _fallbackModel = dotenv.env['GEMINI_FALLBACK_MODEL'] ?? 'gemini-2.5-pro';
    _model = GenerativeModel(model: _preferredModel, apiKey: apiKey);
    await _dbService.initializeDeviceUser();
  }

  /// Original method: Analyze facial expression from image
  Future<String> processWithGemini(XFile imageFile) async {
    final apiKey = dotenv.env['GEMINI_API_KEY'] ?? '';
    if (apiKey.isEmpty) {
      dev.log('Gemini API key not configured. Set GEMINI_API_KEY in .env');
      return 'Gemini API key not configured. Please set GEMINI_API_KEY in .env';
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
        response = await _model.generateContent(content);
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
            final apiKey2 = dotenv.env['GEMINI_API_KEY'] ?? '';
            _model = GenerativeModel(model: _fallbackModel, apiKey: apiKey2);
            response = await _model.generateContent(content);
          } catch (e2) {
            dev.log('Fallback generateContent also failed: $e2');
            throw e2;
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
    XFile? imageFile,
    String? conversationHistory,
  }) async {
    final apiKey = dotenv.env['GEMINI_API_KEY'] ?? '';
    if (apiKey.isEmpty) {
      dev.log('Gemini API key not configured. Set GEMINI_API_KEY in .env');
      return {
        'response':
            'Gemini API key not configured. Please set GEMINI_API_KEY in .env',
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

      // Build system prompt with conversation context
      final systemPrompt =
          """You are Pixie, a friendly and helpful robot assistant.

Give the user a normal conversational reply first. Do not wrap the reply in JSON.
If you need to include metadata, put it after the reply in a separate JSON object,
but always start with the plain answer on the first line.

If there are multiple people in the image, analyze every detected face. Label the nearest person as Person 1, the next nearest as Person 2, and so on.
Return a summary of each detected person as well as the overall conversational reply.

Conversation context: ${conversationHistory ?? "(new conversation)"}
User just said: "$userInput"
${imageFile != null ? "Camera image available for facial analysis." : "(No camera image)"}

Example output:
I'm happy to help! (happy)

{"response": "I'm happy to help! (happy)", "emotion": "happy", "facial_analysis": "Person 1 appears calm, Person 2 appears curious.", "face_emotion": "calm", "face_confidence": "medium", "faces": [{"person": "Person 1", "emotion": "calm", "confidence": "medium"}, {"person": "Person 2", "emotion": "curious", "confidence": "low"}]}
""";

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
        response = await _model.generateContent(content);
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
            final apiKey2 = dotenv.env['GEMINI_API_KEY'] ?? '';
            _model = GenerativeModel(model: _fallbackModel, apiKey: apiKey2);
            response = await _model.generateContent(content);
            fullText = response.text ?? "{}";
          } catch (e2) {
            dev.log('Fallback generateContent also failed: $e2');
            throw e2;
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
    final lines = fullText.trim().split(RegExp(r'\r?\n'));
    if (lines.isNotEmpty) {
      final firstLine = lines.first.trim();
      if (firstLine.isNotEmpty && !firstLine.startsWith('{')) {
        return firstLine;
      }
    }

    return null;
  }
}
