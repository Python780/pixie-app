import 'dart:async';
import 'dart:developer' as dev;
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

class PixieBluetoothService {
  static final PixieBluetoothService _instance =
      PixieBluetoothService._internal();

  factory PixieBluetoothService() => _instance;

  PixieBluetoothService._internal();

  final Guid serviceUuid = Guid("12345678");
  final Guid characteristicUuid = Guid("abcd1234");

  BluetoothDevice? currentDevice;
  BluetoothCharacteristic? targetCharacteristic;

  final ValueNotifier<bool> isConnectedNotifier = ValueNotifier(false);
  final ValueNotifier<bool> isScanningNotifier = ValueNotifier(false);

  StreamSubscription<BluetoothConnectionState>? _connectionSubscription;

  bool get isConnected => isConnectedNotifier.value;
  bool get isScanning => isScanningNotifier.value;

  Future<bool> scanAndConnect() async {
    try {
      isScanningNotifier.value = true;

      await FlutterBluePlus.startScan(
        timeout: const Duration(seconds: 5),
      );

      await for (final results in FlutterBluePlus.scanResults) {
        for (final result in results) {
          final name = result.device.advName;

          if (name.contains("ESP32")) {
            await FlutterBluePlus.stopScan();
            isScanningNotifier.value = false;

            return await connectToDevice(
              result.device,
            );
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
      // ✅ FIX: Modern versions of flutter_blue_plus require an explicit License enum argument.
      // Passing License.free declares compliant non-commercial student/hobbyist use.
      await device.connect(
        autoConnect: false,
        license: License.free,
      );

      currentDevice = device;

      _connectionSubscription = device.connectionState.listen(
        (state) {
          isConnectedNotifier.value =
              state == BluetoothConnectionState.connected;
        },
      );

      final services = await device.discoverServices();

      for (final service in services) {
        if (service.uuid == serviceUuid) {
          for (final char in service.characteristics) {
            if (char.uuid == characteristicUuid) {
              targetCharacteristic = char;
              isConnectedNotifier.value = true;

              dev.log("BLE Ready");
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

  Future<void> sendDriveCommand(double x, double y) async {
    if (targetCharacteristic == null) {
      return;
    }

    try {
      // ✅ OPTIMIZATION: .clamp(0, 255) ensures mathematical boundaries 
      // never overflow or underflow past a single standard byte limit (0-255).
      int xValue = ((x + 1) * 127).round().clamp(0, 255);
      int yValue = ((y + 1) * 127).round().clamp(0, 255);

      await targetCharacteristic!.write(
        [
          10, // Command Header/Opcode
          xValue,
          yValue,
        ],
        withoutResponse: true,
      );
    } catch (e) {
      dev.log("Drive command failed: $e");
    }
  }

  Future<void> disconnect() async {
    try {
      await currentDevice?.disconnect();
    } catch (_) {}

    currentDevice = null;
    targetCharacteristic = null;
    isConnectedNotifier.value = false;
  }

  void dispose() {
    _connectionSubscription?.cancel();
  }
}