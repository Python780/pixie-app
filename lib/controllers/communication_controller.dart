//import 'package:pixie/services/gemini_service.dart';
//import 'package:pixie/controllers/robot_controller.dart';
//import 'package:pixie/providers/conversation_provider.dart';

class CommunicationController {
  final GeminiService geminiService;
  final RobotController robotController;
  final ConversationProvider conversationProvider;

  CommunicationController({
    required this.geminiService,
    required this.robotController,
    required this.conversationProvider,
  });
}

handleUserInput(String text) async {
  final reply = await geminiService.askGemini(text);

  robotController.speak(reply);
  conversationProvider.addMessage(reply);
}