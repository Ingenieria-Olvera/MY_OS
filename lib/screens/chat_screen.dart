import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/chat_provider.dart';
import '../theme/app_theme.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _inputController = TextEditingController();
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ChatProvider>(
      builder: (context, provider, child) {
        _scrollToBottom();
        return Scaffold(
          appBar: AppBar(
            title: const Text('SECRETARY'),
            actions: [
              IconButton(
                icon: const Icon(Icons.settings_outlined),
                onPressed: () => _showSettingsDialog(context, provider),
              ),
            ],
          ),
          body: Column(
            children: [
              if (provider.agentBaseUrl.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'Set the local agent\'s address (tap the gear) — it runs on your own '
                    'machine on your home network, see python/README.md.',
                    style: const TextStyle(color: AppTheme.textSecondary),
                    textAlign: TextAlign.center,
                  ),
                ),
              if (provider.error != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Text(provider.error!, style: const TextStyle(color: AppTheme.statusRed)),
                ),
              Expanded(
                child: ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: provider.messages.length,
                  itemBuilder: (context, i) => _buildBubble(provider.messages[i]),
                ),
              ),
              if (provider.isSending)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: CircularProgressIndicator(color: AppTheme.accentPurple, strokeWidth: 2),
                ),
              _buildInputBar(provider),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBubble(ChatMessage message) {
    return Align(
      alignment: message.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        decoration: BoxDecoration(
          color: message.isUser ? AppTheme.accentPurple.withOpacity(0.2) : AppTheme.surface,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text(message.text, style: const TextStyle(color: AppTheme.textPrimary)),
      ),
    );
  }

  Widget _buildInputBar(ChatProvider provider) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _inputController,
              style: const TextStyle(color: AppTheme.textPrimary),
              decoration: InputDecoration(
                hintText: 'Ask your secretary…',
                hintStyle: const TextStyle(color: AppTheme.textSecondary),
                filled: true,
                fillColor: AppTheme.surface,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              onSubmitted: (_) => _send(provider),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.send, color: AppTheme.accentPurple),
            onPressed: () => _send(provider),
          ),
        ],
      ),
    );
  }

  void _send(ChatProvider provider) {
    final text = _inputController.text;
    if (text.trim().isEmpty) return;
    _inputController.clear();
    provider.sendMessage(text);
  }

  void _showSettingsDialog(BuildContext context, ChatProvider provider) {
    final controller = TextEditingController(text: provider.agentBaseUrl);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: const Text('Local Agent Address', style: TextStyle(color: AppTheme.textPrimary)),
        content: TextField(
          controller: controller,
          style: const TextStyle(color: AppTheme.textPrimary),
          decoration: const InputDecoration(
            hintText: 'http://192.168.1.x:8765',
            hintStyle: TextStyle(color: AppTheme.textSecondary),
            labelText: 'Base URL',
            labelStyle: TextStyle(color: AppTheme.textSecondary),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              provider.clearHistory();
              Navigator.pop(context);
            },
            child: const Text('Clear history', style: TextStyle(color: AppTheme.statusRed)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: AppTheme.textSecondary)),
          ),
          TextButton(
            onPressed: () {
              provider.setBaseUrl(controller.text);
              Navigator.pop(context);
            },
            child: const Text('Save', style: TextStyle(color: AppTheme.accentPurple)),
          ),
        ],
      ),
    );
  }
}
