import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/calendar_provider.dart';
import '../services/calendar_service.dart';
import '../theme/app_theme.dart';

/// Full-day timeline: every calendar event for today, across all connected
/// accounts, interleaved with the free-time suggestions computed by
/// `python/calendar_scraper.py`.
class CalendarScreen extends StatelessWidget {
  const CalendarScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('TODAY'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => context.read<CalendarProvider>().refresh(),
          ),
        ],
      ),
      body: Consumer<CalendarProvider>(
        builder: (context, provider, _) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator(color: AppTheme.accentPurple));
          }
          final items = _mergeTimeline(provider.events, provider.suggestions);
          if (items.isEmpty) {
            return const Center(
              child: Text('Nothing scheduled today.', style: TextStyle(color: AppTheme.textSecondary)),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            itemBuilder: (context, i) => _buildTimelineTile(items[i]),
          );
        },
      ),
    );
  }

  List<_TimelineItem> _mergeTimeline(List<CalendarEvent> events, List<DaySuggestion> suggestions) {
    final items = <_TimelineItem>[
      ...events.map(_TimelineItem.fromEvent),
      ...suggestions.map(_TimelineItem.fromSuggestion),
    ];
    items.sort((a, b) => a.start.compareTo(b.start));
    return items;
  }

  Widget _buildTimelineTile(_TimelineItem item) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: 56,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.allDay ? 'ALL DAY' : _friendlyTime(item.start),
                    style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                  if (!item.allDay)
                    Text(
                      _friendlyTime(item.end),
                      style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11),
                    ),
                ],
              ),
            ),
            Container(width: 3, margin: const EdgeInsets.symmetric(horizontal: 8), color: item.color),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.title, style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold)),
                    if (item.subtitle != null) ...[
                      const SizedBox(height: 4),
                      Text(item.subtitle!, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _friendlyTime(DateTime time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}

class _TimelineItem {
  final DateTime start;
  final DateTime end;
  final bool allDay;
  final String title;
  final String? subtitle;
  final Color color;

  _TimelineItem({
    required this.start,
    required this.end,
    required this.allDay,
    required this.title,
    this.subtitle,
    required this.color,
  });

  factory _TimelineItem.fromEvent(CalendarEvent event) {
    return _TimelineItem(
      start: event.start,
      end: event.end,
      allDay: event.allDay,
      title: event.summary,
      subtitle: [event.label, event.account].where((s) => s != null && s.isNotEmpty).join(' · '),
      color: _colorForLabel(event.label),
    );
  }

  factory _TimelineItem.fromSuggestion(DaySuggestion suggestion) {
    return _TimelineItem(
      start: suggestion.start,
      end: suggestion.end,
      allDay: false,
      title: _titleForSuggestionType(suggestion.type),
      subtitle: suggestion.reason,
      color: AppTheme.statusGreen,
    );
  }

  static String _titleForSuggestionType(String type) {
    switch (type) {
      case 'exercise':
        return 'Suggested: Exercise';
      case 'study':
        return 'Suggested: Study';
      case 'wind_down':
        return 'Suggested: Wind Down';
      default:
        return 'Suggested free time';
    }
  }

  static Color _colorForLabel(String label) {
    switch (label) {
      case 'work':
        return AppTheme.statusOrange;
      case 'school':
        return AppTheme.accentPurple;
      default:
        return AppTheme.statusRed;
    }
  }
}
