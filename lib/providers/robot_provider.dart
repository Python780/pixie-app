import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/bluetooth_service.dart';

enum RobotOperationMode {
  autonomous,
  handheldManual,
}

class RobotProvider with ChangeNotifier {
  final PixieBluetoothService
      _bluetoothService =
      PixieBluetoothService();

  RobotOperationMode _currentMode =
      RobotOperationMode.handheldManual;

  RobotProvider() {
    _bluetoothService
        .isConnectedNotifier
        .addListener(notifyListeners);

    _bluetoothService
        .isScanningNotifier
        .addListener(notifyListeners);
  }

  bool get isConnected =>
      _bluetoothService.isConnected;

  bool get isScanning =>
      _bluetoothService.isScanning;

  RobotOperationMode get currentMode =>
      _currentMode;

  bool get isAutonomous =>
      _currentMode ==
      RobotOperationMode.autonomous;

  Future<bool> connectBluetooth() async {
    final status = await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.location,
    ].request();

    if (status[
            Permission.bluetoothScan] !=
        PermissionStatus.granted) {
      return false;
    }

    if (status[
            Permission.bluetoothConnect] !=
        PermissionStatus.granted) {
      return false;
    }

    return await _bluetoothService
        .scanAndConnect();
  }

  Future<void>
      disconnectBluetooth() async {
    await _bluetoothService.disconnect();
  }

  void drive(
    double x,
    double y,
  ) {
    if (!isConnected) return;

    _bluetoothService
        .sendDriveCommand(
      x,
      y,
    );
  }

  void stopRobot() {
    drive(0, 0);
  }

  void setHardwareDockStatus({
    required bool isDocked,
  }) {
    _currentMode = isDocked
        ? RobotOperationMode.autonomous
        : RobotOperationMode.handheldManual;

    notifyListeners();
  }

  @override
  void dispose() {
    _bluetoothService.dispose();
    super.dispose();
  }
}