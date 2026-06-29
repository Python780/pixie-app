import 'dart:async';
import 'dart:convert';
import 'dart:developer' as dev;
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

class PixieBluetoothService {
  static final PixieBluetoothService _instance =
      PixieBluetoothService._internal();

  factory PixieBluetoothService() => _instance;
  PixieBluetoothService._internal();

  // ✅ UUIDs (MATCH ESP32)
  final Guid serviceUuid = Guid("12345678");
  final Guid characteristicUuid = Guid("abcd1234");       // TELEMETRY
  final Guid controlCharacteristicUuid = Guid("abcd5678"); // COMMAND

  BluetoothDevice? currentDevice;

  BluetoothCharacteristic? telemetryCharacteristic; // READ/NOTIFY
  BluetoothCharacteristic? controlCharacteristic;   // WRITE

  final isConnectedNotifier = ValueNotifier<bool>(false);
  final isScanningNotifier = ValueNotifier<bool>(false);

  final StreamController<String> _telemetryController =
      StreamController<String>.broadcast();

  Stream<String> get telemetryStream => _telemetryController.stream;

  StreamSubscription<BluetoothConnectionState>? _connectionSubscription;
  StreamSubscription<List<int>>? _valueSubscription;

  bool get isConnected => isConnectedNotifier.value;
  bool get isScanning => isScanningNotifier.value;

  // ✅ SCAN + CONNECT
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

  // ✅ CONNECT + DISCOVER SERVICES
  Future<bool> connectToDevice(BluetoothDevice device) async {
    try {
      
        await device.connect(
          autoConnect: false,
          license: License.free,
        );

      currentDevice = device;

      _connectionSubscription =
          device.connectionState.listen((state) {
        isConnectedNotifier.value =
            state == BluetoothConnectionState.connected;
      });

      final services = await device.discoverServices();

      for (final service in services) {
        if (service.uuid == serviceUuid) {
          for (final char in service.characteristics) {

            // ✅ TELEMETRY CHARACTERISTIC
            if (char.uuid == characteristicUuid) {
              telemetryCharacteristic = char;

              await char.setNotifyValue(true);

              _valueSubscription =
                  char.onValueReceived.listen((value) {
                try {
                  String rawString = utf8.decode(value);
                  _telemetryController.add(rawString);
                } catch (e) {
                  dev.log("Decode error: $e");
                }
              });

              dev.log("Telemetry characteristic ready");
            }

            // ✅ CONTROL CHARACTERISTIC (FIXED)
            if (char.uuid == controlCharacteristicUuid) {
              controlCharacteristic = char;
              dev.log("Control characteristic ready");
            }
          }
        }
      }

      // ✅ Ensure BOTH are ready
      if (telemetryCharacteristic != null &&
          controlCharacteristic != null) {
        isConnectedNotifier.value = true;
        dev.log("BLE FULLY READY ✅");
        return true;
      }

    } catch (e) {
      dev.log("Connection failed: $e");
    }

    return false;
  }

  // ✅ ✅ FIXED: SEND COMMAND TO CORRECT CHARACTERISTIC
  Future<void> sendRawStringCommand(String command) async {
    if (controlCharacteristic == null) {
      dev.log("Control characteristic NOT ready");
      return;
    }

    try {
      await controlCharacteristic!.write(
        command.codeUnits,
        withoutResponse: true,
      );

      dev.log("Sent command: $command");
    } catch (e) {
      dev.log("Failed to send command ($command): $e");
    }
  }

  // ✅ DISCONNECT
  Future<void> disconnect() async {
    try {
      await _valueSubscription?.cancel();
      await _connectionSubscription?.cancel();
      await currentDevice?.disconnect();
    } catch (_) {}

    currentDevice = null;
    telemetryCharacteristic = null;
    controlCharacteristic = null;
    isConnectedNotifier.value = false;
  }

  void dispose() {
    _connectionSubscription?.cancel();
    _valueSubscription?.cancel();
    _telemetryController.close();
  }
}