// lib/widgets/robot_face/eyes_widget.dart
import 'package:flutter/material.dart';
import '../../core/constants/emotion_config.dart';

class EyesWidget extends StatelessWidget {
  final PixieEmotion emotion;
  final double blinkScale;

  const EyesWidget({super.key, required this.emotion, required this.blinkScale});

  @override
  Widget build(BuildContext context) {
    final params = emotionRegistry[emotion] ?? emotionRegistry[PixieEmotion.neutral]!;
    
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildEye(params, emotionName: emotion.name, isLeft: true),
        const SizedBox(width: 64),
        _buildEye(params, emotionName: emotion.name, isLeft: false),
      ],
    );
  }

  Widget _buildEye(EmotionParams params, {required String emotionName, required bool isLeft}) {
    Widget painter;
    
    if (emotionName == 'questioning') {
      painter = CustomPaint(painter: QuestioningEyePainter(color: params.color, isLeft: isLeft));
    } else if (emotionName == 'crying' || emotionName == 'sad') {
      painter = CustomPaint(painter: CryingEyePainter(color: params.color, isLeft: isLeft));
    } else {
      switch (params.eyeShape) {
        case 'heart': painter = CustomPaint(painter: HeartPainter(color: params.color)); break;
        case 'angry': painter = CustomPaint(painter: AngryEyePainter(color: params.color, isLeft: isLeft)); break;
        case 'arc': painter = CustomPaint(painter: EyeArcPainter(color: params.color, strokeWidth: 14)); break;
        default: painter = CustomPaint(painter: PerfectOvalPainter(color: params.color));
      }
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      height: 120.0 * params.eyeSquint * blinkScale,
      width: 100.0,
      child: painter,
    );
  }
}

// 共享基础猫咪大圆眼高光
void _drawCatHighlights(Canvas canvas, Size size) {
  final mainHighlight = Paint()..color = Colors.white.withOpacity(0.85)..style = PaintingStyle.fill;
  final subHighlight = Paint()..color = Colors.white.withOpacity(0.45)..style = PaintingStyle.fill;
  canvas.drawCircle(Offset(size.width * 0.68, size.height * 0.32), size.width * 0.13, mainHighlight);
  canvas.drawCircle(Offset(size.width * 0.36, size.height * 0.68), size.width * 0.07, subHighlight);
}

// --- 基础大圆眼 ---
class PerfectOvalPainter extends CustomPainter {
  final Color color; PerfectOvalPainter({required this.color});
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawOval(Rect.fromLTWH(0, 0, size.width, size.height), Paint()..color = color);
    _drawCatHighlights(canvas, size);
  }
  @override bool shouldRepaint(covariant CustomPainter old) => false;
}

// --- ✨ 升级版：晶莹剔透爱心眼 (带动漫猫咪微光) ---
class HeartPainter extends CustomPainter {
  final Color color; 
  HeartPainter({required this.color});
  
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color..style = PaintingStyle.fill;
    final path = Path();
    
    // 绘制完美的爱心贝塞尔曲线
    path.moveTo(size.width / 2, size.height / 4);
    path.cubicTo(0, -size.height / 2, -size.width / 2, size.height / 2, size.width / 2, size.height);
    path.cubicTo(size.width * 1.5, size.height / 2, size.width, -size.height / 2, size.width / 2, size.height / 4);
    canvas.drawPath(path, paint);

    // ✨ 注入灵魂：在爱心饱满的右上侧弧瓣、左下侧，精确点缀通透的白色高光
    final mainHighlight = Paint()..color = Colors.white.withOpacity(0.82)..style = PaintingStyle.fill;
    final subHighlight = Paint()..color = Colors.white.withOpacity(0.4)..style = PaintingStyle.fill;
    
    // 右瓣主高光圆圈
    canvas.drawCircle(Offset(size.width * 0.72, size.height * 0.35), size.width * 0.09, mainHighlight);
    // 左瓣辅高光小圆圈
    canvas.drawCircle(Offset(size.width * 0.34, size.height * 0.46), size.width * 0.05, subHighlight);
  }
  @override bool shouldRepaint(covariant CustomPainter old) => false;
}

// --- 哭泣宽面条泪眼 ---
class CryingEyePainter extends CustomPainter {
  final Color color; final bool isLeft;
  CryingEyePainter({required this.color, required this.isLeft});
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color..style = PaintingStyle.fill;
    final tearPaint = Paint()..color = Colors.cyanAccent.withOpacity(0.85)..style = PaintingStyle.fill;
    canvas.save();
    final clipPath = Path();
    if (isLeft) {
      clipPath.moveTo(0, size.height * 0.45);
      clipPath.quadraticBezierTo(size.width * 0.45, size.height * 0.22, size.width, size.height * 0.28);
    } else {
      clipPath.moveTo(0, size.height * 0.28);
      clipPath.quadraticBezierTo(size.width * 0.55, size.height * 0.22, size.width, size.height * 0.45);
    }
    clipPath.lineTo(size.width, size.height); clipPath.lineTo(0, size.height); clipPath.close();
    canvas.clipPath(clipPath);
    canvas.drawOval(Rect.fromLTWH(0, 0, size.width, size.height), paint);
    _drawCatHighlights(canvas, size);
    canvas.restore();

    final tearPath = Path();
    if (isLeft) {
      tearPath.moveTo(size.width * 0.15, size.height * 0.75);
      tearPath.quadraticBezierTo(size.width * 0.05, size.height * 1.1, size.width * 0.1, size.height * 1.4);
      tearPath.lineTo(size.width * 0.35, size.height * 1.4);
      tearPath.quadraticBezierTo(size.width * 0.4, size.height * 1.1, size.width * 0.4, size.height * 0.82);
    } else {
      tearPath.moveTo(size.width * 0.6, size.height * 0.82);
      tearPath.quadraticBezierTo(size.width * 0.6, size.height * 1.1, size.width * 0.65, size.height * 1.4);
      tearPath.lineTo(size.width * 0.9, size.height * 1.4);
      tearPath.quadraticBezierTo(size.width * 0.95, size.height * 1.1, size.width * 0.85, size.height * 0.75);
    }
    tearPath.close(); canvas.drawPath(tearPath, tearPaint);
  }
  @override bool shouldRepaint(covariant CustomPainter old) => false;
}

// --- 生气眼 ---
class AngryEyePainter extends CustomPainter {
  final Color color; final bool isLeft;
  AngryEyePainter({required this.color, required this.isLeft});
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color..style = PaintingStyle.fill;
    canvas.save(); final clipPath = Path();
    if (isLeft) {
      clipPath.moveTo(0, size.height * 0.25);
      clipPath.quadraticBezierTo(size.width * 0.55, size.height * 0.28, size.width, size.height * 0.58);
    } else {
      clipPath.moveTo(0, size.height * 0.58);
      clipPath.quadraticBezierTo(size.width * 0.44, size.height * 0.28, size.width, size.height * 0.25);
    }
    clipPath.lineTo(size.width, size.height); clipPath.lineTo(0, size.height); clipPath.close();
    canvas.clipPath(clipPath);
    canvas.drawOval(Rect.fromLTWH(0, 0, size.width, size.height), paint);
    _drawCatHighlights(canvas, size);
    canvas.restore();
  }
  @override bool shouldRepaint(covariant CustomPainter old) => false;
}

// --- 疑问眼 ---
class QuestioningEyePainter extends CustomPainter {
  final Color color; final bool isLeft;
  QuestioningEyePainter({required this.color, required this.isLeft});
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color..style = PaintingStyle.fill;
    canvas.save(); final clipPath = Path();
    if (isLeft) {
      clipPath.moveTo(0, size.height * 0.32);
      clipPath.quadraticBezierTo(size.width * 0.5, size.height * 0.38, size.width, size.height * 0.32);
    } else {
      clipPath.moveTo(0, size.height * 0.5); 
      clipPath.quadraticBezierTo(size.width * 0.45, size.height * 0.24, size.width, size.height * 0.2); 
    }
    clipPath.lineTo(size.width, size.height); clipPath.lineTo(0, size.height); clipPath.close();
    canvas.clipPath(clipPath);
    canvas.drawOval(Rect.fromLTWH(0, 0, size.width, size.height), paint);
    _drawCatHighlights(canvas, size);
    canvas.restore();
  }
  @override bool shouldRepaint(covariant CustomPainter old) => false;
}

// --- 弧形眼 ---
class EyeArcPainter extends CustomPainter {
  final Color color; final double strokeWidth;
  EyeArcPainter({required this.color, required this.strokeWidth});
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = strokeWidth..strokeCap = StrokeCap.round;
    canvas.drawArc(Rect.fromLTWH(0, 0, size.width, size.height * 2), 3.14, 3.14, false, paint);
  }
  @override bool shouldRepaint(covariant CustomPainter old) => false;
}