// lib/services/bluetooth_service.dart
import 'dart:developer' as dev;

//for temporary stubbing until we have the ESP32 Bluetooth connection logic implemented
class PixieBluetoothService {
  // A fake connection flag for now
  bool get isConnected => false;

  /// A mock method so your RobotProvider functions don't complain
  void sendCommandToBridge({
    required String targetModule,
    required String action,
    required int value,
  }) {
    dev.log("📡 [Bluetooth Stub] Mock sending: module=$targetModule, action=$action, value=$value");
  }
}