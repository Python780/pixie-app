import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/robot_provider.dart';
import '../providers/conversation_provider.dart';
import '../screens/DiagnosticsScreen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final robot = Provider.of<RobotProvider>(context);

    return Scaffold(
      backgroundColor: const Color(0xFF181A20),

      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        title: const Text(
          'Settings',
          style: TextStyle(
            color: Colors.white,
            fontSize: 28,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),

      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),

        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // ================= DEVICE =================

            const SectionTitle(
              title: "DEVICE",
            ),

            const SizedBox(height: 16),

            // ================= BLUETOOTH =================

            SettingsCard(
              icon: Icons.bluetooth_rounded,

              iconColor: robot.isConnected
                  ? Colors.greenAccent
                  : Colors.redAccent,

              title: robot.isConnected
                  ? "ESP32 Connected"
                  : "Bluetooth Connection",

              subtitle: robot.isConnected
                  ? "Robot ready"
                  : (robot.isScanning ? "Scanning..." : "Tap to connect ESP32"),

              onTap: () async {

                if (!robot.isConnected) {
                  
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Scanning for Pixie...')),
                  );

                  bool success = await robot.connectBluetooth();

                  if (success) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('✅ Connected to Pixie!'), backgroundColor: Colors.green),
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text('❌ Device not found. Please try again.'),
                        backgroundColor: Colors.redAccent,
                        action: SnackBarAction(label: 'Retry', onPressed: () => robot.connectBluetooth()),
                      ),
                    );
                  }
                } else {
                  await robot.disconnectBluetooth();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('🔌 Disconnected')),
                  );
                }
              },
            ),

            const SizedBox(height: 18),

            // ================= SENSOR =================

            SettingsCard(
              icon: Icons.monitor_heart_rounded,
              iconColor: Colors.orangeAccent,
              title: "Hardware Diagnostics",
              subtitle: "Check connectivity,sensors", 
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const DiagnosticsScreen()),
                );
              },
            ),

            const SizedBox(height: 30),

            // ================= AI SYSTEM =================

            const SectionTitle(
              title: "AI SYSTEM",
            ),

            const SizedBox(height: 16),

            SettingsCard(
              icon: Icons.psychology_alt_rounded,
              iconColor: Colors.purpleAccent,
              title: "Gemini AI",
              subtitle: "Conversation and emotion engine",
              onTap: () {
                final provider = Provider.of<ConversationProvider>(context, listen: false);
                final TextEditingController dialogController = TextEditingController(text: provider.geminiApiKey);

                showDialog(
                  context: context,
                  builder: (context) {
                    bool isObscured = true; // 初始隐藏密码

                    return StatefulBuilder(
                      builder: (context, setDialogState) {
                        bool hasKey = dialogController.text.isNotEmpty;

                        return AlertDialog(
                          backgroundColor: const Color(0xFF222222),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          title: const Text("Gemini API Key", style: TextStyle(color: Colors.white)),
                          content: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              TextField(
                                controller: dialogController,
                                obscureText: isObscured, 
                                style: const TextStyle(color: Colors.white),
                                onChanged: (value) {
                                  setDialogState(() {}); 
                                },
                                decoration: InputDecoration(
                                  hintText: "Enter your API key",
                                  hintStyle: const TextStyle(color: Colors.white54),
                                  enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.cyanAccent)),
                                  focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.cyanAccent, width: 2)),
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      isObscured ? Icons.visibility_off : Icons.visibility,
                                      color: Colors.white54,
                                    ),
                                    onPressed: () {
                                      // 🌟 点击切换局部显示隐藏状态
                                      setDialogState(() {
                                        isObscured = !isObscured;
                                      });
                                    },
                                  ),
                                ),
                              ),
                              const SizedBox(height: 14),
                              Row(
                                children: [
                                  Icon(
                                    hasKey ? Icons.check_circle_outline : Icons.warning_amber_rounded,
                                    color: hasKey ? Colors.greenAccent : Colors.amberAccent,
                                    size: 16,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    hasKey ? "Status: API Key Detected" : "Status: Key Empty",
                                    style: TextStyle(
                                      color: hasKey ? Colors.greenAccent : Colors.amberAccent,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
                            ),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.cyanAccent),
                              onPressed: () async {
                                await provider.updateGeminiApiKey(dialogController.text.trim());
                                Navigator.pop(context);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text("Gemini API Key saved!")),
                                );
                              },
                              child: const Text("Save", style: TextStyle(color: Colors.black)),
                            ),
                          ],
                        );
                      },
                    );
                  },
                );
              },
            ),

            const SizedBox(height: 18),
            // ================= VOICE SYSTEM =================
            SettingsCard(
              icon: Icons.mic_rounded,
              iconColor: Colors.cyanAccent,
              title: "Voice System",
              subtitle:
                  "Wake word and speech settings",

              onTap: () {},
            ),

            const SizedBox(height: 30),

            // ================= DATA =================

            const SectionTitle(
              title: "DATA",
            ),

            const SizedBox(height: 16),

            SettingsCard(
              icon: Icons.cloud_sync_rounded,
              iconColor: Colors.amberAccent,
              title: "Firebase Sync",
              subtitle:
                  "Refresh robot conversation data",

              onTap: () {},
            ),

            const SizedBox(height: 35),

            // ================= ABOUT CARD =================

            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF22252E),
                borderRadius:
                    BorderRadius.circular(28),
                border: Border.all(
                  color: Colors.white10,
                ),

                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.25),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),

              child: Row(
                children: [

                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color:
                          Colors.cyanAccent.withOpacity(0.15),
                      borderRadius:
                          BorderRadius.circular(18),
                    ),

                    child: const Icon(
                      Icons.smart_toy_rounded,
                      color: Colors.cyanAccent,
                      size: 30,
                    ),
                  ),

                  const SizedBox(width: 18),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,

                      children: [

                        Text(
                          "Pixie PRO",

                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 19,
                            fontWeight: FontWeight.bold,
                          ),
                        ),

                        SizedBox(height: 5),

                        Text(
                          "v1.0.0 • ESP32 + Gemini + Firebase",

                          style: TextStyle(
                            color: Colors.grey,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =======================================================
// SETTINGS CARD
// =======================================================

class SettingsCard extends StatelessWidget {

  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const SettingsCard({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {

    return GestureDetector(

      onTap: onTap,

      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: const Color(0xFF22252E),
          borderRadius:
              BorderRadius.circular(28),

          border: Border.all(
            color: Colors.white10,
          ),

          boxShadow: [

            BoxShadow(
              color: Colors.black.withOpacity(0.25),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),

        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color:
                    iconColor.withOpacity(0.15),
                borderRadius:
                    BorderRadius.circular(18),
              ),

              child: Icon(
                icon,
                color: iconColor,
                size: 28,
              ),
            ),

            const SizedBox(width: 18),

            Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [

                  Text(
                    title,

                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 5),

                  Text(
                    subtitle,

                    style: const TextStyle(
                      color: Colors.grey,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),

            const Icon(
              Icons.arrow_forward_ios_rounded,
              color: Colors.grey,
              size: 18,
            ),
          ],
        ),
      ),
    );
  }
}

// =======================================================
// SECTION TITLE
// =======================================================

class SectionTitle extends StatelessWidget {

  final String title;

  const SectionTitle({
    super.key,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {

    return Text(

      title,

      style: const TextStyle(
        color: Colors.grey,
        fontSize: 13,
        letterSpacing: 2,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}