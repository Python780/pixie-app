import 'package:flutter/material.dart';
import 'package:flutter_joystick/flutter_joystick.dart';

class JoystickWidget extends StatelessWidget {
  final Function(double x, double y) onMove;
  final Function(double speed) onSpeed;

  const JoystickWidget({
    super.key,
    required this.onMove,
    required this.onSpeed,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(25),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // SPEED
          buildJoystickBox(
            color: Colors.cyanAccent,
            joystick: Joystick(
              mode: JoystickMode.vertical,
              listener: (details) {
                onSpeed(details.y);
              },
            ),
          ),

          // MOVE
          buildJoystickBox(
            color: Colors.cyanAccent,
            joystick: Joystick(
              mode: JoystickMode.all,
              listener: (details) {
                onMove(details.x, details.y);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget buildJoystickBox({
    required Color color,
    required Widget joystick,
  }) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.4),
            blurRadius: 20,
          ),
        ],
      ),
      child: SizedBox(
        width: 120,
        height: 120,
        child: joystick,
      ),
    );
  }
}