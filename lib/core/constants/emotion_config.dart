import 'package:flutter/material.dart';

enum PixieEmotion { neutral, happy, angry, confused, lovely, surprised, speechless, questioning }

class EmotionParams {
  final Color color;
  final double mouthOffset;
  final double eyeSquint; 
  final String eyeShape;
  
  const EmotionParams({
    required this.color,
    this.mouthOffset = 0.0,
    this.eyeSquint = 1.0,
    this.eyeShape = 'oval',
  });
}

const Map<PixieEmotion, EmotionParams> emotionRegistry = {
  PixieEmotion.neutral: EmotionParams(color: Colors.greenAccent),
  PixieEmotion.happy: EmotionParams(color: Colors.greenAccent, eyeShape: 'arc'),
  PixieEmotion.angry: EmotionParams(color: Colors.redAccent, mouthOffset: 16.0, eyeSquint: 0.5, eyeShape: 'angry'),
  PixieEmotion.lovely: EmotionParams(color: Colors.pinkAccent, eyeShape: 'heart'),
  PixieEmotion.confused: EmotionParams(color: Colors.amberAccent, mouthOffset: -12.0),
};