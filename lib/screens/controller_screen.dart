import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/robot_provider.dart';
import '../widgets/controller/joystick_widget.dart';

class ControllerScreen extends StatelessWidget {
  const ControllerScreen({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final robotProvider =
        Provider.of<RobotProvider>(
      context,
    );

    return Scaffold(
      backgroundColor:
          const Color(0xFF181A20),

      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 40),

            Text(
              robotProvider.isConnected
                  ? "ESP32 Connected"
                  : "Disconnected",
              style: TextStyle(
                color: robotProvider
                        .isConnected
                    ? Colors.cyanAccent
                    : Colors.redAccent,
                fontSize: 22,
                fontWeight:
                    FontWeight.bold,
              ),
            ),

            const Spacer(),

            JoystickWidget(
              onMove: (
                x,
                y,
              ) {
                const deadZone =
                    0.08;

                if (x.abs() <
                        deadZone &&
                    y.abs() <
                        deadZone) {
                  robotProvider
                      .stopRobot();
                  return;
                }

                robotProvider.drive(
                  x,
                  y,
                );
              },
            ),

            const Spacer(),
          ],
        ),
      ),
    );
  }
}