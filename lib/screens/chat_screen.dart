import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/chat_message.dart';
import '../state/finance_state.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ApiService _apiService = ApiService();
  bool _isTyping = false;

  void _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    _controller.clear();
    
    final state = Provider.of<FinanceState>(context, listen: false);

    // Call state
    state.addChatMessage('user', text);
    
    setState(() {
      _isTyping = true;
    });
    
    _scrollToBottom();

    // Prepare history for API
    List<Map<String, dynamic>> history = state.chatHistory.map((m) => {
      "role": m['role'], 
      "content": m['content']
    }).toList();

    // Call API
    String rawReply = await _apiService.getChatResponse(text, history, state);
    state.addChatMessage('model', rawReply);

    setState(() {
      _isTyping = false;
    });
    
    _scrollToBottom();
  }

  void _triggerFlexFund(double amount) {
    final state = Provider.of<FinanceState>(context, listen: false);
    state.logFlexFund(amount);
    state.addChatMessage('system', "Flex Fund activated for ₹$amount. Hope it was worth it.");
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<FinanceState>(
      builder: (context, state, child) {
        
        List<ChatMessage> messages = [];
        for (int i = 0; i < state.chatHistory.length; i++) {
          final act = state.chatHistory[i];
          bool isUser = act['role'] == 'user';
          bool isSystem = act['role'] == 'system';
          String rawText = act['content']?.toString() ?? '';
          
          double? flexFundAmount;
          final RegExp flexRegExp = RegExp(r'\[FLEX_FUND:\s*(\d+(\.\d+)?)\]');
          final match = flexRegExp.firstMatch(rawText);
          
          if (match != null) {
            flexFundAmount = double.tryParse(match.group(1) ?? '');
            rawText = rawText.replaceAll(flexRegExp, '').trim();
          }
          
          messages.add(ChatMessage(
            id: i.toString(),
            text: rawText,
            isUser: isUser,
            isSystem: isSystem,
            flexFundAmount: flexFundAmount,
          ));
        }

        return Column(
          children: [
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.all(16),
                itemCount: messages.length,
                itemBuilder: (context, index) {
                  final message = messages[index];
                  if (message.isSystem) {
                    return _buildSystemMessage(message);
                  }
                  if (message.isUser) {
                    return _buildUserMessage(message);
                  } else {
                    return _buildAiMessage(message);
                  }
                },
              ),
            ),
            if (_isTyping)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text("FinBot is thinking...", style: TextStyle(color: Colors.grey, fontSize: 12, fontStyle: FontStyle.italic)),
                ),
              ),
            _buildInputArea(),
          ],
        );
      }
    );
  }

  Widget _buildUserMessage(ChatMessage message) {
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16, left: 50),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: AppTheme.neonCyan.withOpacity(0.1),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(16),
            topRight: Radius.circular(16),
            bottomLeft: Radius.circular(16),
          ),
          border: Border.all(color: AppTheme.neonCyan.withOpacity(0.3)),
        ),
        child: Text(
          message.text,
          style: const TextStyle(color: AppTheme.neonCyan, fontSize: 14),
        ),
      ),
    );
  }

  Widget _buildAiMessage(ChatMessage message) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16, right: 50),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(16),
            topRight: Radius.circular(16),
            bottomRight: Radius.circular(16),
          ),
          border: Border.all(color: AppTheme.success.withOpacity(0.3)), // Alert border
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.success),
                  ),
                  child: const Icon(Icons.smart_toy_outlined, color: AppTheme.success, size: 16),
                ),
                const SizedBox(width: 8),
                const Text(
                  "Wingman Alert",
                  style: TextStyle(color: AppTheme.success, fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              message.text,
              style: const TextStyle(color: Colors.white, fontSize: 14, height: 1.4),
            ),
            if (message.flexFundAmount != null) ...[
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => _triggerFlexFund(message.flexFundAmount!),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent.withOpacity(0.1),
                    foregroundColor: Colors.redAccent,
                    side: const BorderSide(color: Colors.redAccent),
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: Text(
                    "Use Flex Fund ₹${message.flexFundAmount!.toStringAsFixed(0)}", 
                    style: const TextStyle(fontWeight: FontWeight.bold)
                  ),
                ),
              )
            ]
          ],
        ),
      ),
    );
  }

  Widget _buildSystemMessage(ChatMessage message) {
    return Align(
      alignment: Alignment.center,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white10,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          message.text,
          style: const TextStyle(color: Colors.grey, fontSize: 12, fontStyle: FontStyle.italic),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: AppTheme.surface,
        border: Border(top: BorderSide(color: Colors.white10)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white24),
            ),
            child: const Icon(Icons.person_outline, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: _controller,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: "Type a message...",
                hintStyle: const TextStyle(color: Colors.grey),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: const BorderSide(color: AppTheme.neonCyan),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: const BorderSide(color: AppTheme.neonCyan),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: const BorderSide(color: AppTheme.neonCyan),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              ),
              onSubmitted: (_) => _sendMessage(),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.mic_none, color: Colors.grey),
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.send, color: AppTheme.neonCyan),
            onPressed: _sendMessage,
          ),
        ],
      ),
    );
  }
}
