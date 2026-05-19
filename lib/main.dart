import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:pixie/firebase_options.dart';
//import 'package:pixie/screens/controller_screen.dart';
import 'screens/face_screen.dart';
//import 'firebase_options.dart';

void main() async {
  // Ensure native device hardware channels (Camera/Mic) are fully ready before boot
  WidgetsFlutterBinding.ensureInitialized();
  
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const PixieRobotApp());
}

class PixieRobotApp extends StatelessWidget {
  const PixieRobotApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Pixie AI Robot Controller',
      debugShowCheckedModeBanner: false, // Clean look without the debug ribbon
      theme: ThemeData(
        brightness: Brightness.dark, // Use dark mode across the platform for a tech aesthetic
        scaffoldBackgroundColor: const Color(0xFF0F0F1A),
        primarySwatch: Colors.cyan,
      ),
      home: const FaceScreen(),// Boot directly into your responsive core routing surface
    );
  }
} 