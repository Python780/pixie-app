import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:pixie/providers/conversation_provider.dart';
import 'package:pixie/providers/robot_provider.dart';
import 'package:pixie/providers/sensor_provider.dart';

import 'package:pixie/firebase_options.dart';
import 'package:firebase_core/firebase_core.dart';

import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'screens/face_screen.dart';
import 'screens/controller_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/dashboard_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    // Load .env from assets (works on all platforms including web)
    final envString = await rootBundle.loadString('assets/.env');
    // Parse the env string into a map that dotenv can use
    final envMap = <String, String>{};
    for (final line in envString.split('\n')) {
      if (line.isEmpty || line.startsWith('#')) continue;
      final parts = line.split('=');
      if (parts.length == 2) {
        envMap[parts[0].trim()] = parts[1].trim();
      }
    }
    // Load the parsed map into dotenv
    await dotenv.load(mergeWith: envMap);
    print('✅ Loaded .env from assets successfully');
  } catch (e) {
    print('⚠️ Could not load .env from assets: $e');
    try {
      // Fallback to .env.example from assets
      final exampleString = await rootBundle.loadString('assets/.env.example');
      final envMap = <String, String>{};
      for (final line in exampleString.split('\n')) {
        if (line.isEmpty || line.startsWith('#')) continue;
        final parts = line.split('=');
        if (parts.length == 2) {
          envMap[parts[0].trim()] = parts[1].trim();
        }
      }
      await dotenv.load(mergeWith: envMap);
      print(
        '⚠️ Using .env.example from assets. Add real credentials to assets/.env!',
      );
    } catch (e2) {
      print('❌ Could not load .env.example either: $e2');
    }
  }

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  final conversationProvider = ConversationProvider();

  await conversationProvider.initialize();

  runApp(PixieRobotApp(provider: conversationProvider));
}

class PixieRobotApp extends StatelessWidget {
  final ConversationProvider provider;

  const PixieRobotApp({super.key, required this.provider});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<RobotProvider>(create: (_) => RobotProvider()),
        ChangeNotifierProvider<ConversationProvider>.value(value: provider),
        ChangeNotifierProvider<SensorProvider>(
          create: (_) {
            final sensorProvider = SensorProvider();
            // Configure ThinkSpeak with credentials from .env
            final channelId = dotenv.env['THINKSPEAK_CHANNEL_ID'];
            final apiKey = dotenv.env['THINKSPEAK_API_KEY'];

            print('🔍 DEBUG: Loading ThinkSpeak credentials from .env');
            print('   channelId from .env: "$channelId"');
            print('   apiKey from .env: "$apiKey"');

            if (channelId != null &&
                apiKey != null &&
                channelId.isNotEmpty &&
                apiKey.isNotEmpty) {
              print('✅ Credentials loaded successfully');
              sensorProvider.configureThinkSpeak(
                channelId: channelId,
                apiKey: apiKey,
                autoRefreshInterval: const Duration(seconds: 30),
              );
            }
            return sensorProvider;
          },
        ),
      ],

      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: "Pixie AI Robot",
        theme: ThemeData(
          brightness: Brightness.dark,
          scaffoldBackgroundColor: const Color(0xFF0F0F1A),
          primarySwatch: Colors.cyan,
        ),

        home: MainNavigationScreen(conversationProvider: provider),
      ),
    );
  }
}

class MainNavigationScreen extends StatefulWidget {
  final ConversationProvider conversationProvider;

  const MainNavigationScreen({super.key, required this.conversationProvider});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int currentIndex = 0;

  late final List<Widget> pages;

  @override
  void initState() {
    super.initState();

    pages = [
      // 主页
      FaceScreen(provider: widget.conversationProvider),

      // Sensor Dashboard
      const DashboardScreen(),
      // Manual Controller
      const ControllerScreen(),
      // Settings
      const SettingsScreen(),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: currentIndex, children: pages),

      bottomNavigationBar: NavigationBar(
        selectedIndex: currentIndex,
        onDestinationSelected: (index) {
          setState(() {
            currentIndex = index;
          });
        },

        destinations: const [
          NavigationDestination(icon: Icon(Icons.face), label: "Pixie"),

          NavigationDestination(icon: Icon(Icons.dashboard), label: "Monitor"),

          NavigationDestination(icon: Icon(Icons.gamepad), label: "Control"),

          NavigationDestination(icon: Icon(Icons.settings), label: "Settings"),
        ],
      ),
    );
  }
}
