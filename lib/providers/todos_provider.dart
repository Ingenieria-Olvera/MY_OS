import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/vault_paths.dart';
import '../services/agent_service.dart';
import '../services/todos_service.dart';
import '../services/vault_access.dart';

class TodosProvider extends ChangeNotifier {
  static const _completedIdsKey = 'todos_completed_ids';
  // Same SharedPreferences key ChatProvider stores the agent's base URL
  // under (see lib/providers/chat_provider.dart) — one Settings field
  // backs both /chat and /feedback.
  static const _agentBaseUrlKey = 'agent_base_url';

  List<TodoItem> today = [];
  List<TodoItem> overarching = [];
  bool isLoading = true;
  Set<String> _completedIds = {};
  // Manually-added todos not yet confirmed by the next digest fetch (see
  // refresh()) — kept here so addTodo() can show them optimistically and
  // refresh() can drop them once todos_aggregator.py has parsed the same
  // checkbox and they appear in the fetched digest by stable id.
  final List<TodoItem> _pendingToday = [];
  final List<TodoItem> _pendingOverarching = [];
  TodosProvider() {
    _loadCompletedIds();
  }

  bool isCompleted(String id) => _completedIds.contains(id);

  List<TodoItem> get pendingToday => today.where((t) => !isCompleted(t.id)).toList();
  List<TodoItem> get pendingOverarching => overarching.where((t) => !isCompleted(t.id)).toList();

  /// Appends a new checkbox to a vault-root note (see [manualTodosFileName])
  /// so it syncs to every other device exactly like a hand-typed todo, and
  /// shows it immediately without waiting for the next scraper run.
  Future<bool> addTodo({
    required String text,
    String? due,
    bool ongoing = false,
    bool pinToday = false,
    String? category,
  }) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return false;
    final rootUri = await resolveVaultRootUri();
    if (rootUri == null) return false;

    final buffer = StringBuffer(trimmed);
    if (due != null) buffer.write(' 📅 $due');
    if (ongoing) buffer.write(' #ongoing');
    if (pinToday) buffer.write(' #today');
    if (category == 'personal' || category == 'work') buffer.write(' #$category');
    final checkboxText = buffer.toString();

    await VaultAccess.appendLine(rootUri, manualTodosFileName, '- [ ] $checkboxText');

    final item = TodoItem(
      id: stableTodoId(manualTodosFileName, checkboxText),
      text: checkboxText,
      source: 'vault',
      due: due,
      origin: manualTodosFileName,
      category: category == 'personal' || category == 'work' ? category : null,
    );

    final bucketIsToday = pinToday ||
        (!ongoing && due != null && !DateTime.parse(due).isAfter(DateTime.now()));
    if (bucketIsToday) {
      today = [...today, item];
      _pendingToday.add(item);
    } else {
      overarching = [...overarching, item];
      _pendingOverarching.add(item);
    }
    notifyListeners();
    return true;
  }

  /// Sends a category/urgency correction (plus an optional free-text reason)
  /// for [item] to the local agent's `/feedback` endpoint. Returns false if
  /// no agent base URL is configured (Settings) or the request fails, so the
  /// caller can show a snackbar without throwing.
  Future<bool> submitFeedback({
    required TodoItem item,
    String? chosenCategory,
    String? chosenUrgency,
    String? reason,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final baseUrl = prefs.getString(_agentBaseUrlKey) ?? '';
    if (baseUrl.isEmpty) return false;

    try {
      await AgentService.sendFeedback(
        baseUrl,
        text: item.text,
        suggestedCategory: item.category,
        chosenCategory: chosenCategory,
        suggestedUrgency: item.urgency,
        chosenUrgency: chosenUrgency,
        reason: reason,
      );
      return true;
    } catch (_) {
      return false;
    }
  }

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
    final fetchedToday = await TodosDigest.readToday(inboxUri);
    final fetchedOverarching = await TodosDigest.readOverarching(inboxUri);

    _pendingToday.removeWhere((p) => fetchedToday.any((t) => t.id == p.id));
    _pendingOverarching.removeWhere((p) => fetchedOverarching.any((t) => t.id == p.id));

    today = [...fetchedToday, ..._pendingToday];
    overarching = [...fetchedOverarching, ..._pendingOverarching];
    isLoading = false;
    notifyListeners();
  }
}
