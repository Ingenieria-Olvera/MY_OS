import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/calendar_provider.dart';
import '../services/agent_service.dart';
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
            icon: const Icon(Icons.add),
            onPressed: () => _showAddEventDialog(context),
          ),
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
            itemBuilder: (context, i) => _buildTimelineTile(context, items[i]),
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

  Widget _buildTimelineTile(BuildContext context, _TimelineItem item) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: 65,
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
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
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
                    if (item.id != null && item.id!.isNotEmpty)
                      IconButton(
                        icon: const Icon(Icons.delete_outline, size: 20, color: AppTheme.textSecondary),
                        onPressed: () => _deleteEvent(context, item.id!, item.account),
                      ),
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
    return DateFormat('h:mm a').format(time.toLocal());
  }

  Future<void> _showAddEventDialog(BuildContext context) async {
    final summaryCtrl = TextEditingController();
    final startCtrl = TextEditingController();
    final endCtrl = TextEditingController();
    final cal = context.read<CalendarProvider>();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: const Text('Add Event', style: TextStyle(color: AppTheme.textPrimary)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: summaryCtrl, decoration: const InputDecoration(labelText: 'Title'), style: const TextStyle(color: AppTheme.textPrimary)),
            TextField(controller: startCtrl, decoration: const InputDecoration(labelText: 'Start (e.g. 2026-06-23T14:00:00Z)'), style: const TextStyle(color: AppTheme.textPrimary)),
            TextField(controller: endCtrl, decoration: const InputDecoration(labelText: 'End (e.g. 2026-06-23T15:00:00Z)'), style: const TextStyle(color: AppTheme.textPrimary)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              try {
                final prefs = await SharedPreferences.getInstance();
                final baseUrl = (prefs.getString('agent_base_url') ?? '').trim();
                if (baseUrl.isEmpty) throw Exception('Base URL not set');

                await AgentService.addCalendarEvent(
                  baseUrl: baseUrl,
                  summary: summaryCtrl.text,
                  start: startCtrl.text,
                  end: endCtrl.text,
                );
                if (!ctx.mounted) return;
                Navigator.pop(ctx);
                cal.refresh();
              } catch (e) {
                if (!ctx.mounted) return;
                ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text(e.toString())));
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteEvent(BuildContext context, String id, String? account) async {
    final cal = context.read<CalendarProvider>();
    try {
      final prefs = await SharedPreferences.getInstance();
      final baseUrl = (prefs.getString('agent_base_url') ?? '').trim();
      if (baseUrl.isEmpty) throw Exception('Base URL not set');

      await AgentService.deleteCalendarEvent(
        baseUrl: baseUrl,
        id: id,
        account: account,
      );
      if (!context.mounted) return;
      cal.refresh();
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }
}

class _TimelineItem {
  final String? id;
  final String? account;
  final DateTime start;
  final DateTime end;
  final bool allDay;
  final String title;
  final String? subtitle;
  final Color color;

  _TimelineItem({
    this.id,
    this.account,
    required this.start,
    required this.end,
    required this.allDay,
    required this.title,
    this.subtitle,
    required this.color,
  });

  factory _TimelineItem.fromEvent(CalendarEvent event) {
    return _TimelineItem(
      id: event.id,
      account: event.account,
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
