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
  // Ensure Flutter engine services are completely ready
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Core Fix: Load .env before ANYTHING else initializes
  try {
    // Try loading from asset bundle first (works for both development and APK builds)
    try {
      final envFile = await rootBundle.loadString('.env');
      print('📄 Raw .env content from asset bundle: $envFile');
      
      // Parse the env file content manually into dotenv.env
      final lines = envFile.split('\n');
      for (final line in lines) {
        final trimmed = line.trim();
        if (trimmed.isEmpty || trimmed.startsWith('#')) continue;
        
        final equalsIndex = trimmed.indexOf('=');
        if (equalsIndex > 0) {
          final key = trimmed.substring(0, equalsIndex).trim();
          var value = trimmed.substring(equalsIndex + 1).trim();
          
          // Remove quotes if present
          if ((value.startsWith('"') && value.endsWith('"')) ||
              (value.startsWith("'") && value.endsWith("'"))) {
            value = value.substring(1, value.length - 1);
          }
          
          dotenv.env[key] = value;
          print('✅ Loaded: $key = ${value.substring(0, (value.length > 10 ? 10 : value.length))}...');
        }
      }
      print('✅ Loaded credentials from asset bundle .env successfully');
    } catch (e) {
      // Fallback to file system loading for development
      print('⚠️ Asset bundle load failed, trying file system: $e');
      await dotenv.load(fileName: ".env");
      print('✅ Loaded credentials from file system .env successfully');
    }
    print('🔍 Available Keys: ${dotenv.env.keys.toList()}');
    print('🔍 FISH_AUDIO_API_KEY value: ${dotenv.env['FISH_AUDIO_API_KEY']}');
  } catch (e) {
    print('❌ Critical Error: Could not load .env file: $e');
  }

  // 2. Initialize Firebase infrastructure
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // 3. Set up and await your conversation provider sequence
  final conversationProvider = ConversationProvider();
  await conversationProvider.initialize();

  // 4. Fire up the UI tree safely now that variables are stored in active RAM
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
            
            // Fetch credentials directly out of global environment memory maps
            final channelId = dotenv.env['THINGSPEAK_CHANNEL_ID'];
            final apiKey = dotenv.env['THINGSPEAK_API_KEY'];

            print('🔍 DEBUG: Loading ThingSpeak credentials from .env');
            print('   channelId from .env: "$channelId"');
            print('   apiKey from .env: "$apiKey"');

            if (channelId != null && apiKey != null &&
                channelId.isNotEmpty && apiKey.isNotEmpty) {
              print('✅ Credentials loaded successfully');
              
              sensorProvider.configureThingSpeak(
                channelId: channelId,
                apiKey: apiKey,
                autoRefreshInterval: const Duration(seconds: 30),
              );
            } else {
              print('❌ Missing or empty ThingSpeak credentials in .env');
            }
            return sensorProvider;
          },
        ),
      ],

      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: "Pixie Pet",
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
      FaceScreen(provider: widget.conversationProvider),
      const DashboardScreen(),
      const ControllerScreen(),
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