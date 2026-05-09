import 'package:speech_to_text/speech_to_text.dart';

typedef WakeWordCallback = void Function();

class PixieVoiceService {
  final SpeechToText _stt = SpeechToText();
  bool _isListening = false;

  Future<void> initializeSpeech() async {
    // Standard 2026 check for microphone permissions and hardware availability
    bool available = await _stt.initialize(
      onError: (val) => print('STT Error: $val'),
      onStatus: (val) => print('STT Status: $val'),
    );
    if (!available) {
      throw StateError(
        'Speech recognition hardware unavailable or permission denied',
      );
    }
  }

  Future<void> startListening(WakeWordCallback onWakeWord) async {
    if (_isListening) return;

    // We use the STT engine's built-in listener for the wake-word
    // This is more power-efficient than processing raw frames manually
    await _stt.listen(
      onResult: (result) {
        String words = result.recognizedWords.toLowerCase();
        if (words.contains('hi pixie')) {
          stopListening(); // Shut down the mic to free hardware for the camera
          onWakeWord(); // Trigger Phase 3 (Camera)
        }
      },
      listenMode:
          ListenMode.deviceDefault, // Optimized for 2026 mobile hardware
      cancelOnError: false,
    );

    _isListening = true;
  }

  Future<void> stopListening() async {
    if (!_isListening) return;
    await _stt.stop();
    _isListening = false;
  }
}
