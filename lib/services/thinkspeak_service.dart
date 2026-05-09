import 'package:speech_to_text/speech_to_text.dart';

SpeechToText _speech = SpeechToText();

void initPixieEar() async {
  bool available = await _speech.initialize();
  if (available) {
    _speech.listen(
      onResult: (result) {
        String words = result.recognizedWords.toLowerCase();
        if (words.contains("hi pixie")) {
          _speech.stop(); // CRITICAL: Stop mic to allow Camera/AI to work
          triggerVision();
        }
      },
      listenMode: ListenMode.deviceDefault, // Most energy efficient
    );
  }
}
