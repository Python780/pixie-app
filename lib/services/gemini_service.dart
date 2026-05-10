import 'package:firebase_ai/firebase_ai.dart';
import 'package:camera/camera.dart';
import 'dart:developer' as dev; // For production-safe logging
import 'firebase_service.dart';

class GeminiService {
  // Initialize the 2026 Gemini 3 Flash model
  final _model = FirebaseAI.googleAI().generativeModel(
    model: 'gemini-3-flash'
    );

  final FirebaseService _dbService = FirebaseService();

  Future<String> processWithGemini(XFile imageFile) async {
    try {
      final imageBytes = await imageFile.readAsBytes();

      // In this package, the parts are TextPart and DataPart
      final prompt = [
        Content.multi([
          TextPart(
            "Analyze this face as Pixie the Robot. Reply in 1 short sentence with an emotion in (brackets).",
          ),
          InlineDataPart('image/jpeg', imageBytes),
        ]),
      ];

      final response = await _model.generateContent(prompt);
      final responseText = response.text ?? "I see you! (happy)";

      // Save to Firebase (storage only, no AI logic here)
      await _dbService.saveInteraction(responseText);

      return responseText;
    } catch (e, stackTrace) {
      // Fixed the 'print' warning with a developer log
      dev.log("Gemini Brain Error", error: e, stackTrace: stackTrace);
      return "I'm having a little trouble thinking right now. (neutral)";
    }
  }
}
