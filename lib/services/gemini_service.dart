// 1. Switch to the standard Google AI package
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:camera/camera.dart';
import 'dart:developer' as dev; // For production-safe logging
import 'firebase_service.dart';

class GeminiService {
  static const String _modelName = 'gemini-1.5-flash';
  static const String _apiKey =
      'AIzaSyCeCrpXzz89taPkOOaZeOt28pvUxdtOAd8'; // TODO: Load from environment/config

  late final GenerativeModel _model;
  final FirebaseService _dbService = FirebaseService();

  GeminiService() {
    _model = GenerativeModel(model: _modelName, apiKey: _apiKey);
  }

  Future<String> processWithGemini(XFile imageFile) async {
    try {
      final imageBytes = await imageFile.readAsBytes();

      // In this package, the parts are TextPart and DataPart
      final prompt = [
        Content.multi([
          TextPart(
            "Analyze this face as Pixie the Robot. Reply in 1 short sentence with an emotion in (brackets).",
          ),
          DataPart('image/jpeg', imageBytes),
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
