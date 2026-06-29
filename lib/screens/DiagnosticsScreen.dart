import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/robot_provider.dart';

class DiagnosticsScreen extends StatelessWidget {
  const DiagnosticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final robotProvider = context.watch<RobotProvider>();
    final bool connected = robotProvider.isConnected;
    final String operationMode = robotProvider.isAutonomous 
        ? "Autonomous (Auto-Follow)" 
        : "Manual Joystick Drive";

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        title: const Text("System Diagnostics"),
        backgroundColor: Colors.black,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Section 1: Connection Status Banner
          const SectionTitle("Connection Status"),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: connected ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: connected ? Colors.greenAccent.withOpacity(0.3) : Colors.redAccent.withOpacity(0.3),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  connected ? Icons.check_circle : Icons.error, 
                  color: connected ? Colors.greenAccent : Colors.redAccent,
                  size: 28,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    // FIXED: Typo removed here
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        connected ? "Robot Connected" : "Robot Disconnected",
                        style: TextStyle(
                          color: connected ? Colors.greenAccent : Colors.redAccent, 
                          fontSize: 16, 
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        connected 
                            ? "All hardware control links running optimally." 
                            : "Please establish a device connection in the Settings menu.",
                        style: const TextStyle(color: Colors.white70, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const Divider(color: Colors.white24, height: 40),

          // Section 2: Real-Time Metrics
          const SectionTitle("Hardware Metrics"),
          _buildHealthTile(
            "ESP32 MCU Status", 
            connected ? "Online" : "Offline", 
            Icons.memory, 
            connected ? Colors.greenAccent : Colors.redAccent,
          ),
          
          _buildHealthTile(
            "Active Control Mode", 
            connected ? operationMode : "Unknown", 
            Icons.settings_suggest_rounded, 
            connected ? Colors.cyanAccent : Colors.white24,
          ),
          _buildHealthTile(
            "BLE Data Channel", 
            connected ? "Connected (Low Latency)" : "Inactive", 
            Icons.bluetooth_connected, 
            connected ? Colors.greenAccent : Colors.redAccent,
          ),
        ],
      ),
    );
  }

  Widget _buildHealthTile(String title, String status, IconData icon, Color color) {
    return Card(
      color: Colors.white.withOpacity(0.02),
      margin: const EdgeInsets.symmetric(vertical: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: ListTile(
        leading: Icon(icon, color: color),
        title: Text(title, style: const TextStyle(color: Colors.white, fontSize: 15)),
        trailing: Text(
          status, 
          style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 14),
        ),
      ),
    );
  }
}

class SectionTitle extends StatelessWidget {
  final String title;
  const SectionTitle(this.title, {super.key});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Text(
      title, 
      style: const TextStyle(
        color: Colors.cyanAccent, 
        fontWeight: FontWeight.bold, 
        fontSize: 16,
        letterSpacing: 0.5,
      ),
    ),
  );
}