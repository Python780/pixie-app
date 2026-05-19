// lib/widgets/robot_face/emotion_animation.dart
import 'package:flutter/material.dart';

class EmotionAnimationWidget extends StatefulWidget {
  final String emotion;
  final bool isProcessing;
  final Widget child;

  const EmotionAnimationWidget({
    super.key,
    required this.emotion,
    required this.isProcessing,
    required this.child,
  });

  @override
  State<EmotionAnimationWidget> createState() => _EmotionAnimationWidgetState();
}

class _EmotionAnimationWidgetState extends State<EmotionAnimationWidget> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true); // Continuous breathing loop

    _glowAnimation = Tween<double>(begin: 0.2, end: 0.8).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _glowAnimation,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(32),
            boxShadow: widget.isProcessing
                ? [
                    BoxShadow(
                      color: Colors.cyanAccent.withOpacity(_glowAnimation.value * 0.3),
                      blurRadius: 24,
                      spreadRadius: 4,
                    )
                  ]
                : [],
          ),
          child: widget.child,
        );
      },
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}