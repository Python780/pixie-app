import 'package:camera/camera.dart';
import 'dart:developer' as dev;

class PixieCameraService {
  CameraController? _controller;

  Future<void> triggerVision(Function(XFile) onImageCaptured) async {
    try {
      // 1. Identify available hardware sensors
      final cameras = await availableCameras();

      if (cameras.isEmpty) {
        dev.log('📷 No cameras available on this platform');
        return;
      }
      
      // 2. Select the front-facing camera (usually index 1, fallback to 0 for web/limited devices)
      final cameraIndex = cameras.length > 1 ? 1 : 0;
      // Use Medium resolution to keep the file size small for the Free Tier API
      _controller = CameraController(
        cameras[cameraIndex],
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
