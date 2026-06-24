import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/robot_provider.dart';
import '../widgets/controller/joystick_widget.dart';

/// A control interface screen featuring bluetooth hardware telemetry 
/// and an integrated dual-axis manual robot controller.
class ControllerScreen extends StatelessWidget {
  // Maintaining a strict compile-time constant constructor allows Flutter
  // to skip heavy re-render phases from parent widgets like main.dart.
  const ControllerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Listens actively to changes inside the RobotProvider state engine
    final robotProvider = Provider.of<RobotProvider>(context);

    return Scaffold(
      // Unified matte dark canvas color matching the global application theme
      backgroundColor: const Color(0xFF181A20),

      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          // Bluetooth connectivity action button
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
                // Triggers asynchronous background bluetooth handshake
                await robotProvider.connectBluetooth();
              } else {
                // Safely terminates the stream socket connection
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

      // Extends behind the status bar area for clean edge-to-edge rendering[cite: 4]
      extendBodyBehindAppBar: true, 
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 40),
            
            // Hardware Link Status HUD Element[cite: 4]
            Text(
              robotProvider.isConnected ? "ESP32 Connected" : "Disconnected",
              style: TextStyle(
                color: robotProvider.isConnected ? Colors.cyanAccent : Colors.redAccent,
                fontSize: 22,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),
            
            const Spacer(),
            
            // Core Manual Navigation Assembly[cite: 4]
            JoystickWidget(
              onMove: (x, y) {
                // DEADZONE FILTER (0.08 Value Range):
                // Filters out minor micro-movements, electrical noise, or hardware jitter 
                // when user lets go of the thumb stick. This prevents motor overheating.[cite: 4]
                const deadZone = 0.08;
                if (x.abs() < deadZone && y.abs() < deadZone) {
                  robotProvider.stopRobot(); // Commands all serial motor rails to write 0V[cite: 4]
                  return;
                }
                
                // Forwards pure x/y calculations (-1.0 to 1.0) down to the differential drive algorithm[cite: 4]
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