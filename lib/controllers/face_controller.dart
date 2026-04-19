//import 'package:pixie/services/gemini_service.dart';
//import 'package:pixie/controllers/robot_controller.dart';
//import 'package:pixie/providers/conversation_provider.dart';

class FaceController {
  final GeminiService geminiService;
  final RobotController robotController;
  final ConversationProvider conversationProvider;

  DateTime? lastSeenTime;

  FaceController({
    required this.geminiService,
    required this.robotController,
    required this.conversationProvider,
  });

  void onFaceDetected() async {
    final now = DateTime.now();

    // Prevent spamming Gemini if the face is detected continuously
    if (lastSeenTime != null &&
        now.difference(lastSeenTime!).inSeconds < 5) {
      return;
    }

    lastSeenTime = now;

    // Chat status
    conversationProvider.setStatus("thinking");

    // Ask Gemini to greet the user
    final reply = await geminiService.askGemini(
      "Greet the user like a cute robot pet",
    );

    // Speak
    robotController.speak(reply);

    // Store
    conversationProvider.addMessage(reply);

    // Status
    conversationProvider.setStatus("talking");
  }
}