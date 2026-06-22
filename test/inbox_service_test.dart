import 'package:flutter_test/flutter_test.dart';
import 'package:my_os/services/inbox_service.dart';

void main() {
  group('SlackMessage.fromJson', () {
    test('parses all fields', () {
      final message = SlackMessage.fromJson({
        'id': '1',
        'source': 'mention',
        'channel': 'general',
        'sender': 'Bob',
        'text': 'hello',
        'timestamp': '2026-06-20T14:00:00+00:00',
        'permalink': 'https://x',
      });
      expect(message.id, '1');
      expect(message.source, 'mention');
      expect(message.permalink, 'https://x');
    });

    test('defaults missing optional fields', () {
      final message = SlackMessage.fromJson({'id': '1'});
      expect(message.source, 'dm');
      expect(message.channel, '');
      expect(message.sender, 'Unknown');
      expect(message.permalink, isNull);
    });
  });

  group('EmailMessage.fromJson', () {
    test('parses all fields', () {
      final email = EmailMessage.fromJson({
        'id': 'a',
        'sender': 'x@y.com',
        'subject': 'Hi',
        'snippet': '...',
        'received_at': '2026-06-19T09:00:00+00:00',
        'labels': ['IMPORTANT'],
        'link': 'https://mail',
      });
      expect(email.id, 'a');
      expect(email.labels, ['IMPORTANT']);
      expect(email.receivedAt, DateTime.parse('2026-06-19T09:00:00+00:00'));
    });

    test('defaults missing optional fields', () {
      final email = EmailMessage.fromJson({'id': 'a'});
      expect(email.sender, 'Unknown');
      expect(email.subject, '(no subject)');
      expect(email.receivedAt, isNull);
      expect(email.labels, isEmpty);
    });
  });
}
