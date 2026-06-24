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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _sensorProvider = Provider.of<SensorProvider>(context, listen: false);
      _sensorProvider.addListener(_errorListener);
    });
  }

  void _errorListener() {
    if (!mounted) return;
    
    final error = _sensorProvider.errorMessage;
    if (error != null && error.isNotEmpty) {
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
              context.read<SensorProvider>().fetchLatestData();
            },
          ),
        ),
      );
    }
  }

  @override
  void dispose() {
    _sensorProvider.removeListener(_errorListener);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF181A20),
      // FIXED: Wrapped the body inside a SafeArea to fix structural shifts caused by notches or status bars
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              
              // ================= FIXED CUSTOM APP BAR ROW =================
              // Replaced the buggy AppBar widget with a flexible custom Row layout 
              // to fully prevent the refresh button container from being clipped.
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "DASHBOARD",
                    style: TextStyle(
                      color: Colors.white,
                      letterSpacing: 1.5,
                      fontWeight: FontWeight.w600,
                      fontSize: 20,
                    ),
                  ),
                  Consumer<SensorProvider>(
                    builder: (context, provider, _) {
                      return InkWell(
                        borderRadius: BorderRadius.circular(8),
                        onTap: provider.isLoading ? null : () => provider.fetchLatestData(),
                        child: Container(
                          // Optimized fixed dimensions ensure the refresh circle resides comfortably inside the box
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.cyanAccent.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: Colors.cyanAccent.withOpacity(0.2),
                              width: 1,
                            ),
                          ),
                          child: Icon(
                            provider.isLoading ? Icons.sync : Icons.refresh,
                            color: Colors.cyanAccent,
                            size: 20,
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
              
              const SizedBox(height: 24),

              // Error Banner Section
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
    // FIXED: Cleans the input string to prevent duplicate unit tags (e.g., "0.0°C °C") 
    // which was pushing the layout card bounds off-screen.
    final cleanedValue = value.contains(unit) ? value.replaceAll(unit, '').trim() : value;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF22252E), 
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
                    fontSize: 11, // Sized slightly down to guarantee zero layout wrapping
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
                    // FIXED: Wrapped with Flexible and applied cleanedValue string logic 
                    // to perfectly maintain screen container integrity across all hardware devices.
                    Flexible(
                      child: Text(
                        cleanedValue,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 28, // Balanced size profile
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      unit,
                      style: TextStyle(
                        color: glowColor,
                        fontSize: 14,
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
        color: const Color(0xFF22252E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.cyanAccent.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: Column(
        children: [
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
                      fontFamily: 'Courier',
                    ),
                  ),
                  const SizedBox(width: 8),
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