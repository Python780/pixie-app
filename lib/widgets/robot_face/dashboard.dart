// lib/widgets/robot_face/dashboard.dart
import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../../core/constants/emotion_config.dart'; 
import 'eyes_widget.dart';
import 'mouth_widget.dart';
import 'emotion_animation.dart';

class DashboardWidget extends StatefulWidget {
  final String emotion;
  final bool isTalking;
  final bool isProcessing;
  final double baseSize;

  const DashboardWidget({
    super.key,
    required this.emotion,
    required this.isTalking,
    required this.isProcessing,
    this.baseSize = 68.0, 
  });

  @override
  State<DashboardWidget> createState() => _DashboardWidgetState();
}

class _DashboardWidgetState extends State<DashboardWidget> with TickerProviderStateMixin {
  late AnimationController _blinkController;
  late Animation<double> _blinkScaleAnimation;
  
  // Controller handling dynamic changes for special symbols (Question Mark / Angry Vein)
  late AnimationController _symbolController;
  late Animation<double> _symbolScaleAnimation;
  late Animation<double> _symbolYOffsetAnimation;

  // Controller handling the rhythmic up-and-down cute bobbing effect for the entire face
  late AnimationController _faceHopController;
  late Animation<double> _faceYOffsetAnimation;

  // Controller dedicated to the pulsing "heartbeat" blinking effect for Lovely (Heart) Eyes
  late AnimationController _lovePulseController;
  late Animation<double> _loveScaleAnimation;
  
  Timer? _blinkSchedulerTimer;
  Timer? _talkingTimer;
  bool _talkingMouthState = false;
  final Random _random = Random();

  @override
  void initState() {
    super.initState();
    
    // 1. Flat blinking animation sequence for standard expressions
    _blinkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );
    _blinkScaleAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween<double>(begin: 1.0, end: 0.1).chain(CurveTween(curve: Curves.easeInQuad)), weight: 45),
      TweenSequenceItem(tween: Tween<double>(begin: 0.1, end: 1.0).chain(CurveTween(curve: Curves.easeOutCubic)), weight: 55),
    ]).animate(_blinkController);
    
    // 2. Rhythmic floating movement loop for top status symbols
    _symbolController = AnimationController(
      vsync: this, // Fixed argument typo from sync to vsync
      duration: const Duration(milliseconds: 600),
    )..repeat(reverse: true);

    _symbolScaleAnimation = Tween<double>(begin: 0.9, end: 1.12).animate(
      CurvedAnimation(parent: _symbolController, curve: Curves.easeInOut),
    );
    _symbolYOffsetAnimation = Tween<double>(begin: 0.0, end: -6.0).animate(
      CurvedAnimation(parent: _symbolController, curve: Curves.easeInOut),
    );

    // 3. Jelly-like up-and-down bobbing animation for the complete face canvas
    _faceHopController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    )..repeat(reverse: true);

    _faceYOffsetAnimation = Tween<double>(begin: 0.0, end: 8.0).animate(
      CurvedAnimation(parent: _faceHopController, curve: Curves.easeInOutQuad),
    );

    // 4. Custom pulsing heartbeat curve exclusive to the Lovely Eye setup
    _lovePulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1300),
    )..repeat();

    _loveScaleAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween<double>(begin: 1.0, end: 1.22).chain(CurveTween(curve: Curves.easeOutBack)), weight: 15),
      TweenSequenceItem(tween: Tween<double>(begin: 1.22, end: 0.90).chain(CurveTween(curve: Curves.easeInQuad)), weight: 15),
      TweenSequenceItem(tween: Tween<double>(begin: 0.90, end: 1.10).chain(CurveTween(curve: Curves.easeOut)), weight: 15),
      TweenSequenceItem(tween: Tween<double>(begin: 1.10, end: 1.0).chain(CurveTween(curve: Curves.easeInOutQuad)), weight: 15),
      TweenSequenceItem(tween: Tween<double>(begin: 1.0, end: 1.0).chain(CurveTween(curve: Curves.linear)), weight: 40),
    ]).animate(_lovePulseController);

    _scheduleNextBlink();
  }

  @override
  void didUpdateWidget(DashboardWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isTalking != oldWidget.isTalking) {
      if (widget.isTalking) {
        _startTalkingAnimation();
      } else {
        _stopTalkingAnimation();
      }
    }
  }

  void _scheduleNextBlink() {
    _blinkSchedulerTimer?.cancel();
    final int nextBlinkDelay = 4000 + _random.nextInt(3500); 
    _blinkSchedulerTimer = Timer(Duration(milliseconds: nextBlinkDelay), () {
      if (!mounted) return;
      final emo = widget.emotion.toLowerCase();
      if (emo == 'neutral' && !widget.isProcessing) {
        _blinkController.forward(from: 0.0).then((_) => _scheduleNextBlink());
      } else {
        _scheduleNextBlink(); 
      }
    });
  }

  void _startTalkingAnimation() {
    _talkingTimer?.cancel();
    _talkingTimer = Timer.periodic(const Duration(milliseconds: 120), (timer) {
      if (mounted) setState(() { _talkingMouthState = !_talkingMouthState; });
    });
  }

  void _stopTalkingAnimation() {
    _talkingTimer?.cancel();
    if (mounted) setState(() { _talkingMouthState = false; });
  }

  @override
  Widget build(BuildContext context) {
    String targetEmotion = widget.emotion.toLowerCase();
    if (targetEmotion == 'confused') {
      targetEmotion = 'questioning';
    }

    final PixieEmotion currentEmotion = PixieEmotion.values.firstWhere(
      (e) => e.name.toLowerCase() == targetEmotion,
      orElse: () => PixieEmotion.neutral,
    );

    final bool isLoveEmotion = targetEmotion == 'love' || targetEmotion == 'lovely';
    final bool activeTalkingState = widget.isTalking ? _talkingMouthState : false;
    final bool showQuestionMark = targetEmotion == 'questioning';
    final bool showAngrySymbol = targetEmotion == 'angry';

    final params = emotionRegistry[currentEmotion] ?? emotionRegistry[PixieEmotion.neutral]!;
    final Color symbolColor = params.color;

    return EmotionAnimationWidget( 
      emotion: targetEmotion,
      isProcessing: widget.isProcessing,
      child: Center(
        child: AnimatedBuilder(
          animation: Listenable.merge([_blinkScaleAnimation, _symbolController, _faceHopController, _loveScaleAnimation]),
          builder: (context, child) {
            final double currentBlinkHeight = isLoveEmotion ? 120.0 : (120.0 * _blinkScaleAnimation.value);
            final double currentEyeScale = isLoveEmotion ? _loveScaleAnimation.value : 1.0;
            final double currentFaceHop = _faceYOffsetAnimation.value;

            return SizedBox(
              width: 240.0,
              height: 240.0,
              child: Stack(
                clipBehavior: Clip.none, 
                children: [
                  
                  // 1. Cute Dual-Eye Component Layer
                  Positioned.fromRect(
                    rect: Rect.fromCenter(
                      center: Offset(120, 110 + currentFaceHop), 
                      width: 280, 
                      height: currentBlinkHeight, 
                    ),
                    child: Transform.scale(
                      scale: currentEyeScale,
                      child: EyesWidget(
                        emotion: currentEmotion, 
                        blinkScale: isLoveEmotion ? 1.0 : _blinkScaleAnimation.value, 
                      ),
                    ),
                  ),
                  
                  // 2. Cute Expression Mouth Layer
                  // FIXED POSITION: Placed at 185.0 to achieve the precise spacing seen in the questioning face[cite: 1]
                  // FIXED LENGTH: Scaled width by 0.48 to duplicate the exact length profile[cite: 1]
                  Positioned(
                    top: 185.0 + currentFaceHop, 
                    left: 0, right: 0,
                    child: Center(
                      child: MouthWidget(
                        isTalking: activeTalkingState, 
                        emotion: currentEmotion,
                        baseSize: widget.baseSize * 0.48, 
                      ),
                    ),
                  ),

                  // 3. Floating Question Mark Status Overlay
                  Positioned(
                    top: -6.0 + _symbolYOffsetAnimation.value, 
                    right: 12.0,  
                    child: AnimatedOpacity(
                      duration: const Duration(milliseconds: 250),
                      opacity: showQuestionMark ? 1.0 : 0.0,
                      child: Text(
                        '?',
                        style: TextStyle(
                          color: widget.isProcessing ? Colors.cyanAccent : symbolColor,
                          fontSize: widget.baseSize * 0.7, 
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Comic Sans MS', 
                          shadows: [
                            Shadow(
                              color: (widget.isProcessing ? Colors.cyanAccent : symbolColor).withOpacity(0.8),
                              blurRadius: 14,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // 4. Angry Pop/Vein Vector Status Overlay
                  Positioned(
                    top: -4.0,
                    right: 18.0,
                    child: AnimatedOpacity(
                      duration: const Duration(milliseconds: 250),
                      opacity: showAngrySymbol ? 1.0 : 0.0,
                      child: Transform.scale(
                        scale: _symbolScaleAnimation.value, 
                        child: CustomPaint(
                          size: const Size(36, 36),
                          painter: AngrySymbolPainter(color: symbolColor), 
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  @override
  void dispose() {
    _blinkController.dispose();
    _symbolController.dispose();
    _faceHopController.dispose();
    _lovePulseController.dispose(); 
    _blinkSchedulerTimer?.cancel();
    _talkingTimer?.cancel();
    super.dispose();
  }
}

class AngrySymbolPainter extends CustomPainter {
  final Color color;
  AngrySymbolPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.5
      ..strokeCap = StrokeCap.round;

    final double w = size.width;
    final double h = size.height;
    final double padding = w * 0.15;

    canvas.drawArc(Rect.fromLTWH(padding, padding, w * 0.35, h * 0.35), 3.14, 1.57, false, paint);
    canvas.drawArc(Rect.fromLTWH(w * 0.5, padding, w * 0.35, h * 0.35), 4.71, 1.57, false, paint);
    canvas.drawArc(Rect.fromLTWH(padding, h * 0.5, w * 0.35, h * 0.35), 1.57, 1.57, false, paint);
    canvas.drawArc(Rect.fromLTWH(w * 0.5, h * 0.5, w * 0.35, h * 0.35), 0.0, 1.57, false, paint);
    
    canvas.drawLine(Offset(w * 0.5, padding), Offset(w * 0.5, h - padding), paint);
    canvas.drawLine(Offset(padding, h * 0.5), Offset(w - padding, h * 0.5), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}