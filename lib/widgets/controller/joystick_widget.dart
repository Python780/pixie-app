import 'package:flutter/material.dart';
import 'package:flutter_joystick/flutter_joystick.dart';

class JoystickWidget extends StatelessWidget {
  final Function(double x, double y) onMove;

  const JoystickWidget({
    super.key,
    required this.onMove,
  });

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size.width * 0.65;

    return Center(
      child: Joystick(
        mode: JoystickMode.all,
        listener: (details) {
          onMove(details.x, details.y);
        },
        // FIXED: Putting our design directly inside the 'base' property allows the 
        // package to see the sizing bounds and restores your center thumb stick.
        base: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            // Dark gray panel surface matching the settings theme
            color: const Color(0xFF22252E),
            border: Border.all(
              color: Colors.cyanAccent.withOpacity(0.5), // Boosted opacity for a brighter ring
              width: 1.5,
            ),
            boxShadow: [
              // GLOW LAYER 1: Sharp high-intensity neon core reflection
              BoxShadow(
                color: Colors.cyanAccent.withOpacity(0.25),
                blurRadius: 15,
                spreadRadius: 1,
              ),
              // GLOW LAYER 2: Wide ambient sci-fi bloom aura
              BoxShadow(
                color: Colors.cyanAccent.withOpacity(0.12),
                blurRadius: 35,
                spreadRadius: 4,
              ),
            ],
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Decorative inner technical ring
              Container(
                width: size * 0.72,
                height: size * 0.72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.cyanAccent.withOpacity(0.25),
                    width: 1,
                  ),
                ),
              ),
              
              // High-visibility directional symbols
              Positioned(
                top: 16,
                child: Icon(Icons.keyboard_double_arrow_up_rounded, 
                    color: Colors.cyanAccent.withOpacity(0.75), size: 22),
              ),
              Positioned(
                bottom: 16,
                child: Icon(Icons.keyboard_double_arrow_down_rounded, 
                    color: Colors.cyanAccent.withOpacity(0.75), size: 22),
              ),
              Positioned(
                left: 16,
                child: Icon(Icons.keyboard_double_arrow_left_rounded, 
                    color: Colors.cyanAccent.withOpacity(0.75), size: 22),
              ),
              Positioned(
                right: 16,
                child: Icon(Icons.keyboard_double_arrow_right_rounded, 
                    color: Colors.cyanAccent.withOpacity(0.75), size: 22),
              ),
            ],
          ),
        ),
        // Custom ultra-glowing movement stick
        stick: const SciFiJoystickStick(),
      ),
    );
  }
}

// =======================================================
// HIGH-INTENSITY NEON STICK KNOCK
// =======================================================
class SciFiJoystickStick extends StatelessWidget {
  const SciFiJoystickStick({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        // Solid dark background context to pop cleanly against the chevrons
        color: const Color(0xFF181A20),
        border: Border.all(
          color: Colors.cyanAccent,
          width: 2.5, // Thicker border profile for crisp sci-fi hardware tracking
        ),
        boxShadow: [
          // Powerful localized handle neon light bloom
          BoxShadow(
            color: Colors.cyanAccent.withOpacity(0.6),
            blurRadius: 16,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Center(
        // High-energy center point core indicator
        child: Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.cyanAccent,
            boxShadow: [
              // White hot laser-core highlight effect
              BoxShadow(
                color: Colors.white.withOpacity(0.8),
                blurRadius: 4,
                spreadRadius: 1,
              ),
            ],
          ),
        ),
      ),
    );
  }
}