import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:camera/camera.dart';
import 'dart:developer' as dev;
import 'firebase_service.dart';

class GeminiService {
  // 1. Initialize with new API Key from AI Studio
  final _model = GenerativeModel(
    model: 'gemini-3-flash-preview', // Flash is fastest for robot interactions
    apiKey: 'AQ.Ab8RN6KKFeKwpNCngBZ1VoBW2DsKuqwXJRamggs58SHQpWR9CQ',
  );

  final FirebaseService _dbService = FirebaseService();

  /// Original method: Analyze facial expression from image
  Future<String> processWithGemini(XFile imageFile) async {
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

      // 3. Generate content
      final response = await _model.generateContent(content);
      final responseText = response.text ?? "I see you! (happy)";

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
  Future<Map<String, String>> conversationWithGemini({
    required String userInput,
    XFile? imageFile,
    String? conversationHistory,
  }) async {
    try {
      final parts = <Part>[];

      // Build system prompt with conversation context
      final systemPrompt =
          """You are Pixie, a friendly and helpful robot assistant. Respond with TWO parts:

1. FACIAL_ANALYSIS: Brief description of user's facial expression/emotion if camera image available. Analyze all the face on screen as Pixie the Robot. Format: "User appears [emotion/expression]"
2. RESPONSE: Your conversational reply (1-2 sentences) with your emotion in (brackets).

Conversation context: ${conversationHistory ?? "(new conversation)"}
User just said: "$userInput"
${imageFile != null ? "Camera image available for facial analysis." : "(No camera image)"}

Format your response as:
FACIAL_ANALYSIS: [description]
RESPONSE: [your response with emotion in brackets]""";

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
      final response = await _model.generateContent(content);
      final fullText =
          response.text ??
          "FACIAL_ANALYSIS: Unable to analyze\nRESPONSE: I'm having trouble thinking. (confused)";

      // Parse response into facial analysis and conversation response
      final facialAnalysis = _extractSection(fullText, "FACIAL_ANALYSIS");
      final conversationResponse = _extractSection(fullText, "RESPONSE");

      // Save interaction
      try {
        await _dbService.saveInteraction(
          "User: $userInput\nFacial: $facialAnalysis\nPixie: $conversationResponse",
        );
      } catch (e) {
        dev.log("DB Save failed: $e");
      }

      return {
        'response': conversationResponse.isEmpty
            ? "That's interesting! (thoughtful)"
            : conversationResponse,
        'facial': facialAnalysis.isEmpty ? "Unable to analyze" : facialAnalysis,
      };
    } catch (e) {
      dev.log("Gemini Conversation Error: $e");
      return {
        'response': "I'm having trouble thinking right now. (confused)",
        'facial': "Error analyzing facial expression",
      };
    }
  }

  /// Helper to extract sections from response
  String _extractSection(String text, String sectionName) {
    try {
      final pattern = RegExp(
        '$sectionName:\\s*(.+?)(?=(?:FACIAL_ANALYSIS|RESPONSE)|\\z)',
        multiLine: true,
      );
      final match = pattern.firstMatch(text);
      if (match != null) {
        return match.group(1)?.trim() ?? "";
      }
      // Fallback: if no section markers, treat entire text as response
      if (sectionName == "RESPONSE") {
        return text.trim();
      }
      return "";
    } catch (e) {
      dev.log("Error extracting section $sectionName: $e");
      return "";
    }
  }
}
