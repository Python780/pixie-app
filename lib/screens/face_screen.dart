// lib/screens/face_screen.dart
import 'package:flutter/material.dart';
import '../providers/conversation_provider.dart';
import '../screens/analytics_dashboard.dart';
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
  final TextEditingController _apiKeyController = TextEditingController();
  String? _apiKeyStatus;

  @override
  void initState() {
    super.initState();
    _initPixieSystem();
  }

  Future<void> _initPixieSystem() async {
    await widget.provider.initialize();
    _apiKeyController.text = widget.provider.geminiApiKey;

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

  Future<void> _saveApiKey() async {
    final apiKey = _apiKeyController.text.trim();
    try {
      await widget.provider.updateGeminiApiKey(apiKey);
      setState(() {
        _apiKeyStatus = apiKey.isEmpty
            ? 'Gemini API key cleared; app will fall back to env if available.'
            : 'Gemini API key saved locally for this device only.';
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            apiKey.isEmpty
                ? 'Saved key cleared.'
                : 'Gemini API key saved locally.',
          ),
        ),
      );
    } catch (e) {
      setState(() {
        _apiKeyStatus = 'Error saving API key: ${e.toString()}';
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to save API key: ${e.toString()}'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
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
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: DashboardWidget(
              emotion: currentEmotion,
              isTalking: isCurrentlyTalking,
              isProcessing: widget.provider.isProcessing,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 6.0,
            ),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16.0),
              decoration: BoxDecoration(
                color: Colors.white10,
                borderRadius: BorderRadius.circular(22.0),
                border: Border.all(color: Colors.cyanAccent),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Gemini API Key',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _apiKeyController,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            hintText: 'Enter your Gemini API key',
                            hintStyle: TextStyle(color: Colors.white54),
                            filled: true,
                            fillColor: Colors.white12,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16.0),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      ElevatedButton(
                        onPressed: _saveApiKey,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.cyanAccent,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 16,
                          ),
                        ),
                        child: const Text('Save'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _apiKeyStatus ??
                        (widget.provider.hasSavedGeminiApiKey
                            ? 'Saved key will be used on this device only.'
                            : 'No stored key yet; enter one to use your own Gemini account.'),
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
          if (widget.provider.state == PixieState.userListening)
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 8.0,
              ),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16.0),
                decoration: BoxDecoration(
                  color: Colors.white12,
                  borderRadius: BorderRadius.circular(22.0),
                  border: Border.all(color: Colors.cyanAccent),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.mic, color: Colors.cyanAccent),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            widget.provider.listeningPrompt ??
                                'Listening for your response...',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16.0),
                      child: LinearProgressIndicator(
                        value: widget.provider.listeningLevel,
                        minHeight: 12,
                        backgroundColor: Colors.white10,
                        color: Colors.cyanAccent,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Speech level ${(widget.provider.listeningLevel * 100).round()}%',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                  ],
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
    _apiKeyController.dispose();
    widget.provider.removeListener(_providerListener);
    widget.provider.shutdown();
    super.dispose();
  }
}
