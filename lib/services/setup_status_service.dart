import '../constants/vault_paths.dart';
import 'vault_access.dart';

/// Per-digest status used by the setup checklist screen: when it was last
/// written, and which Google account names actually show up in it (tagged
/// by gmail_scraper.py / calendar_scraper.py per python/README.md).
class DigestStatus {
  final DateTime? generatedAt;
  final Set<String> accountsSeen;

  DigestStatus({required this.generatedAt, required this.accountsSeen});

  static final empty = DigestStatus(generatedAt: null, accountsSeen: {});
}

/// Reads `_inbox/email_digest.json` and `_inbox/calendar_digest.json`
/// directly (rather than through InboxDigest/CalendarDigest's parsed
/// models) just to answer "is this account's data actually showing up yet",
/// for SetupChecklistScreen.
class SetupStatusService {
  static Future<DigestStatus> emailStatus([String? inboxUri]) async {
    final data = await _readDigest(inboxUri, 'email_digest.json');
    if (data == null) return DigestStatus.empty;
    final emails = (data['emails'] as List<dynamic>? ?? const []);
    final accounts = emails
        .map((e) => (e as Map<String, dynamic>)['account'] as String?)
        .whereType<String>()
        .toSet();
    return DigestStatus(
      generatedAt: DateTime.tryParse(data['generated_at'] as String? ?? ''),
      accountsSeen: accounts,
    );
  }

  static Future<DigestStatus> calendarStatus([String? inboxUri]) async {
    final data = await _readDigest(inboxUri, 'calendar_digest.json');
    if (data == null) return DigestStatus.empty;
    final events = (data['events'] as List<dynamic>? ?? const []);
    final accounts = events
        .map((e) => (e as Map<String, dynamic>)['account'] as String?)
        .whereType<String>()
        .toSet();
    return DigestStatus(
      generatedAt: DateTime.tryParse(data['generated_at'] as String? ?? ''),
      accountsSeen: accounts,
    );
  }

  static Future<Map<String, dynamic>?> _readDigest(String? inboxUri, String filename) async {
    final uri = inboxUri ?? await resolveVaultInboxUri();
    if (uri == null) return null;
    final fileEntry = await VaultAccess.child(uri, filename);
    if (fileEntry == null) return null;
    return VaultAccess.readJson(fileEntry.uri);
  }
}
