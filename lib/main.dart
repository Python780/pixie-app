import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:pixie/firebase_options.dart';
import 'package:pixie/providers/conversation_provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
//import 'package:pixie/screens/controller_screen.dart';
import 'screens/face_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await dotenv.load(fileName: ".env");

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  final conversationProvider = ConversationProvider();

  await conversationProvider.initialize();

  runApp(
    PixieRobotApp(
      provider: conversationProvider,
    ),
  );
}

class PixieRobotApp extends StatelessWidget {
  final ConversationProvider provider;

  const PixieRobotApp({
    super.key,
    required this.provider,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Pixie AI',
      debugShowCheckedModeBanner: false,

      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0F0F1A),
        primarySwatch: Colors.cyan,
      ),

      home: FaceScreen(provider: provider),
    );
  }
}