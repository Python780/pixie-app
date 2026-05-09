import 'dart:math';
import 'package:flutter/material.dart';

class StarryBackground extends StatelessWidget {
  const StarryBackground({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Color(0xFF0A0F1F), // 深蓝黑
            Color.fromARGB(255, 21, 33, 75), // 偏亮蓝
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: CustomPaint(
        painter: StarPainter(0.5), // 传递一个初始动画值
        size: Size.infinite,
      ),
    );
  }
}

class StarPainter extends CustomPainter {
  final double animationValue;
  // 固定位置，防止乱跳
  static final List<Offset> _stars = List.generate(100, (_) => Offset(Random().nextDouble(), Random().nextDouble()));

  StarPainter(this.animationValue);

  @override
  void paint(Canvas canvas, Size size) {
    // 1. 基础明亮度：调高基础透明度
    final double opacity = (animationValue * 0.7) + 0.3; // 确保最暗时也不完全消失

    // 2. star
    final mainPaint = Paint()..color = Colors.white.withOpacity(opacity);

    // 3. glowing
    final glowPaint = Paint()
      ..color = Colors.white.withOpacity(opacity * 0.5)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3); // 添加模糊边缘

    for (var star in _stars) {
      
      double dx = (star.dx + (animationValue * 0.05)) % 1.0; // 向右慢移
      double dy = (star.dy + (animationValue * 0.02)) % 1.0; // 向下慢移
      
      final pos = Offset(dx * size.width, dy * size.height);

      // 先画一层大的模糊光晕
      canvas.drawCircle(pos, 2.5, glowPaint); 
      // 再画中心的小亮点
      canvas.drawCircle(pos, 1.2, mainPaint); 
    }
  }

  @override
  bool shouldRepaint(StarPainter oldDelegate) => oldDelegate.animationValue != animationValue;
}