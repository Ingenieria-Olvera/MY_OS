import 'dart:convert';
import 'dart:typed_data';

import 'package:saf_stream/saf_stream.dart';
import 'package:saf_util/saf_util.dart';
import 'package:saf_util/saf_util_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// One file or folder inside the user-picked vault tree. Wraps the
/// platform's [SafDocumentFile] so the rest of the app never has to import
/// `package:saf_util` directly — if the plugin's API ever changes, only
/// this file needs to change.
class VaultEntry {
  final String uri;
  final String name;
  final bool isDir;

  const VaultEntry({required this.uri, required this.name, required this.isDir});

  factory VaultEntry.fromSaf(SafDocumentFile doc) =>
      VaultEntry(uri: doc.uri, name: doc.name, isDir: doc.isDir);
}

/// Storage-Access-Framework-backed access to the Obsidian vault folder the
/// user picks once on first launch. Replaces the old hardcoded
/// `/storage/emulated/0/...` path and `MANAGE_EXTERNAL_STORAGE` permission:
/// the OS grants a persisted, scoped read/write grant to just that one
/// folder tree, and nothing else on the device.
class VaultAccess {
  static const _prefsKey = 'vault_root_uri';
  static const inboxFolderName = '_inbox';

  static final SafUtil _safUtil = SafUtil();
  static final SafStream _safStream = SafStream();

  static Future<String?> getVaultRootUri() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_prefsKey);
  }

  static Future<bool> hasVaultAccess() async {
    final uri = await getVaultRootUri();
    if (uri == null) return false;
    try {
      return await _safUtil.hasPersistedPermission(uri, checkRead: true, checkWrite: true);
    } catch (_) {
      return false;
    }
  }

  /// Opens the folder picker, persists the grant, and remembers the URI.
  /// Returns the picked root's URI, or null if the user cancelled.
  static Future<String?> pickVaultFolder() async {
    final picked = await _safUtil.pickDirectory(
      writePermission: true,
      persistablePermission: true,
    );
    if (picked == null) return null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, picked.uri);
    return picked.uri;
  }

  static Future<void> clearVaultFolder() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsKey);
  }

  /// Resolves the `_inbox` folder inside the picked vault root, if any.
  static Future<String?> resolveInboxUri() async {
    final root = await getVaultRootUri();
    if (root == null) return null;
    try {
      final child = await _safUtil.child(root, [inboxFolderName]);
      return child?.uri;
    } catch (_) {
      return null;
    }
  }

  static Future<List<VaultEntry>> list(String dirUri) async {
    try {
      final docs = await _safUtil.list(dirUri);
      return docs.map(VaultEntry.fromSaf).toList();
    } catch (_) {
      return [];
    }
  }

  static Future<VaultEntry?> child(String dirUri, String name) async {
    try {
      final doc = await _safUtil.child(dirUri, [name]);
      return doc == null ? null : VaultEntry.fromSaf(doc);
    } catch (_) {
      return null;
    }
  }

  static Future<String?> readAsString(String fileUri) async {
    try {
      final bytes = await _safStream.readFileBytes(fileUri);
      return utf8.decode(bytes, allowMalformed: true);
    } catch (_) {
      return null;
    }
  }

  static Future<Map<String, dynamic>?> readJson(String fileUri) async {
    final content = await readAsString(fileUri);
    if (content == null) return null;
    try {
      return jsonDecode(content) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  static Future<void> writeString(String dirUri, String fileName, String content) async {
    await _safStream.writeFileBytes(
      dirUri,
      fileName,
      'text/markdown',
      Uint8List.fromList(utf8.encode(content)),
      overwrite: true,
    );
  }

  /// Recursively lists every `.md` file under [rootUri], skipping the
  /// `_inbox` folder (Python scrapers' digests, not vault notes).
  static Future<List<VaultEntry>> listMarkdownFilesRecursive(String rootUri) async {
    final result = <VaultEntry>[];
    await _collectMarkdown(rootUri, result);
    return result;
  }

  static Future<void> _collectMarkdown(String dirUri, List<VaultEntry> out) async {
    List<SafDocumentFile> docs;
    try {
      docs = await _safUtil.list(dirUri);
    } catch (_) {
      return;
    }
    for (final doc in docs) {
      if (doc.isDir) {
        if (doc.name == inboxFolderName) continue;
        await _collectMarkdown(doc.uri, out);
      } else if (doc.name.toLowerCase().endsWith('.md')) {
        out.add(VaultEntry.fromSaf(doc));
      }
    }
  }
}
