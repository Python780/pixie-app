import 'package:camera/camera.dart';

class PixieCameraService {
  CameraController? _controller;

  Future<void> triggerVision(Function(XFile) onImageCaptured) async {
    try {
      // 1. Identify available hardware sensors
      final cameras = await availableCameras();

      // 2. Select the front-facing camera (usually index 1)
      // Use Medium resolution to keep the file size small for the Free Tier API
      _controller = CameraController(
        cameras[1],
        ResolutionPreset.medium,
        enableAudio: false, // We don't need audio for the facial scan
      );

      // 3. Initialize the sensor
      await _controller!.initialize();

      // 4. Capture the frame
      XFile image = await _controller!.takePicture();

      // 5. Handover the image to the Brain (Phase 4)
      await onImageCaptured(image);
    } catch (e) {
      print("Camera Sensor Error: $e");
    } finally {
      // 6. Power down the sensor to save energy (Critical for ESG goals)
      await _controller?.dispose();
    }
  }
}
