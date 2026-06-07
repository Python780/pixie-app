import 'package:flutter/material.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF071126),

      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          "DASHBOARD",
          style: TextStyle(
            color: Colors.white,
            letterSpacing: 1.5,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),

        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "ENVIRONMENTAL SENSORS",
              style: TextStyle(
                color: Colors.white54,
                letterSpacing: 2,
                fontSize: 12,
              ),
            ),

            const SizedBox(height: 16),
            Row(
              children: const [
                Expanded(
                  child: SensorCard(
                    title: "TEMPERATURE",
                    value: "26.5",
                    unit: "°C",
                    icon: Icons.thermostat,
                    glowColor: Colors.orange,
                  ),
                ),

                SizedBox(width: 16),
                Expanded(
                  child: SensorCard(
                    title: "HUMIDITY",
                    value: "65",
                    unit: "%",
                    icon: Icons.water_drop,
                    glowColor: Colors.cyanAccent,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 32),
            const Text(
              "SYSTEM TELEMETRY",
              style: TextStyle(
                color: Colors.white54,
                letterSpacing: 2,
                fontSize: 12,
              ),
            ),

            const SizedBox(height: 16),
            const TelemetryCard(),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }
}

class SensorCard extends StatelessWidget {
  final String title;
  final String value;
  final String unit;
  final IconData icon;
  final Color glowColor;

  const SensorCard({
    super.key,
    required this.title,
    required this.value,
    required this.unit,
    required this.icon,
    required this.glowColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 170,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF1A2235),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: glowColor.withOpacity(0.7),
        ),

        boxShadow: [
          BoxShadow(
            color: glowColor.withOpacity(0.2),
            blurRadius: 20,
            spreadRadius: 1,
          ),
        ],
      ),

      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment:
                MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white54,
                  fontSize: 11,
                  letterSpacing: 1.5,
                ),
              ),

              Icon(
                icon,
                color: glowColor,
                size: 18,
              ),
            ],
          ),

          const Spacer(),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 40,
              fontWeight: FontWeight.w300,
            ),
          ),

          Text(
            unit,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
            ),
          ),

          const Spacer(),
          Container(
            height: 5,
            decoration: BoxDecoration(
              color: Colors.black26,
              borderRadius: BorderRadius.circular(10),
            ),

            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: 0.65,
              child: Container(
                decoration: BoxDecoration(
                  color: glowColor,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class TelemetryCard extends StatelessWidget {
  const TelemetryCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 220,
      decoration: BoxDecoration(
        color: const Color(0xFF1A2235),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: Colors.cyanAccent.withOpacity(0.4),
        ),
      ),

      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: const [
                Icon(
                  Icons.query_stats,
                  color: Colors.cyanAccent,
                ),

                SizedBox(width: 10),
                Text(
                  "REAL-TIME GRAPH PLOTTER",
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),

          const Spacer(),
          const Icon(
            Icons.show_chart,
            size: 70,
            color: Colors.cyanAccent,
          ),

          const SizedBox(height: 10),
          const Text(
            "Waiting for ESP32 BLE Stream...",
            style: TextStyle(
              color: Colors.white38,
              fontStyle: FontStyle.italic,
            ),
          ),
          const Spacer(),
        ],
      ),
    );
  }
}