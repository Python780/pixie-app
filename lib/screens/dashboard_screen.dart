import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/sensor_provider.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late SensorProvider _sensorProvider;

  @override
  void initState() {
    super.initState();
    // Bind a one-time listener after the first frame renders
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _sensorProvider = Provider.of<SensorProvider>(context, listen: false);
      _sensorProvider.addListener(_errorListener);
    });
  }

  // Dedicated error listener: Handles side-effects without triggering whole-page rebuilds
  void _errorListener() {
    if (!mounted) return;
    
    final error = _sensorProvider.errorMessage;
    if (error != null && error.isNotEmpty) {
      // Dismiss the previous SnackBar before showing a new one
      ScaffoldMessenger.of(context).hideCurrentSnackBar(); 
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(
                child: Text(error, style: const TextStyle(color: Colors.white)),
              ),
            ],
          ),
          backgroundColor: Colors.red.shade700,
          duration: const Duration(seconds: 5),
          action: SnackBarAction(
            label: 'RETRY',
            textColor: Colors.cyanAccent,
            onPressed: () {
              // context.read does not trigger rebuilds
              context.read<SensorProvider>().fetchLatestData();
            },
          ),
        ),
      );
    }
  }

  @override
  void dispose() {
    // Always remove listeners to prevent memory leaks
    _sensorProvider.removeListener(_errorListener);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Zero top-level watchers here. High-frequency data streams 
    // will now only repaint their respective Consumer components.
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
        actions: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Consumer<SensorProvider>(
              builder: (context, provider, _) {
                return Center(
                  // InkWell adds the premium touch feedback ripple effect
                  child: InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: provider.isLoading ? null : () => provider.fetchLatestData(),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.cyanAccent.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        provider.isLoading ? Icons.sync : Icons.refresh,
                        color: Colors.cyanAccent,
                        size: 20,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Error Banner (Conditionally Rendered)
            Consumer<SensorProvider>(
              builder: (context, provider, _) {
                if (provider.errorMessage != null && provider.errorMessage!.isNotEmpty) {
                  return Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.red.shade900.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.red.shade700, width: 1),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.warning, color: Colors.red.shade400, size: 20),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                provider.errorMessage!,
                                style: TextStyle(color: Colors.red.shade300, fontSize: 13),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                  );
                }
                return const SizedBox.shrink();
              },
            ),

            const Text(
              "ENVIRONMENTAL SENSORS",
              style: TextStyle(color: Colors.white54, letterSpacing: 2, fontSize: 12),
            ),
            const SizedBox(height: 16),

            // Sensor Metrics Section
            Consumer<SensorProvider>(
              builder: (context, provider, _) {
                return Row(
                  children: [
                    Expanded(
                      child: SensorCard(
                        title: "TEMPERATURE",
                        value: provider.temperatureDisplay,
                        unit: "°C",
                        icon: Icons.thermostat,
                        glowColor: Colors.orange,
                        isLoading: provider.isLoading,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: SensorCard(
                        title: "HUMIDITY",
                        value: provider.humidityDisplay,
                        unit: "%",
                        icon: Icons.water_drop,
                        glowColor: Colors.cyanAccent,
                        isLoading: provider.isLoading,
                      ),
                    ),
                  ],
                );
              },
            ),

            const SizedBox(height: 32),
            const Text(
              "SYSTEM TELEMETRY",
              style: TextStyle(color: Colors.white54, letterSpacing: 2, fontSize: 12),
            ),
            const SizedBox(height: 16),

            // System Logs Section
            Consumer<SensorProvider>(
              builder: (context, provider, _) {
                return TelemetryCard(
                  lastUpdate: provider.getTimeSinceUpdate(),
                  radarValue: provider.radarDisplay,
                  isDataFresh: provider.isDataFresh(),
                );
              },
            ),
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
  final bool isLoading;

  const SensorCard({
    super.key,
    required this.title,
    required this.value,
    required this.unit,
    required this.icon,
    required this.glowColor,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF111C33), // Darker panel color
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: glowColor.withOpacity(0.3),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: glowColor.withOpacity(0.1),
            blurRadius: 10,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: glowColor, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    letterSpacing: 1,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          isLoading
              ? const SizedBox(
                  height: 40,
                  width: 40,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white54,
                  ),
                )
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      value,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      unit,
                      style: TextStyle(
                        color: glowColor,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
        ],
      ),
    );
  }
}

class TelemetryCard extends StatelessWidget {
  final String lastUpdate;
  final String radarValue;
  final bool isDataFresh;

  const TelemetryCard({
    super.key,
    required this.lastUpdate,
    required this.radarValue,
    required this.isDataFresh,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF111C33),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.cyanAccent.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          // Radar Status Row
          _buildTelemetryRow(
            icon: Icons.radar,
            label: "RADAR / MOTION",
            value: radarValue,
            valueColor: radarValue.contains("DETECTED") 
                ? Colors.redAccent 
                : Colors.cyanAccent,
          ),
          
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Divider(color: Colors.white10, height: 1),
          ),
          
          // Last Update Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.access_time, color: Colors.white54, size: 16),
                  SizedBox(width: 8),
                  Text(
                    "LAST SYNC",
                    style: TextStyle(
                      color: Colors.white54,
                      fontSize: 12,
                      letterSpacing: 1,
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  Text(
                    lastUpdate,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontFamily: 'Courier', // Gives it a terminal/log feel
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Freshness Indicator Dot
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isDataFresh ? Colors.greenAccent : Colors.redAccent,
                      boxShadow: [
                        BoxShadow(
                          color: (isDataFresh ? Colors.greenAccent : Colors.redAccent).withOpacity(0.5),
                          blurRadius: 6,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Helper method to keep the code clean
  Widget _buildTelemetryRow({
    required IconData icon, 
    required String label, 
    required String value,
    required Color valueColor,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Icon(icon, color: Colors.white54, size: 16),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white54,
                fontSize: 12,
                letterSpacing: 1,
              ),
            ),
          ],
        ),
        Text(
          value,
          style: TextStyle(
            color: valueColor,
            fontSize: 14,
            fontWeight: FontWeight.bold,
            letterSpacing: 1,
          ),
        ),
      ],
    );
  }
}