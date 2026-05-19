import 'package:flutter/material.dart';
import '../services/bluetooth_service.dart';
import 'dart:developer' as dev;

enum RobotOperationMode { autonomous, handheldManual }

class RobotProvider with ChangeNotifier {
  final PixieBluetoothService _bluetoothService = PixieBluetoothService();
  RobotOperationMode _currentMode = RobotOperationMode.autonomous;

  RobotOperationMode get currentMode => _currentMode;
  bool get isAutonomous => _currentMode == RobotOperationMode.autonomous;
  //bool get isConnected => _bluetoothService.isConnected;
  bool get isConnected => false; // Placeholder until Bluetooth connection logic is implemented

  /// Call this when hardware sensors detect the phone is plucked out or plugged in
  void setHardwareDockStatus({required bool isDocked}) {
    if (isDocked) {
      _currentMode = RobotOperationMode.autonomous;
      stopRobot(); // Safe clear of manual speeds
    } else {
      _currentMode = RobotOperationMode.handheldManual;
    }
    notifyListeners(); // This instantly swaps the UI layout on the phone screen!
  }

  // ================= 🤖 AUTO TRACK: SENDING AI COMMANDS OVER BLUETOOTH =================
  void dispatchAiEmotion(String emotion) {
    if (_currentMode == RobotOperationMode.handheldManual) return; // Ignore AI requests if handheld
    
    dev.log("🤖 [Simulated Face Command] Emotion: $emotion");
    //_bluetoothService.sendCommandToBridge(
    //  targetModule: "face", 
    //  action: emotion, 
    //  value: 1
    //);
  }

  // ================= 🕹️ MANUAL TRACK: HANDHELD JOYSTICK OVER BLUETOOTH =================
  //void moveForward(int speed) {
  //  if (isAutonomous) return;
  //  _bluetoothService.sendCommandToBridge(targetModule: "motor", action: "forward", value: speed);
  //}

  //void stopRobot() {
  //  _bluetoothService.sendCommandToBridge(targetModule: "motor", action: "stop", value: 0);
  //}
  void moveForward(int speed) {
    if (isAutonomous) return;
    
    dev.log("🕹️ [Simulated Motor Command] Direction: Forward, Speed: $speed");
    
    // Commented out to bypass missing ESP32 connection:
    /*
    _bluetoothService.sendCommandToBridge(targetModule: "motor", action: "forward", value: speed);
    */
  }

  void moveBackward(int speed) {
    if (isAutonomous) return;
    dev.log("🕹️ [Simulated Motor Command] Direction: Backward, Speed: $speed");
    // _bluetoothService.sendCommandToBridge(targetModule: "motor", action: "backward", value: speed);
  }

  void turnLeft(int speed) {
    if (isAutonomous) return;
    dev.log("🕹️ [Simulated Motor Command] Direction: Left, Speed: $speed");
    // _bluetoothService.sendCommandToBridge(targetModule: "motor", action: "left", value: speed);
  }

  void turnRight(int speed) {
    if (isAutonomous) return;
    dev.log("🕹️ [Simulated Motor Command] Direction: Right, Speed: $speed");
    // _bluetoothService.sendCommandToBridge(targetModule: "motor", action: "right", value: speed);
  }

  void stopRobot() {
    dev.log("🕹️ [Simulated Motor Command] Direction: STOP");
  }
  // Add backward, left, right methods matching your original signature...
}