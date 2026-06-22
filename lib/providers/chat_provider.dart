import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/agent_service.dart';

class ChatMessage {
  final String text;
  final bool isUser;

  ChatMessage({required this.text, required this.isUser});
}

class ChatProvider extends ChangeNotifier {
  static const _baseUrlKey = 'agent_base_url';
  static const _historyKey = 'agent_chat_history';

  String agentBaseUrl = '';
  List<ChatMessage> messages = [];
  bool isSending = false;
  String? error;

  ChatProvider() {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    agentBaseUrl = prefs.getString(_baseUrlKey) ?? '';
    final history = prefs.getStringList(_historyKey) ?? const [];
    messages = history.map((entry) {
      final isUser = entry.startsWith('U:');
      return ChatMessage(text: entry.substring(2), isUser: isUser);
    }).toList();
    notifyListeners();
  }

  Future<void> setBaseUrl(String url) async {
    agentBaseUrl = url.trim();
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_baseUrlKey, agentBaseUrl);
  }

  Future<void> sendMessage(String text) async {
    if (text.trim().isEmpty || agentBaseUrl.isEmpty) return;

    messages.add(ChatMessage(text: text, isUser: true));
    isSending = true;
    error = null;
    notifyListeners();

    try {
      final reply = await AgentService.sendMessage(agentBaseUrl, text);
      messages.add(ChatMessage(text: reply, isUser: false));
    } catch (e) {
      error = e.toString();
    }

    isSending = false;
    notifyListeners();
    await _saveHistory();
  }

  Future<void> _saveHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = messages.map((m) => '${m.isUser ? 'U' : 'A'}:${m.text}').toList();
    await prefs.setStringList(_historyKey, encoded);
  }

  Future<void> clearHistory() async {
    messages = [];
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_historyKey);
  }
}
