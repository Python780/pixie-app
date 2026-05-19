import 'package:flutter/material.dart';
import 'eyes_widget.dart';
import 'mouth_widget.dart';
import 'emotion_animation.dart';

class DashboardWidget extends StatelessWidget {
  final String emotion;
  final bool isTalking;
  final bool isProcessing;

  const DashboardWidget({
    super.key,
    required this.emotion,
    required this.isTalking,
    required this.isProcessing,
  });

  @override
  Widget build(BuildContext context) {
    return EmotionAnimationWidget( // 1. emotion animation wrapper that can trigger global effects based on the current emotion and processing state
      emotion: emotion,
      isProcessing: isProcessing,
      child: Column(
        children: [
          // 2. implement your eyes as a separate widget that reacts to both emotion and processing state (e.g. blinking faster when processing, changing shape based on emotion)
          EyesWidget(emotion: emotion, isProcessing: isProcessing),
          const SizedBox(height: 30),
          // 3. implement your mouth as a separate widget that reacts to talking state and emotion (e.g. open when talking, change shape based on emotion)
          MouthWidget(isTalking: isTalking, emotion: emotion),
        ],
      ),
    );
  }
}