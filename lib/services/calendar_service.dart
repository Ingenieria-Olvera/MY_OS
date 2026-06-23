import '../constants/vault_paths.dart';
import 'digest_fetcher.dart';
import 'vault_access.dart';

/// A single calendar event surfaced by `python/calendar_scraper.py`.
class CalendarEvent {
  final String id;
  final String label; // 'personal' | 'work' | 'school'
  final String? account; // which Google account this came from, if multi-account
  final String summary;
  final DateTime start;
  final DateTime end;
  final bool allDay;

  CalendarEvent({
    required this.id,
    required this.label,
    this.account,
    required this.summary,
    required this.start,
    required this.end,
    required this.allDay,
  });

  factory CalendarEvent.fromJson(Map<String, dynamic> data) {
    return CalendarEvent(
      id: data['id'] as String? ?? '',
      label: data['label'] as String? ?? '',
      account: data['account'] as String?,
      summary: data['summary'] as String? ?? '(untitled)',
      start: DateTime.tryParse(data['start'] as String? ?? '') ?? DateTime.now(),
      end: DateTime.tryParse(data['end'] as String? ?? '') ?? DateTime.now(),
      allDay: data['all_day'] as bool? ?? false,
    );
  }
}

/// A suggested free-time activity (exercise/study/wind_down) computed by
/// `python/calendar_scraper.py` from the gaps between the day's events.
class DaySuggestion {
  final DateTime start;
  final DateTime end;
  final String type; // 'exercise' | 'study' | 'wind_down'
  final String reason;

  DaySuggestion({
    required this.start,
    required this.end,
    required this.type,
    required this.reason,
  });

  factory DaySuggestion.fromJson(Map<String, dynamic> data) {
    return DaySuggestion(
      start: DateTime.tryParse(data['start'] as String? ?? '') ?? DateTime.now(),
      end: DateTime.tryParse(data['end'] as String? ?? '') ?? DateTime.now(),
      type: data['type'] as String? ?? '',
      reason: data['reason'] as String? ?? '',
    );
  }
}

/// Reads the calendar digest JSON file that `python/calendar_scraper.py`
/// writes into the vault's `_inbox` folder (resolved via the SAF-picked
/// vault — see [VaultAccess]).
class CalendarDigest {
  static Future<List<CalendarEvent>> readEvents([String? inboxUri]) async {
    final data = await _readDigest(inboxUri);
    if (data == null) return [];
    final events = (data['events'] as List<dynamic>? ?? const [])
        .map((e) => CalendarEvent.fromJson(e as Map<String, dynamic>))
        .toList();
    events.sort((a, b) => a.start.compareTo(b.start));
    return events;
  }

  static Future<List<DaySuggestion>> readSuggestions([String? inboxUri]) async {
    final data = await _readDigest(inboxUri);
    if (data == null) return [];
    final suggestions = (data['suggestions'] as List<dynamic>? ?? const [])
        .map((s) => DaySuggestion.fromJson(s as Map<String, dynamic>))
        .toList();
    suggestions.sort((a, b) => a.start.compareTo(b.start));
    return suggestions;
  }

  static Future<Map<String, dynamic>?> _readDigest(String? inboxUri) async {
    return DigestFetcher.read('calendar', 'calendar_digest.json', inboxUri);
  }
}
