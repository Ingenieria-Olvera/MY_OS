import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/vault_paths.dart';
import '../services/todos_service.dart';

class TodosProvider extends ChangeNotifier {
  static const _completedIdsKey = 'todos_completed_ids';

  List<TodoItem> today = [];
  List<TodoItem> overarching = [];
  bool isLoading = true;
  Set<String> _completedIds = {};

  TodosProvider() {
    _loadCompletedIds().then((_) => refresh());
  }

  bool isCompleted(String id) => _completedIds.contains(id);

  List<TodoItem> get pendingToday => today.where((t) => !isCompleted(t.id)).toList();
  List<TodoItem> get pendingOverarching => overarching.where((t) => !isCompleted(t.id)).toList();

  Future<void> toggleCompleted(String id) async {
    if (!_completedIds.remove(id)) {
      _completedIds.add(id);
    }
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_completedIdsKey, _completedIds.toList());
  }

  Future<void> _loadCompletedIds() async {
    final prefs = await SharedPreferences.getInstance();
    _completedIds = (prefs.getStringList(_completedIdsKey) ?? const []).toSet();
  }

  Future<void> refresh() async {
    isLoading = true;
    notifyListeners();
    final inboxUri = await resolveVaultInboxUri();
    today = await TodosDigest.readToday(inboxUri);
    overarching = await TodosDigest.readOverarching(inboxUri);
    isLoading = false;
    notifyListeners();
  }
}
