import 'dart:developer' as dev;
import 'dart:math' as math;
import 'package:speech_to_text/speech_to_text.dart';
import 'base_voice_service.dart';

class PixieVoiceInteractionService extends BaseVoiceService {
  String _currentInput = "";
  double _maxSoundLevel = 0.0;
  double _currentSoundLevel = 0.0;
  static const double _minSpeechLevel = 4.0;

  Future<String> listenForInput({int maxDurationSeconds = 10}) async {
    if (isListening) return "";
    bool available = await initSpeech();

    if (!available) {
      return "";
    }

    _currentInput = "";

    try {
      await Future.delayed(const Duration(milliseconds: 500));

      isListening = true;
      dev.log("🎤 Conversation listening START");

      await stt.listen(
        onResult: (result) async {
          _currentInput = result.recognizedWords;
          dev.log(
            "🎤 User said: $_currentInput"
            " [final=${result.finalResult} confidence=${result.confidence}]",
          );

          if (result.finalResult) {
            final bool loudEnough = _maxSoundLevel >= _minSpeechLevel;
            final bool confidentEnough = result.confidence > 0.5;
            if (_currentInput.trim().isNotEmpty &&
                (loudEnough || confidentEnough)) {
              dev.log("✅ Final result received and accepted");
              await stopListening();
            } else {
              dev.log(
                "⚠️ Final result ignored due to low volume/confidence "
                "(level=${_maxSoundLevel.toStringAsFixed(1)}, "
                "confidence=${result.confidence})",
              );
            }
          }
        },
        onSoundLevelChange: (level) {
          _currentSoundLevel = level;
          _maxSoundLevel = math.max(_maxSoundLevel, level);
        },
        listenMode: ListenMode.dictation,
        partialResults: true,
        cancelOnError: false,
        pauseFor: const Duration(seconds: 5),
        listenFor: Duration(seconds: maxDurationSeconds),
      );

      // Wait until listening ends
      int safetyCounter = 0;

      while (isListening) {
        await Future.delayed(const Duration(milliseconds: 200));

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
