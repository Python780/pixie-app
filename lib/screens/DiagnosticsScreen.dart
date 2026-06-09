import 'package:flutter/material.dart';

class DiagnosticsScreen extends StatelessWidget {
  const DiagnosticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(title: const Text("Hardware Diagnostics"), backgroundColor: Colors.black),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 第一部分：ESP32 核心健康
          const SectionTitle("System Health"),
          _buildHealthTile("ESP32 Controller", "Online", Icons.memory, Colors.greenAccent),
          _buildHealthTile("Battery Level", "82% (Stable)", Icons.battery_charging_full, Colors.cyanAccent),
          _buildHealthTile("UART Bridge", "Active", Icons.link, Colors.greenAccent),
          
          const Divider(color: Colors.white24, height: 40),
          
          // 第二部分：雷达传感区
          const SectionTitle("LD2450 Radar"),
          Container(
            height: 250,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Center(
              child: Text("Radar Visualization (Canvas)", style: TextStyle(color: Colors.white54)),
            ),
          ),
          const SizedBox(height: 16),
          const ListTile(
            leading: Icon(Icons.speed, color: Colors.orangeAccent),
            title: Text("Target Speed: 0.4 m/s", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildHealthTile(String title, String status, IconData icon, Color color) {
    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(title, style: const TextStyle(color: Colors.white)),
      trailing: Text(status, style: TextStyle(color: color, fontWeight: FontWeight.bold)),
    );
  }
}

class SectionTitle extends StatelessWidget {
  final String title;
  const SectionTitle(this.title, {super.key});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Text(title, style: const TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.bold, fontSize: 18)),
  );
}