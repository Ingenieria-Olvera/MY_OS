import 'dart:convert';
import 'dart:io';

/// A Slack DM or @-mention surfaced by `python/slack_scraper.py`.
class SlackMessage {
  final String id;
  final String source; // 'dm' or 'mention'
  final String channel;
  final String sender;
  final String text;
  final DateTime timestamp;
  final String? permalink;

  SlackMessage({
    required this.id,
    required this.source,
    required this.channel,
    required this.sender,
    required this.text,
    required this.timestamp,
    this.permalink,
  });

  factory SlackMessage.fromJson(Map<String, dynamic> data) {
    return SlackMessage(
      id: data['id'] as String,
      source: data['source'] as String? ?? 'dm',
      channel: data['channel'] as String? ?? '',
      sender: data['sender'] as String? ?? 'Unknown',
      text: data['text'] as String? ?? '',
      timestamp: DateTime.tryParse(data['timestamp'] as String? ?? '') ?? DateTime.now(),
      permalink: data['permalink'] as String?,
    );
  }
}

/// An important/unread Gmail message surfaced by `python/gmail_scraper.py`.
class EmailMessage {
  final String id;
  final String sender;
  final String subject;
  final String snippet;
  final DateTime? receivedAt;
  final List<String> labels;
  final String? link;

  EmailMessage({
    required this.id,
    required this.sender,
    required this.subject,
    required this.snippet,
    required this.receivedAt,
    required this.labels,
    this.link,
  });

  factory EmailMessage.fromJson(Map<String, dynamic> data) {
    final receivedAtRaw = data['received_at'] as String?;
    return EmailMessage(
      id: data['id'] as String,
      sender: data['sender'] as String? ?? 'Unknown',
      subject: data['subject'] as String? ?? '(no subject)',
      snippet: data['snippet'] as String? ?? '',
      receivedAt: receivedAtRaw == null ? null : DateTime.tryParse(receivedAtRaw),
      labels: (data['labels'] as List<dynamic>? ?? const []).cast<String>(),
      link: data['link'] as String?,
    );
  }
}

/// Reads the Slack/Gmail digest JSON files that the Python scrapers write
/// into the vault's `_inbox` folder.
class InboxDigest {
  static Future<List<SlackMessage>> readSlackMessages(Directory inboxDir) async {
    final data = await _readJson(inboxDir, 'slack_digest.json');
    if (data == null) return [];
    final messages = (data['messages'] as List<dynamic>? ?? const [])
        .map((m) => SlackMessage.fromJson(m as Map<String, dynamic>))
        .toList();
    messages.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return messages;
  }

  static Future<List<EmailMessage>> readEmails(Directory inboxDir) async {
    final data = await _readJson(inboxDir, 'email_digest.json');
    if (data == null) return [];
    final emails = (data['emails'] as List<dynamic>? ?? const [])
        .map((m) => EmailMessage.fromJson(m as Map<String, dynamic>))
        .toList();
    emails.sort((a, b) => (b.receivedAt ?? DateTime(0)).compareTo(a.receivedAt ?? DateTime(0)));
    return emails;
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
