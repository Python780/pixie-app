import 'dart:async';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/bluetooth_service.dart';

enum RobotOperationMode { autonomous, handheldManual }

class RobotProvider with ChangeNotifier {
  final PixieBluetoothService _bluetoothService = PixieBluetoothService();
  StreamSubscription<String>? _telemetrySubscription;

  RobotOperationMode _currentMode = RobotOperationMode.handheldManual;
  String _lastSentCommand = ""; 
  
  // App state for the battery percentage
  int _batteryPercent = 100; // Defaults to 100%

  RobotProvider() {
    _bluetoothService.isConnectedNotifier.addListener(notifyListeners);
    _bluetoothService.isScanningNotifier.addListener(notifyListeners);
    
    // Listen for incoming data strings from the ESP32
    _telemetrySubscription = _bluetoothService.telemetryStream.listen(_handleTelemetry);
  }

  bool get isConnected => _bluetoothService.isConnected;
  bool get isScanning => _bluetoothService.isScanning;
  RobotOperationMode get currentMode => _currentMode;
  bool get isAutonomous => _currentMode == RobotOperationMode.autonomous;
  
  // Public getter so screens can display the exact charge number
  int get batteryPercent => _batteryPercent;

  void _handleTelemetry(String data) {
    data = data.trim();
    // If the data packet looks like "B:85", parse the number 85
    if (data.startsWith("B:")) {
      String valueStr = data.substring(2);
      int? parsedValue = int.tryParse(valueStr);
      if (parsedValue != null) {
        _batteryPercent = parsedValue;
        notifyListeners(); // Force UI screens to refresh immediately
      }
    }
  }

  Future<bool> connectBluetooth() async {
    final status = await [Permission.bluetoothScan, Permission.bluetoothConnect, Permission.location].request();
    if (status[Permission.bluetoothScan] != PermissionStatus.granted || status[Permission.bluetoothConnect] != PermissionStatus.granted) {
      return false;
    }
    return await _bluetoothService.scanAndConnect();
  }

  Future<void> disconnectBluetooth() async {
    await _bluetoothService.disconnect();
  }

  void drive(double x, double y) {
    if (!isConnected || isAutonomous) return;
    String xStr = x.toStringAsFixed(2);
    String yStr = y.toStringAsFixed(2);
    String targetCommand = "J:$xStr,$yStr";

    if (targetCommand != _lastSentCommand) {
      _lastSentCommand = targetCommand;
      _bluetoothService.sendRawStringCommand(targetCommand);
    }
  }

  void stopRobot() { drive(0, 0); }

  void setHardwareDockStatus({required bool isDocked}) {
    _currentMode = isDocked ? RobotOperationMode.autonomous : RobotOperationMode.handheldManual;
    if (isConnected) {
      _bluetoothService.sendRawStringCommand(_currentMode == RobotOperationMode.autonomous ? "A" : "M");
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _telemetrySubscription?.cancel();
    _bluetoothService.dispose();
    super.dispose();
  }
}