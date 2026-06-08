import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:provider/provider.dart';
import '../providers/sensor_provider.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  String? _lastError;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // Listen for errors from SensorProvider
    final sensorProvider = context.watch<SensorProvider>();

    if (sensorProvider.errorMessage != null &&
        sensorProvider.errorMessage != _lastError) {
      _lastError = sensorProvider.errorMessage;

      // Defer SnackBar to post-frame callback to avoid build-phase errors
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.error, color: Colors.white),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      sensorProvider.errorMessage!,
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                ],
              ),
              backgroundColor: Colors.red.shade700,
              duration: const Duration(seconds: 5),
              action: SnackBarAction(
                label: 'RETRY',
                textColor: Colors.cyanAccent,
                onPressed: () {
                  sensorProvider.fetchLatestData();
                },
              ),
            ),
          );
        }
      });
    }
  }

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
        actions: [
          // Refresh button
          Padding(
            padding: const EdgeInsets.all(16),
            child: Consumer<SensorProvider>(
              builder: (context, sensorProvider, _) {
                return Center(
                  child: GestureDetector(
                    onTap: () {
                      sensorProvider.fetchLatestData();
                    },
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.cyanAccent.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        sensorProvider.isLoading ? Icons.sync : Icons.refresh,
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
            // Error banner
            Consumer<SensorProvider>(
              builder: (context, sensorProvider, _) {
                if (sensorProvider.errorMessage != null &&
                    sensorProvider.errorMessage!.isNotEmpty) {
                  return Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.red.shade900.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: Colors.red.shade700,
                            width: 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.warning,
                              color: Colors.red.shade400,
                              size: 20,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                sensorProvider.errorMessage!,
                                style: TextStyle(
                                  color: Colors.red.shade300,
                                  fontSize: 13,
                                ),
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
              style: TextStyle(
                color: Colors.white54,
                letterSpacing: 2,
                fontSize: 12,
              ),
            ),

            const SizedBox(height: 16),
            Consumer<SensorProvider>(
              builder: (context, sensorProvider, _) {
                return Row(
                  children: [
                    Expanded(
                      child: SensorCard(
                        title: "TEMPERATURE",
                        value: sensorProvider.temperatureDisplay,
                        unit: "°C",
                        icon: Icons.thermostat,
                        glowColor: Colors.orange,
                        isLoading: sensorProvider.isLoading,
                      ),
                    ),

                    const SizedBox(width: 16),
                    Expanded(
                      child: SensorCard(
                        title: "HUMIDITY",
                        value: sensorProvider.humidityDisplay,
                        unit: "%",
                        icon: Icons.water_drop,
                        glowColor: Colors.cyanAccent,
                        isLoading: sensorProvider.isLoading,
                      ),
                    ),
                  ],
                );
              },
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
            Consumer<SensorProvider>(
              builder: (context, sensorProvider, _) {
                return TelemetryCard(
                  lastUpdate: sensorProvider.getTimeSinceUpdate(),
                  radarValue: sensorProvider.radarDisplay,
                  isDataFresh: sensorProvider.isDataFresh(),
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
      height: 170,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF1A2235),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: glowColor.withOpacity(0.7)),

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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white54,
                  fontSize: 11,
                  letterSpacing: 1.5,
                ),
              ),

              Icon(icon, color: glowColor, size: 18),
            ],
          ),

          const Spacer(),
          if (isLoading)
            SizedBox(
              height: 40,
              child: Center(
                child: SizedBox(
                  width: 30,
                  height: 30,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(glowColor),
                  ),
                ),
              ),
            )
          else
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 40,
                fontWeight: FontWeight.w300,
              ),
            ),

          if (!isLoading)
            Text(
              unit,
              style: const TextStyle(color: Colors.white, fontSize: 24),
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
  final String lastUpdate;
  final String radarValue;
  final bool isDataFresh;

  const TelemetryCard({
    super.key,
    this.lastUpdate = 'Never',
    this.radarValue = '0.00',
    this.isDataFresh = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 220,
      decoration: BoxDecoration(
        color: const Color(0xFF1A2235),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.cyanAccent.withOpacity(0.4)),
      ),

      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                Icon(Icons.query_stats, color: Colors.cyanAccent),

                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    "REAL-TIME TELEMETRY",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),

                // Status indicator
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: isDataFresh
                        ? Colors.green.withOpacity(0.2)
                        : Colors.orange.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    isDataFresh ? 'LIVE' : 'CACHED',
                    style: TextStyle(
                      color: isDataFresh ? Colors.green : Colors.orange,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const Spacer(),

          // Radar value display
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              Column(
                children: [
                  Icon(Icons.radar, size: 40, color: Colors.cyanAccent),
                  const SizedBox(height: 8),
                  Text(
                    'MOTION/RADAR',
                    style: const TextStyle(
                      color: Colors.white38,
                      fontSize: 9,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    radarValue,
                    style: const TextStyle(
                      color: Colors.cyanAccent,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),

              // Last update time
              Column(
                children: [
                  Icon(Icons.schedule, size: 40, color: Colors.amber),
                  const SizedBox(height: 8),
                  Text(
                    'LAST UPDATE',
                    style: const TextStyle(
                      color: Colors.white38,
                      fontSize: 9,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    lastUpdate,
                    style: const TextStyle(
                      color: Colors.amber,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),

          const Spacer(),
        ],
      ),
    );
  }
}
