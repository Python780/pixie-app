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
      duration: const Duration(milliseconds: 2500),
    )..repeat(reverse: true); 

    _glowAnimation = Tween<double>(begin: 0.3, end: 0.8).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void didUpdateWidget(EmotionAnimationWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isProcessing != oldWidget.isProcessing) {
      if (widget.isProcessing) {
        _controller.duration = const Duration(milliseconds: 1000); 
      } else {
        _controller.duration = const Duration(milliseconds: 2500); 
      }
      if (_controller.isAnimating) {
        _controller.repeat(reverse: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final String currentEmotion = widget.emotion.toLowerCase();

    Color baseGlowColor = Colors.greenAccent;
    if (widget.isProcessing) {
      baseGlowColor = Colors.cyanAccent; 
    } else if (currentEmotion == 'confused') {
      baseGlowColor = Colors.amberAccent; 
    } else if (currentEmotion == 'angry') {
      baseGlowColor = Colors.redAccent; 
    } else if (currentEmotion == 'lovely') {
      baseGlowColor = Colors.pinkAccent; 
    }

    return AnimatedBuilder(
      animation: _glowAnimation,
      builder: (context, child) {
        return Container(
          padding: const EdgeInsets.all(24), 
          decoration: const BoxDecoration(
            color: Colors.transparent, // Completely transparent container removes bounding boxes
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Independent ambient aura hub emitting a borderless neon cloud backdrop
              Positioned.fill(
                child: Center(
                  child: Container(
                    width: 140, // Expanded radius to correspond with upsized features
                    height: 90,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: baseGlowColor.withOpacity(
                            widget.isProcessing 
                                ? _glowAnimation.value * 0.35 
                                : _glowAnimation.value * 0.15,
                          ),
                          blurRadius: widget.isProcessing ? 64 : 48,
                          spreadRadius: widget.isProcessing ? 12 : 4,
                        )
                      ],
                    ),
                  ),
                ),
              ),
              widget.child,
            ],
          ),
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
