import 'dart:async';
import 'dart:convert';
import 'dart:developer' as dev;
import 'package:flutter/material.dart'; // REQUIRED FOR VALUENOTIFIER
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

class PixieBluetoothService {
  static final PixieBluetoothService _instance = PixieBluetoothService._internal();
  factory PixieBluetoothService() => _instance;
  PixieBluetoothService._internal();

  final Guid serviceUuid = Guid("12345678");
  final Guid characteristicUuid = Guid("abcd1234");

  BluetoothDevice? currentDevice;
  BluetoothCharacteristic? targetCharacteristic;

  // Now ValueNotifier will be recognized perfectly
  final isConnectedNotifier = ValueNotifier<bool>(false);
  final isScanningNotifier = ValueNotifier<bool>(false);
  
  final StreamController<String> _telemetryController = StreamController<String>.broadcast();
  Stream<String> get telemetryStream => _telemetryController.stream;

  StreamSubscription<BluetoothConnectionState>? _connectionSubscription;
  StreamSubscription<List<int>>? _valueSubscription;

  bool get isConnected => isConnectedNotifier.value;
  bool get isScanning => isScanningNotifier.value;

  Future<bool> scanAndConnect() async {
    try {
      isScanningNotifier.value = true;
      await FlutterBluePlus.startScan(timeout: const Duration(seconds: 5));

      await for (final results in FlutterBluePlus.scanResults) {
        for (final result in results) {
          if (result.device.advName.contains("ESP32")) {
            await FlutterBluePlus.stopScan();
            isScanningNotifier.value = false;
            return await connectToDevice(result.device);
          }
        }
      }
    } catch (e) { 
      dev.log("Scan error: $e"); 
    }
    isScanningNotifier.value = false;
    return false;
  }

  Future<bool> connectToDevice(BluetoothDevice device) async {
    try {
      await device.connect(autoConnect: false, license: License.free);
      currentDevice = device;

      _connectionSubscription = device.connectionState.listen((state) {
        isConnectedNotifier.value = state == BluetoothConnectionState.connected;
      });

      final services = await device.discoverServices();
      for (final service in services) {
        if (service.uuid == serviceUuid) {
          for (final char in service.characteristics) {
            if (char.uuid == characteristicUuid) {
              targetCharacteristic = char;
              isConnectedNotifier.value = true;

              await char.setNotifyValue(true);
              _valueSubscription = char.onValueReceived.listen((value) {
                String rawString = utf8.decode(value);
                _telemetryController.add(rawString);
              });

              dev.log("BLE Service & Characteristic Ready");
              return true;
            }
          }
        }
      }
    } catch (e) { 
      dev.log("Connection failed: $e"); 
    }
    return false;
  }

  Future<void> sendRawStringCommand(String command) async {
    if (targetCharacteristic == null) return;
    try {
      await targetCharacteristic!.write(
        command.codeUnits, 
        withoutResponse: true,
      );
    } catch (e) { 
      dev.log("Failed to send command ($command): $e"); 
    }
  }

  Future<void> disconnect() async {
    try {
      await _valueSubscription?.cancel();
      await currentDevice?.disconnect();
    } catch (_) {}
    currentDevice = null;
    targetCharacteristic = null;
    isConnectedNotifier.value = false;
  }

  void dispose() {
    _connectionSubscription?.cancel();
    _valueSubscription?.cancel();
    _telemetryController.close();
  }
}