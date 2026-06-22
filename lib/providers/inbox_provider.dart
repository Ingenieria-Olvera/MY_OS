import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/vault_paths.dart';
import '../services/inbox_service.dart';

class InboxProvider extends ChangeNotifier {
  static const _readIdsKey = 'inbox_read_ids';

  List<SlackMessage> slackMessages = [];
  List<EmailMessage> emails = [];
  bool isLoading = true;
  Set<String> _readIds = {};

  InboxProvider() {
    _loadReadIds().then((_) => refresh());
  }

  bool isRead(String id) => _readIds.contains(id);

  int get unreadSlackCount => slackMessages.where((m) => !isRead(m.id)).length;
  int get unreadEmailCount => emails.where((m) => !isRead(m.id)).length;

  Future<void> markRead(String id) async {
    if (!_readIds.add(id)) return;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_readIdsKey, _readIds.toList());
  }

  Future<void> _loadReadIds() async {
    final prefs = await SharedPreferences.getInstance();
    _readIds = (prefs.getStringList(_readIdsKey) ?? const []).toSet();
  }

  Future<void> refresh() async {
    isLoading = true;
    notifyListeners();
    final inboxUri = await resolveVaultInboxUri();
    slackMessages = await InboxDigest.readSlackMessages(inboxUri);
    emails = await InboxDigest.readEmails(inboxUri);
    isLoading = false;
    notifyListeners();
  }
}
