import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_os/services/inbox_service.dart';

void main() {
  group('InboxDigest', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('inbox_test_');
    });

    tearDown(() async {
      await tempDir.delete(recursive: true);
    });

    test('returns empty lists when no digest files exist', () async {
      expect(await InboxDigest.readSlackMessages(tempDir), isEmpty);
      expect(await InboxDigest.readEmails(tempDir), isEmpty);
    });

    test('parses Slack messages and sorts newest first', () async {
      await File('${tempDir.path}/slack_digest.json').writeAsString('''
{
  "generated_at": "2026-06-20T15:00:00+00:00",
  "messages": [
    {"id": "1", "source": "dm", "channel": "D1", "sender": "Alice", "text": "older", "timestamp": "2026-06-20T10:00:00+00:00"},
    {"id": "2", "source": "mention", "channel": "general", "sender": "Bob", "text": "newer", "timestamp": "2026-06-20T14:00:00+00:00", "permalink": "https://x"}
  ]
}
''');
      final messages = await InboxDigest.readSlackMessages(tempDir);
      expect(messages.map((m) => m.id).toList(), ['2', '1']);
      expect(messages.first.source, 'mention');
      expect(messages.first.permalink, 'https://x');
    });

    test('parses emails and sorts newest first', () async {
      await File('${tempDir.path}/email_digest.json').writeAsString('''
{
  "generated_at": "2026-06-20T15:00:00+00:00",
  "emails": [
    {"id": "a", "sender": "x@y.com", "subject": "Old", "snippet": "...", "received_at": "2026-06-19T09:00:00+00:00", "labels": ["INBOX"]},
    {"id": "b", "sender": "z@y.com", "subject": "New", "snippet": "...", "received_at": "2026-06-20T09:00:00+00:00", "labels": ["IMPORTANT"]}
  ]
}
''');
      final emails = await InboxDigest.readEmails(tempDir);
      expect(emails.map((e) => e.id).toList(), ['b', 'a']);
      expect(emails.first.subject, 'New');
    });

    test('treats malformed JSON as empty rather than throwing', () async {
      await File('${tempDir.path}/slack_digest.json').writeAsString('not json');
      expect(await InboxDigest.readSlackMessages(tempDir), isEmpty);
    });
  });
}
