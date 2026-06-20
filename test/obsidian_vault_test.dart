import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_os/services/obsidian_vault.dart';

void main() {
  group('VaultIndex', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('vault_test_');
      await File('${tempDir.path}/Note A.md').writeAsString('Links to [[Note B]].\n#shared');
      await Directory('${tempDir.path}/sub').create();
      await File('${tempDir.path}/sub/Note B.md').writeAsString('---\ntags: [shared]\n---\nNo outbound links.');
    });

    tearDown(() async {
      await tempDir.delete(recursive: true);
    });

    test('indexes notes recursively across subdirectories', () async {
      final index = VaultIndex();
      await index.build(tempDir);
      expect(index.allTags, {'shared'});
    });

    test('resolves wikilinks by basename regardless of folder depth', () async {
      final index = VaultIndex();
      await index.build(tempDir);
      final resolved = index.resolveLink('Note B');
      expect(resolved?.path, '${tempDir.path}/sub/Note B.md');
    });

    test('computes backlinks for a note', () async {
      final index = VaultIndex();
      await index.build(tempDir);
      final noteB = File('${tempDir.path}/sub/Note B.md');
      final backlinks = index.backlinksFor(noteB);
      expect(backlinks.map((n) => n.title), {'Note A'});
    });

    test('finds notes by tag from both frontmatter and inline forms', () async {
      final index = VaultIndex();
      await index.build(tempDir);
      final tagged = index.notesWithTag('shared').map((n) => n.title).toSet();
      expect(tagged, {'Note A', 'Note B'});
    });
  });
  group('parseFrontmatterTags', () {
    test('parses inline bracket list', () {
      const content = '---\ntags: [project, idea]\n---\nBody';
      expect(parseFrontmatterTags(content), {'project', 'idea'});
    });

    test('parses YAML list form', () {
      const content = '---\ntags:\n  - project\n  - idea\n---\nBody';
      expect(parseFrontmatterTags(content), {'project', 'idea'});
    });

    test('returns empty set when no frontmatter', () {
      expect(parseFrontmatterTags('# Just a note'), isEmpty);
    });
  });

  group('extractInlineTags', () {
    test('extracts tags from body text', () {
      expect(extractInlineTags('Some text #project/idea and #another.'), {'project/idea', 'another'});
    });

    test('ignores ATX headings', () {
      expect(extractInlineTags('# Heading\nNo tags here.'), isEmpty);
    });

    test('ignores tags inside fenced code blocks', () {
      const body = '```\n#not_a_tag\n```\n#real_tag';
      expect(extractInlineTags(body), {'real_tag'});
    });
  });

  group('extractWikilinkTargets', () {
    test('extracts plain and aliased links', () {
      expect(extractWikilinkTargets('See [[Note One]] and [[Note Two|alias]].'), {'Note One', 'Note Two'});
    });

    test('strips heading anchors', () {
      expect(extractWikilinkTargets('[[Note#Section]]'), {'Note'});
    });
  });

  group('ObsidianMarkdown.preprocess', () {
    test('converts wikilinks to tappable markdown links', () {
      final result = ObsidianMarkdown.preprocess('[[My Note]]');
      expect(result, '[My Note](wikilink:My%20Note)');
    });

    test('converts aliased wikilinks', () {
      final result = ObsidianMarkdown.preprocess('[[My Note|Click here]]');
      expect(result, '[Click here](wikilink:My%20Note)');
    });

    test('converts inline tags but leaves headings untouched', () {
      final result = ObsidianMarkdown.preprocess('# Heading #notatag\nBody #tag here');
      expect(result, '# Heading #notatag\nBody [#tag](tag:tag) here');
    });

    test('strips frontmatter from rendered output', () {
      final result = ObsidianMarkdown.preprocess('---\ntags: [a]\n---\n# Title');
      expect(result, '# Title');
    });
  });
}
