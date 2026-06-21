import 'dart:convert';
import 'dart:io';

/// A single todo surfaced by `python/todos_aggregator.py`, sourced from the
/// vault's Markdown checkboxes, the calendar digest, or important emails.
class TodoItem {
  final String id;
  final String text;
  final String source; // 'vault' | 'calendar' | 'email'
  final String? due; // ISO date, e.g. '2026-06-21'
  final String origin; // note path, calendar label, or sender

  TodoItem({
    required this.id,
    required this.text,
    required this.source,
    required this.due,
    required this.origin,
  });

  factory TodoItem.fromJson(Map<String, dynamic> data) {
    return TodoItem(
      id: data['id'] as String,
      text: data['text'] as String? ?? '',
      source: data['source'] as String? ?? 'vault',
      due: data['due'] as String?,
      origin: data['origin'] as String? ?? '',
    );
  }
}

/// Reads the todos digest JSON file that `python/todos_aggregator.py` writes
/// into the vault's `_inbox` folder.
class TodosDigest {
  static Future<List<TodoItem>> readToday(Directory inboxDir) async {
    final data = await _readJson(inboxDir, 'todos_digest.json');
    if (data == null) return [];
    return (data['today'] as List<dynamic>? ?? const [])
        .map((t) => TodoItem.fromJson(t as Map<String, dynamic>))
        .toList();
  }

  static Future<List<TodoItem>> readOverarching(Directory inboxDir) async {
    final data = await _readJson(inboxDir, 'todos_digest.json');
    if (data == null) return [];
    return (data['overarching'] as List<dynamic>? ?? const [])
        .map((t) => TodoItem.fromJson(t as Map<String, dynamic>))
        .toList();
  }

  static Future<Map<String, dynamic>?> _readJson(Directory inboxDir, String filename) async {
    final file = File('${inboxDir.path}/$filename');
    if (!await file.exists()) return null;
    try {
      final content = await file.readAsString();
      return jsonDecode(content) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }
}
