import 'package:flutter/material.dart';
import 'package:pixie/widgets/controller/joystick_widget.dart';
import 'package:pixie/widgets/controller/background.dart';

class ControllerScreen extends StatefulWidget {
  const ControllerScreen({super.key});

  @override
  State<ControllerScreen> createState() => _ControllerScreenState();
}

class _ControllerScreenState extends State<ControllerScreen> {
  double speed = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          const StarryBackground(),
          
      
        Column(
          children: [
            const Spacer(),

            JoystickWidget(
              onMove: (x, y) {
                print("MOVE: x=$x, y=$y");

              // connect esp32
              // sendCommand(...)
              },

              onSpeed: (s) {
                setState(() {
                  speed = s;
                });
                print("SPEED: $speed");
              },
            ),

            const SizedBox(height: 30),
          ],
        ),
      ],
     ),
    );
  }
}
