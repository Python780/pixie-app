import 'package:firebase_ai/firebase_ai.dart';
import 'package:camera/camera.dart';
import 'firebase_service.dart'; // Ensure this matches your filename

class GeminiService {
  // Initialize the 2026 Gemini 3 Flash model
  final _model = FirebaseAI.instance.googleAI(
    modelName: 'gemini-3-flash',
    apiKey: 'AIzaSyCeCrpXzz89taPkOOaZeOt28pvUxdtOAd8',
  );

  final FirebaseService _dbService = FirebaseService();

  Future<String> processWithGemini(XFile imageFile) async {
    try {
      final imageBytes = await imageFile.readAsBytes();

      final prompt = [
        Content.multi([
          TextPart(
            "Analyze this face as Pixie the Robot. Reply in 1 short sentence with an emotion in (brackets).",
          ),
          DataPart('image/jpeg', imageBytes),
        ]),
      ];

      // Generate the AI response
      final response = await _model.generateContent(prompt);
      final responseText = response.text ?? "I see you! (happy)";

      // AUTOMATIC MEMORY: Save to Firestore immediately
      // This uses the 60-minute filter logic we built in the Firebase Service
      await _dbService.saveInteraction(responseText);

      return responseText;
    } catch (e) {
      print("Gemini Brain Error: $e");
      return "I'm having a little trouble thinking right now. (neutral)";
    }
  }
}
