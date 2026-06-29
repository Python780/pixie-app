import 'dart:async';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/bluetooth_service.dart';

enum RobotOperationMode {
  autonomous,
  handheldManual,
}

class RobotProvider with ChangeNotifier {
  final PixieBluetoothService _bluetoothService =
      PixieBluetoothService();

  StreamSubscription<String>? _telemetrySubscription;

  RobotOperationMode _currentMode =
      RobotOperationMode.handheldManual;

  String _lastSentCommand = "";

  // ==============================
  // ✅ CONSTRUCTOR
  // ==============================
  RobotProvider() {
    _bluetoothService.isConnectedNotifier.addListener(notifyListeners);
    _bluetoothService.isScanningNotifier.addListener(notifyListeners);

    // ✅ FIXED: telemetry listener
    _telemetrySubscription =
        _bluetoothService.telemetryStream.listen(_handleTelemetry);
  }

  // ==============================
  // ✅ GETTERS
  // ==============================
  bool get isConnected => _bluetoothService.isConnected;
  bool get isScanning => _bluetoothService.isScanning;

  RobotOperationMode get currentMode => _currentMode;

  bool get isAutonomous =>
      _currentMode == RobotOperationMode.autonomous;

  // ==============================
  // ✅ TELEMETRY HANDLER (FIXED)
  // ==============================
  void _handleTelemetry(String data) {
    print("ESP32 Telemetry: $data");

    // ✅ (Optional future parsing)
    // Example incoming:
    // MODE:AUTO HUMAN:1 DIST:1.23 X:0.12 TEMP:30.2 ...

    // You can parse later if needed
  }

  // ==============================
  // ✅ CONNECT BLE
  // ==============================
  Future<bool> connectBluetooth() async {
    final status = await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.location,
    ].request();

    if (status[Permission.bluetoothScan] !=
            PermissionStatus.granted ||
        status[Permission.bluetoothConnect] !=
            PermissionStatus.granted) {
      return false;
    }

    return await _bluetoothService.scanAndConnect();
  }

  // ==============================
  // ✅ DISCONNECT
  // ==============================
  Future<void> disconnectBluetooth() async {
    await _bluetoothService.disconnect();
  }

  // ==============================
  // ✅ JOYSTICK DRIVE
  // ==============================
  void drive(double x, double y) {
    if (!isConnected || isAutonomous) return;

    String xStr = x.toStringAsFixed(2);
    String yStr = y.toStringAsFixed(2);

    String command = "J:$xStr,$yStr";

    // ✅ Prevent duplicate sends
    if (command != _lastSentCommand) {
      _lastSentCommand = command;
      _bluetoothService.sendRawStringCommand(command);

      print("Sent: $command");
    }
  }

  // ==============================
  // ✅ STOP ROBOT
  // ==============================
  void stopRobot() {
    drive(0, 0);
  }

  // ==============================
  // ✅ MODE SWITCH (AUTO / MANUAL)
  // ==============================
  void setHardwareDockStatus({required bool isDocked}) {
    _currentMode = isDocked
        ? RobotOperationMode.autonomous
        : RobotOperationMode.handheldManual;

    if (isConnected) {
      String command =
          _currentMode == RobotOperationMode.autonomous ? "A" : "M";

      _bluetoothService.sendRawStringCommand(command);
      print("Sent mode command: $command");
    }

    notifyListeners();
  }

  // ==============================
  // ✅ CLEANUP
  // ==============================
  @override
  void dispose() {
    _telemetrySubscription?.cancel();
    _bluetoothService.dispose();
    super.dispose();
  }
}