// lib/widgets/robot_face/mouth_widget.dart
import 'package:flutter/material.dart';

class MouthWidget extends StatelessWidget {
  final bool isTalking;
  final String emotion;

  const MouthWidget({
    super.key, 
    required this.isTalking, 
    required this.emotion
  });

  @override
  Widget build(BuildContext context) {
    final String currentEmotion = emotion.toLowerCase();
    
    // Configure standard mouth dimensions
    double width = currentEmotion == 'happy' ? 110.0 : 64.0;
    double height = isTalking ? 24.0 : 6.0; // Rapid vertical sizing change based on TTS state
    
    Color mouthColor = currentEmotion == 'confused' ? Colors.amberAccent : Colors.greenAccent;

    return AnimatedContainer(
      duration: Duration(milliseconds: isTalking ? 120 : 300),
      curve: Curves.easeInOut,
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: mouthColor,
        borderRadius: BorderRadius.circular(12),
      ),
    );
  }
}