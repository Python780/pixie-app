import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/robot_provider.dart';
import '../widgets/controller/joystick_widget.dart';

class ControllerScreen extends StatelessWidget {
  const ControllerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final robotProvider = Provider.of<RobotProvider>(context);

    return Scaffold(
      backgroundColor: const Color(0xFF181A20),

      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(
              robotProvider.isConnected ? Icons.bluetooth_connected : Icons.bluetooth,
              color: robotProvider.isConnected ? Colors.cyanAccent : Colors.white54,
              size: 28,
            ),
            onPressed: () async {
              if (!robotProvider.isConnected) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('🔍 Scanning for Pixie...')),
                );
                await robotProvider.connectBluetooth();
              } else {
                await robotProvider.disconnectBluetooth();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('🔌 Disconnected')),
                );
              }
            },
          ),
          const SizedBox(width: 10), 
        ],
      ),

      extendBodyBehindAppBar: true, 
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 40),
            Text(
              robotProvider.isConnected ? "ESP32 Connected" : "Disconnected",
              style: TextStyle(
                color: robotProvider.isConnected ? Colors.cyanAccent : Colors.redAccent,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const Spacer(),
            JoystickWidget(
              onMove: (x, y) {
                const deadZone = 0.08;
                if (x.abs() < deadZone && y.abs() < deadZone) {
                  robotProvider.stopRobot();
                  return;
                }
                robotProvider.drive(x, y);
              },
            ),
            const Spacer(),
          ],
        ),
      ),
    );
  }
}