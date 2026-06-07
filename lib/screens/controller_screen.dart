import 'package:flutter/material.dart';
import 'package:pixie/widgets/controller/joystick_widget.dart';
import '../providers/robot_provider.dart';
import 'package:provider/provider.dart';

class ControllerScreen extends StatefulWidget {
  
  const ControllerScreen({super.key});

  @override
  State<ControllerScreen> createState() => _ControllerScreenState();
}

class _ControllerScreenState extends State<ControllerScreen> {
  double currentSpeedRatio = 0;

  @override
  Widget build(BuildContext context) {
    final robotProvider = Provider.of<RobotProvider>(context);
    
    return Scaffold(
      backgroundColor: const Color(0xFF181A20),
      body: Stack(
        children: [
          //const StarryBackground(),
          
      
        Column(
          children: [
            const Spacer(),

            ListenableBuilder(
                listenable: robotProvider,
                builder: (context, child) {
                  final isConnected = robotProvider.isConnected;
                  return Text(
                    isConnected ? "ESP32 Connected" : "Disconnected",
                    style: TextStyle(
                      color: isConnected ? Colors.cyanAccent : Colors.redAccent,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  );
                },
              ),

              const SizedBox(height: 20),

            JoystickWidget(
                // 转向摇杆 (左右控制)
                onMove: (x, y) {
              
                  if (x < -0.3) {
                    int turnSpeed = (x.abs() * 255).toInt();
                    robotProvider.turnLeft(turnSpeed);
                  } else if (x > 0.3) {
                    int turnSpeed = (x * 255).toInt();
                    robotProvider.turnRight(turnSpeed);
                  } else if (x.abs() <= 0.3 && currentSpeedRatio.abs() <= 0.1) {
                    robotProvider.stopRobot();
                  }
                },

              onSpeed: (s) {
                setState(() {
                  currentSpeedRatio = s;
                });
                
                int targetPwm = (s.abs() * 255).toInt();

                  if (s < -0.1) {
                    // 摇杆向上推，details.y 为负数，代表前进
                    robotProvider.moveForward(targetPwm);
                  } else if (s > 0.1) {
                    // 摇杆向下推，details.y 为正数，代表后退
                    robotProvider.moveBackward(targetPwm);
                  } else {
                    // 处于正负 0.1 死区内，停止
                    robotProvider.stopRobot();
                  }
              },
            ),

            const SizedBox(height: 50),
          ],
        ),
      ],
     ),
    );
  }
}
