import 'package:flutter/material.dart';
import 'package:flutter_joystick/flutter_joystick.dart';

class JoystickWidget extends StatelessWidget {
  final Function(double x, double y) onMove;

  const JoystickWidget({
    super.key,
    required this.onMove,
  });

  @override
  Widget build(BuildContext context) {
    final size =
        MediaQuery.of(context).size.width * 0.55;

    return Center(
      child: Container(
        width: size,
        height: size,

        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: Colors.cyanAccent,
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.cyanAccent.withOpacity(0.35),
              blurRadius: 30,
            ),
          ],
        ),

        child: Joystick(
          mode: JoystickMode.all,

          listener: (details) {
            onMove(
              details.x,
              details.y,
            );
          },
        ),
      ),
    );
  }
}