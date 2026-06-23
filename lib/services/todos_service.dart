import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../constants/vault_paths.dart';
import 'vault_access.dart';

/// The vault-root note that manually-added todos are appended to as plain
/// `- [ ]` checkboxes, so `python/todos_aggregator.py` picks them up on its
/// next run exactly like any other note in the vault.
const manualTodosFileName = 'My Todos.md';

/// Mirrors `_stable_id()` in python/todos_aggregator.py (`sha1("rel_path|text")`,
/// first 16 hex chars) so a todo added in the app keeps the same id once the
/// aggregator re-parses the vault and writes it into the digest — otherwise
/// it would briefly show up twice.
String stableTodoId(String relPath, String text) {
  final digest = sha1.convert(utf8.encode('$relPath|$text'));
  return digest.toString().substring(0, 16);
}

/// A single todo surfaced by `python/todos_aggregator.py`, sourced from the
/// vault's Markdown checkboxes, the calendar digest, important emails, or
/// the local LLM's inference over recent notes' prose.
class TodoItem {
  final String id;
  final String text;
  final String source; // 'vault' | 'vault_inferred' | 'calendar' | 'email'
  final String? due; // ISO date, e.g. '2026-06-21'
  final String origin; // note path, calendar label, or sender
  final String? category; // 'personal' | 'work' | 'other' | null
  final String? urgency; // 'today' | 'this_week' | 'overarching' — why it landed in its bucket

  TodoItem({
    required this.id,
    required this.text,
    required this.source,
    required this.due,
    required this.origin,
    this.category,
    this.urgency,
  });

  static const _categories = {'personal', 'work', 'other'};
  static const _urgencies = {'today', 'this_week', 'overarching'};

  factory TodoItem.fromJson(Map<String, dynamic> data) {
    final category = data['category'] as String?;
    final urgency = data['urgency'] as String?;
    return TodoItem(
      id: data['id'] as String,
      text: data['text'] as String? ?? '',
      source: data['source'] as String? ?? 'vault',
      due: data['due'] as String?,
      origin: data['origin'] as String? ?? '',
      category: _categories.contains(category) ? category : null,
      urgency: _urgencies.contains(urgency) ? urgency : null,
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
