// lib/widgets/robot_face/mouth_widget.dart
import 'package:flutter/material.dart';
import '../../core/constants/emotion_config.dart';

class MouthWidget extends StatelessWidget {
  final PixieEmotion emotion;
  final bool isTalking;
  final double baseSize;

  const MouthWidget({
    super.key, 
    required this.emotion, 
    required this.isTalking,
    this.baseSize = 68.0,
  });

  @override
  Widget build(BuildContext context) {
    final params = emotionRegistry[emotion] ?? emotionRegistry[PixieEmotion.neutral]!;
    
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInOutCubic,
      // Maintains the exact length designated by each specific expression context
      width: baseSize,
      height: baseSize / 2,
      transform: Matrix4.translationValues(params.mouthOffset, 0.0, 0.0),
      child: CustomPaint(
        painter: MouthPainter(
          emotion: emotion.name.toLowerCase(), 
          color: params.color, 
          isTalking: isTalking, 
          strokeWidth: 5.5,
        ),
      ),
    );
  }
}

class MouthPainter extends CustomPainter {
  final String emotion; 
  final Color color; 
  final double strokeWidth; 
  final bool isTalking;

  MouthPainter({
    required this.emotion, 
    required this.color, 
    required this.strokeWidth, 
    required this.isTalking
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeCap = StrokeCap.round;

    final path = Path();

    if (isTalking) {
      // 1. UNIVERSAL TALKING STATE: Solid, filled semi-circle that adapts to the layout length
      paint.style = PaintingStyle.fill;

      if (emotion == 'angry' || emotion == 'crying' || emotion == 'sad') {
        // Drops slightly lower down for negative expressions to maintain the sad look
        path.moveTo(0, size.height * 0.45);
        path.quadraticBezierTo(size.width / 2, size.height * 1.45, size.width, size.height * 0.45);
        path.quadraticBezierTo(size.width / 2, size.height * 0.65, 0, size.height * 0.45);
      } else if (emotion == 'happy') {
        // A wider, happier semi-circle smile
        path.moveTo(0, size.height * 0.20);
        path.quadraticBezierTo(size.width / 2, size.height * 1.40, size.width, size.height * 0.20);
        path.quadraticBezierTo(size.width / 2, size.height * 0.40, 0, size.height * 0.20);
      } else {
        // Neutral / Questioning / Default: A perfectly controlled, subtle mini semi-circle
        path.moveTo(0, size.height * 0.25);
        path.quadraticBezierTo(size.width / 2, size.height * 1.30, size.width, size.height * 0.25);
        path.quadraticBezierTo(size.width / 2, size.height * 0.45, 0, size.height * 0.25);
      }
      
      path.close();
    } else {
      // 2. IDLE STATES: Clean, high-quality line vector styles
      paint.style = PaintingStyle.stroke;
      paint.strokeWidth = strokeWidth;

      if (emotion == 'happy') {
        // Happy open expression curve
        path.moveTo(0, size.height / 2);
        path.quadraticBezierTo(size.width / 2, size.height * 1.2, size.width, size.height / 2);
      } else if (emotion == 'angry' || emotion == 'crying' || emotion == 'sad') {
        // Downward standard sad pout curve
        path.moveTo(0, size.height * 0.7);
        path.quadraticBezierTo(size.width / 2, size.height * 0.2, size.width, size.height * 0.7);
      } else {
        // Neutral: Cute, tight smile line
        path.moveTo(0, size.height * 0.25);
        path.quadraticBezierTo(size.width / 2, size.height * 0.70, size.width, size.height * 0.25);
      }
    }
    
    canvas.drawPath(path, paint);
  }

  @override 
  bool shouldRepaint(covariant MouthPainter oldDelegate) => 
      oldDelegate.isTalking != isTalking || oldDelegate.emotion != emotion;
}