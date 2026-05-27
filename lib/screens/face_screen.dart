// lib/screens/face_screen.dart
import 'package:flutter/material.dart';
import '../providers/conversation_provider.dart';
import '../widgets/robot_face/dashboard.dart'; // Import your custom robot face component

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

    String currentEmotion = 'neutral'; //Default emotion if no messages yet
    if (_chatMessages.isNotEmpty) {
      // Find the most recent bot message with an emotion tag
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
          "Pixie Multimodal Face",
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.black,
        actions: [
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
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: DashboardWidget(
              emotion: currentEmotion,
              isTalking: isCurrentlyTalking,
              isProcessing: widget.provider.isProcessing,
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
          // ================= BOTTOM BLOCK: ACTIVE CONVERSATION FEED =================
          Expanded(
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.black12,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(30),
                  topRight: Radius.circular(30),
                ),
              ),
              child: _chatMessages.isEmpty
                  ? Center(
                      child: Text(
                        widget.provider.isListeningForWakeWord
                            ? "Say 'Hi Pixie' to wake me up!"
                            : "Connecting sensors...",
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 16,
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _chatMessages.length,
                      itemBuilder: (context, index) {
                        final msg = _chatMessages[index];
                        return _buildChatBubble(msg);
                      },
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
