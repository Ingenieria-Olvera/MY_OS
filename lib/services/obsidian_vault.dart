import 'dart:io';

/// A single Markdown note discovered while indexing the vault.
class VaultNote {
  final File file;
  final String title;
  final Set<String> tags;
  final Set<String> linkTargets;

  VaultNote({
    required this.file,
    required this.title,
    required this.tags,
    required this.linkTargets,
  });
}

/// Recursively indexes an Obsidian-style vault so wikilinks, tags, and
/// backlinks can be resolved without re-reading the filesystem on every tap.
class VaultIndex {
  final Map<String, VaultNote> _notesByPath = {};
  final Map<String, List<File>> _filesByBasename = {};

  Set<String> get allTags {
    final tags = <String>{};
    for (final note in _notesByPath.values) {
      tags.addAll(note.tags);
    }
    return tags;
  }

  List<VaultNote> notesWithTag(String tag) =>
      _notesByPath.values.where((n) => n.tags.contains(tag)).toList();

  Future<void> build(Directory root) async {
    _notesByPath.clear();
    _filesByBasename.clear();
    if (!root.existsSync()) return;

    final files = root
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.md'))
        .toList();

    for (final file in files) {
      final key = _basenameNoExt(file.path).toLowerCase();
      _filesByBasename.putIfAbsent(key, () => []).add(file);
    }

    for (final file in files) {
      String content;
      try {
        content = await file.readAsString();
      } catch (_) {
        continue;
      }
      final body = stripFrontmatter(content);
      final tags = {...parseFrontmatterTags(content), ...extractInlineTags(body)};
      _notesByPath[file.path] = VaultNote(
        file: file,
        title: _basenameNoExt(file.path),
        tags: tags,
        linkTargets: extractWikilinkTargets(body),
      );
    }
  }

  /// Resolves a wikilink target (e.g. "Note Name" from `[[Note Name]]`) to a
  /// file anywhere in the vault, matching Obsidian's basename resolution.
  File? resolveLink(String target) {
    final key = target.split('#').first.trim().toLowerCase();
    final matches = _filesByBasename[key];
    if (matches == null || matches.isEmpty) return null;
    return matches.first;
  }

  List<VaultNote> backlinksFor(File file) {
    final targetKey = _basenameNoExt(file.path).toLowerCase();
    return _notesByPath.values
        .where((n) => n.file.path != file.path && n.linkTargets.any((t) => t.toLowerCase() == targetKey))
        .toList();
  }

  static String _basenameNoExt(String path) {
    final name = path.split('/').last;
    return name.endsWith('.md') ? name.substring(0, name.length - 3) : name;
  }
}

String stripFrontmatter(String content) {
  if (!content.startsWith('---')) return content;
  final end = content.indexOf('\n---', 3);
  if (end == -1) return content;
  final lineEnd = content.indexOf('\n', end + 4);
  if (lineEnd == -1) return '';
  return content.substring(lineEnd + 1);
}

/// Parses the `tags:` field out of Obsidian-style YAML frontmatter, handling
/// both inline (`tags: [a, b]` / `tags: a, b`) and list (`tags:\n  - a`) forms.
Set<String> parseFrontmatterTags(String content) {
  if (!content.startsWith('---')) return {};
  final end = content.indexOf('\n---', 3);
  if (end == -1) return {};
  final lines = content.substring(3, end).split('\n');

  for (int i = 0; i < lines.length; i++) {
    final match = RegExp(r'^\s*tags:\s*(.*)$').firstMatch(lines[i]);
    if (match == null) continue;

    final tags = <String>{};
    final inline = match.group(1)!.trim().replaceAll('[', '').replaceAll(']', '');
    if (inline.isNotEmpty) {
      for (final t in inline.split(',')) {
        final trimmed = t.trim();
        if (trimmed.isNotEmpty) tags.add(trimmed);
      }
    } else {
      for (int j = i + 1; j < lines.length; j++) {
        final item = RegExp(r'^\s*-\s*(.+)$').firstMatch(lines[j]);
        if (item == null) break;
        tags.add(item.group(1)!.trim());
      }
    }
    return tags;
  }
  return {};
}

/// Extracts inline `#tags` from note body text, skipping fenced code blocks
/// and ATX headings (`# Heading`) so `#` doesn't get misread as a tag.
Set<String> extractInlineTags(String body) {
  final tags = <String>{};
  bool inCodeBlock = false;

  for (final line in body.split('\n')) {
    if (line.trim().startsWith('```')) {
      inCodeBlock = !inCodeBlock;
      continue;
    }
    if (inCodeBlock || RegExp(r'^\s*#+\s').hasMatch(line)) continue;

    for (int i = 0; i < line.length; i++) {
      if (line[i] != '#') continue;
      if (i > 0 && _isWordChar(line[i - 1])) continue;

      int j = i + 1;
      final buffer = StringBuffer();
      while (j < line.length && _isTagChar(line[j])) {
        buffer.write(line[j]);
        j++;
      }
      final tag = buffer.toString();
      if (tag.isNotEmpty && _isWordChar(tag[0])) tags.add(tag);
    }
  }
  return tags;
}

/// Extracts the target note name out of each `[[Note]]`, `[[Note|Alias]]`,
/// `[[Note#Heading]]`, or `[[Note#Heading|Alias]]` wikilink in the body.
Set<String> extractWikilinkTargets(String body) {
  final targets = <String>{};
  for (final m in RegExp(r'\[\[([^\]|#]+)').allMatches(body)) {
    final target = m.group(1)!.trim();
    if (target.isNotEmpty) targets.add(target);
  }
  return targets;
}

bool _isWordChar(String c) => RegExp(r'[A-Za-z0-9_]').hasMatch(c);
bool _isTagChar(String c) => RegExp(r'[A-Za-z0-9_/-]').hasMatch(c);

/// Rewrites Obsidian wikilink/tag syntax into plain Markdown links with a
/// custom scheme (`wikilink:`, `tag:`) so [MarkdownTapLinkCallback] can
/// intercept taps and route them within the app.
class ObsidianMarkdown {
  static String preprocess(String content) {
    final withoutFrontmatter = stripFrontmatter(content);
    return _convertTags(_convertWikilinks(withoutFrontmatter));
  }

  static String _convertWikilinks(String content) {
    final regex = RegExp(r'\[\[([^\]|#]+)(?:#[^\]|]+)?(?:\|([^\]]+))?\]\]');
    return content.replaceAllMapped(regex, (m) {
      final target = m.group(1)!.trim();
      final alias = m.group(2)?.trim();
      final display = alias ?? target;
      return '[$display](wikilink:${Uri.encodeComponent(target)})';
    });
  }

  static String _convertTags(String content) {
    final tagRegex = RegExp(r'(^|[\s])#([A-Za-z0-9_/-]+)');
    bool inCodeBlock = false;

    return content.split('\n').map((line) {
      if (line.trim().startsWith('```')) {
        inCodeBlock = !inCodeBlock;
        return line;
      }
      if (inCodeBlock || RegExp(r'^\s*#+\s').hasMatch(line)) return line;

      return line.replaceAllMapped(tagRegex, (m) {
        final boundary = m.group(1)!;
        final tag = m.group(2)!;
        return '$boundary[#$tag](tag:${Uri.encodeComponent(tag)})';
      });
    }).join('\n');
  }
}
