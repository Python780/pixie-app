// lib/screens/face_screen.dart
import 'package:flutter/material.dart';
import '../providers/conversation_provider.dart';
import '../screens/analytics_dashboard.dart';
import '../widgets/robot_face/dashboard.dart'; 

class FaceScreen extends StatefulWidget {
  final ConversationProvider provider;
  const FaceScreen({super.key, required this.provider});

  @override
  FaceScreenState createState() => FaceScreenState();
}

class FaceScreenState extends State<FaceScreen> {
  bool _isLoading = true;
  List<Message> _chatMessages = [];

  @override
  void initState() {
    super.initState();
    _initPixieSystem();
  }

  Future<void> _initPixieSystem() async {
    await widget.provider.initialize();

    widget.provider.onMessagesUpdated = (messages) {
      setState(() {
        _chatMessages = List.from(messages);
      });
    };

    widget.provider.addListener(_providerListener);

    widget.provider.startWakeWordDetection();
    setState(() => _isLoading = false);
  }

  void _providerListener() {
    if (!mounted) return;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: CircularProgressIndicator(color: Colors.cyanAccent),
        ),
      );
    }

    String currentEmotion = 'neutral'; 
    if (_chatMessages.isNotEmpty) {
      final lastBotMsg = _chatMessages.lastWhere(
        (m) => !m.isUser,
        orElse: () => _chatMessages.first,
      );
      currentEmotion = lastBotMsg.emotion ?? 'neutral';
    }

    final bool isCurrentlyTalking = widget.provider.isSpeaking;

    return Scaffold(
      backgroundColor: const Color(0xFF222222),
      appBar: AppBar(
        title: const Text(
          "Pixie AI",
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.black,
        actions: [
          IconButton(
            icon: const Icon(Icons.bar_chart, color: Colors.white),
            tooltip: 'Analytics',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const AnalyticsDashboardScreen(),
                ),
              );
            },
          ),
          Icon(
            widget.provider.isCameraActive
                ? Icons.videocam
                : Icons.videocam_off,
            color: widget.provider.isCameraActive ? Colors.green : Colors.red,
          ),
          const SizedBox(width: 15),
        ],
      ),
      body: Column(
        children: [
          // ================= TOP BLOCK: ROBOT FACE PANEL LAYER =================
          Expanded(
            child: Container(
              color: const Color(0xFF222222), 
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final double adaptiveFaceSize = constraints.maxHeight * 0.32;

                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
                      child: DashboardWidget(
                        emotion: currentEmotion,
                        isTalking: isCurrentlyTalking,
                        isProcessing: widget.provider.isProcessing,
                        baseSize: adaptiveFaceSize, 
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
                
          // ================= HINT BUBBLE: SHOWN ONLY WHEN NO CONVERSATION YET =================
          if (_chatMessages.isEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 32.0, left: 32.0, right: 32.0),
              child: AnimatedOpacity(
                opacity: widget.provider.isListeningForWakeWord ? 1.0 : 0.6,
                duration: const Duration(milliseconds: 500),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.black38,
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(
                      color: widget.provider.isListeningForWakeWord 
                          ? Colors.greenAccent.withOpacity(0.4) 
                          : Colors.grey.withOpacity(0.3),
                      width: 1.5,
                    ),
                    boxShadow: [
                      if (widget.provider.isListeningForWakeWord)
                        BoxShadow(
                          color: Colors.greenAccent.withOpacity(0.1),
                          blurRadius: 10,
                          spreadRadius: 1,
                        )
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        widget.provider.isListeningForWakeWord ? Icons.waves : Icons.sync_disabled,
                        color: widget.provider.isListeningForWakeWord ? Colors.greenAccent : Colors.grey,
                        size: 16,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        widget.provider.isListeningForWakeWord
                            ? "Say 'Hi Pixie' to wake me up!"
                            : "Connecting sensors...",
                        style: TextStyle(
                          color: widget.provider.isListeningForWakeWord ? Colors.white : Colors.grey[400],
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // ================= MIDDLE BLOCK: REFINED USER LISTENING BAR =================
          if (widget.provider.state == PixieState.userListening)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 4.0), 
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 10.0), 
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(16.0), 
                  border: Border.all(color: Colors.cyanAccent.withOpacity(0.6)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.mic, color: Colors.cyanAccent, size: 18), 
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            widget.provider.listeningPrompt ?? 'Listening...',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12, 
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        Text(
                          '${(widget.provider.listeningLevel * 100).round()}%',
                          style: const TextStyle(color: Colors.cyanAccent, fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8.0),
                      child: LinearProgressIndicator(
                        value: widget.provider.listeningLevel,
                        minHeight: 5, 
                        backgroundColor: Colors.white10,
                        color: Colors.cyanAccent,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // ================= BOTTOM BLOCK: ACTIVE CONVERSATION FEED =================
          if (_chatMessages.isNotEmpty) 
            Expanded(
              flex: 1,
              child: Container(
                width: double.infinity,
                decoration: const BoxDecoration(
                  color: Colors.black26,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(30),
                    topRight: Radius.circular(30),
                  ),
                ),
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _chatMessages.length,
                  itemBuilder: (context, index) {
                    final msg = _chatMessages[index];
                    return _buildChatBubble(msg);
                  },
                ),
              ),
            ),

          if (!widget.provider.isGeminiAvailable)
            Container(
              width: double.infinity,
              color: Colors.redAccent,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Text(
                widget.provider.geminiErrorMessage != null
                    ? 'Gemini unavailable: ${widget.provider.geminiErrorMessage}'
                    : 'Gemini is currently unavailable.',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    );
  } 

  Widget _buildChatBubble(Message msg) {
    return Align(
      alignment: msg.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: msg.isUser ? Colors.cyan[700] : Colors.grey[800],
          borderRadius: BorderRadius.circular(20).copyWith(
            bottomRight: msg.isUser
                ? const Radius.circular(0)
                : const Radius.circular(20),
            topLeft: msg.isUser
                ? const Radius.circular(20)
                : const Radius.circular(0),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              msg.text,
              style: const TextStyle(color: Colors.white, fontSize: 15),
            ),
            if (!msg.isUser && msg.facialAnalysis != null)
              Padding(
                padding: const EdgeInsets.only(top: 4.0),
                child: Text(
                  "Analysis: ${msg.facialAnalysis}",
                  style: const TextStyle(
                    color: Colors.cyanAccent,
                    fontSize: 11,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    widget.provider.removeListener(_providerListener);
    widget.provider.shutdown();
    super.dispose();
  }
}
