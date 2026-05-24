import 'package:camera/camera.dart';
import 'dart:developer' as dev;
import 'package:permission_handler/permission_handler.dart';

class PixieCameraService {
  CameraController? _controller;
  bool _initialized = false;

  bool get isInitialized => _initialized;

  Future<void> initializeCamera() async {
    if (_initialized) return;

    try {
      var status = await Permission.camera.status;

      if (!status.isGranted) {
        status = await Permission.camera.request();

        if (!status.isGranted) {
          dev.log('🚫 Camera permission denied');
          return;
        }
      }

      final cameras = await availableCameras();

      if (cameras.isEmpty) {
        dev.log('📷 No camera available');
        return;
      }

      final cameraIndex = cameras.length > 1 ? 1 : 0;

      _controller = CameraController(
        cameras[cameraIndex],
        ResolutionPreset.medium,
        enableAudio: false,
      );

      await _controller!.initialize();

      _initialized = true;

      dev.log('✅ Camera initialized once');
    } catch (e) {
      dev.log('Camera init error: $e');
    }
  }

  Future<XFile?> captureFrame() async {
    try {
      if (!_initialized || _controller == null) {
        dev.log('⚠️ Camera not initialized');
        return null;
      }

      return await _controller!.takePicture();
    } catch (e) {
      dev.log('Capture error: $e');
      return null;
    }
  }

  Future<void> disposeCamera() async {
    try {
      await _controller?.dispose();
      _initialized = false;
      dev.log('📷 Camera disposed');
    } catch (e) {
      dev.log('Dispose camera error: $e');
    }
  }
}