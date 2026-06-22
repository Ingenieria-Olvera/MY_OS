import '../constants/vault_paths.dart';
import 'vault_access.dart';

/// A single todo surfaced by `python/todos_aggregator.py`, sourced from the
/// vault's Markdown checkboxes, the calendar digest, important emails, or
/// the local LLM's inference over recent notes' prose.
class TodoItem {
  final String id;
  final String text;
  final String source; // 'vault' | 'vault_inferred' | 'calendar' | 'email'
  final String? due; // ISO date, e.g. '2026-06-21'
  final String origin; // note path, calendar label, or sender
  final String? category; // 'personal' | 'work' | null

  TodoItem({
    required this.id,
    required this.text,
    required this.source,
    required this.due,
    required this.origin,
    this.category,
  });

  factory TodoItem.fromJson(Map<String, dynamic> data) {
    final category = data['category'] as String?;
    return TodoItem(
      id: data['id'] as String,
      text: data['text'] as String? ?? '',
      source: data['source'] as String? ?? 'vault',
      due: data['due'] as String?,
      origin: data['origin'] as String? ?? '',
      category: category == 'personal' || category == 'work' ? category : null,
    );
  }
}

/// Reads the todos digest JSON file that `python/todos_aggregator.py` writes
/// into the vault's `_inbox` folder (resolved via the SAF-picked vault —
/// see [VaultAccess]).
class TodosDigest {
  static Future<List<TodoItem>> readToday([String? inboxUri]) async {
    final data = await _readDigest(inboxUri);
    if (data == null) return [];
    return (data['today'] as List<dynamic>? ?? const [])
        .map((t) => TodoItem.fromJson(t as Map<String, dynamic>))
        .toList();
  }

  static Future<List<TodoItem>> readOverarching([String? inboxUri]) async {
    final data = await _readDigest(inboxUri);
    if (data == null) return [];
    return (data['overarching'] as List<dynamic>? ?? const [])
        .map((t) => TodoItem.fromJson(t as Map<String, dynamic>))
        .toList();
  }

  static Future<Map<String, dynamic>?> _readDigest(String? inboxUri) async {
    final uri = inboxUri ?? await resolveVaultInboxUri();
    if (uri == null) return null;
    final fileEntry = await VaultAccess.child(uri, 'todos_digest.json');
    if (fileEntry == null) return null;
    return VaultAccess.readJson(fileEntry.uri);
  }
}
