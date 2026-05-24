import 'dart:developer' as dev;
import 'package:speech_to_text/speech_to_text.dart';
import 'base_voice_service.dart';

class PixieVoiceInteractionService
    extends BaseVoiceService {

  String _currentInput = "";

  Future<String> listenForInput({
    int maxDurationSeconds = 10,
  }) async {

    if (isListening) return "";
    bool available = await initSpeech();

    if (!available) {
      return "";
    }

    _currentInput = "";

    try {

      await Future.delayed(
        const Duration(milliseconds: 500),
      );

      isListening = true;
      dev.log("🎤 Conversation listening START");

      await stt.listen(

        onResult: (result) async {
          _currentInput = result.recognizedWords;
          dev.log(
            "🎤 User said: $_currentInput",
          );

          // User finished speaking
          if (result.finalResult) {
            dev.log("✅ Final result received");
            await stopListening();
          }
        },

        listenMode: ListenMode.dictation,
        partialResults: true,
        cancelOnError: false,
        pauseFor: const Duration(seconds: 3),
        listenFor: Duration(
          seconds: maxDurationSeconds,
        ),
      );

      // Wait until listening ends
      int safetyCounter = 0;

      while (isListening) {
        await Future.delayed(
          const Duration(milliseconds: 200),
        );

        safetyCounter++;

        if (safetyCounter > 75) {
          dev.log("⚠️ Force stop listener");
          await stopListening();
          break;
        }
      }

      return _currentInput;

    } catch (e) {
      dev.log("Conversation listening failed: $e");
      isListening = false;
      return "";
    }
  }

  void endConversation() {
    _currentInput = "";
    stopListening();
    dev.log("👋 Conversation ended");
  }
}