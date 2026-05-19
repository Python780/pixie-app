import 'package:flutter/material.dart';

class EyesWidget extends StatelessWidget {
  final String emotion;
  final bool isProcessing;

  const EyesWidget({
    super.key, 
    required this.emotion, 
    required this.isProcessing
  });

  @override
  Widget build(BuildContext context) {
    // Determine target eye color base vectors
    Color eyeColor = isProcessing ? Colors.cyanAccent : Colors.greenAccent;
    double height = 44;
    double width = 44;
    BorderRadius radius = BorderRadius.circular(22);

    // Apply explicit shape variants matching Gemini's structural responses
    switch (emotion.toLowerCase()) {
      case 'happy':
        height = 18;
        radius = const BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        );
        break;
      case 'thoughtful':
        width = 24;
        height = 44;
        radius = BorderRadius.circular(8);
        break;
      case 'confused':
        eyeColor = Colors.amberAccent;
        break;
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: List.generate(2, (index) {
        // Create an asymmetrical height variance if Pixie is confused
        final dualHeight = (emotion.toLowerCase() == 'confused' && index == 1) ? 22.0 : height;
        final dualWidth = (emotion.toLowerCase() == 'confused' && index == 1) ? 22.0 : width;

        return AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
          width: dualWidth,
          height: dualHeight,
          decoration: BoxDecoration(
            color: eyeColor,
            borderRadius: radius,
            boxShadow: [
              BoxShadow(
                color: eyeColor.withOpacity(0.4), 
                blurRadius: 12, 
                spreadRadius: 2
              ),
            ],
          ),
        );
      }),
    );
  }
}