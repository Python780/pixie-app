import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:pixie/firebase_options.dart';
import 'package:pixie/screens/controller_screen.dart';

void main() async {
  // 1. This must be the first line
  WidgetsFlutterBinding.ensureInitialized();

  try {
    // 2. Initialize Firebase for the current platform
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    debugPrint("Firebase init failed: $e");
    // Even if it fails, we want to see the UI
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        colorScheme: ColorScheme.dark(primary: Colors.cyanAccent),
        scaffoldBackgroundColor: Colors.black,
      ),
      home: const ControllerScreen(),
    );
  }
}
