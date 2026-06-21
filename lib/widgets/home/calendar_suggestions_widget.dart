import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/calendar_provider.dart';
import '../../services/calendar_service.dart';
import '../../theme/app_theme.dart';

class CalendarSuggestionsWidget extends StatelessWidget {
  const CalendarSuggestionsWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<CalendarProvider>(
      builder: (context, provider, child) {
        if (provider.suggestions.isEmpty) return const SizedBox.shrink();
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.05)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'TODAY\'S OPEN WINDOWS',
                style: TextStyle(
                  color: AppTheme.accentPurple,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 2.0,
                ),
              ),
              const SizedBox(height: 16),
              ...provider.suggestions.map((s) => _buildSuggestionRow(context, s)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSuggestionRow(BuildContext context, DaySuggestion s) {
    final start = TimeOfDay.fromDateTime(s.start).format(context);
    final end = TimeOfDay.fromDateTime(s.end).format(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(_iconFor(s.type), color: AppTheme.accentPurple, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${_labelFor(s.type)} · $start–$end',
                  style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold),
                ),
                Text(s.reason, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  IconData _iconFor(String type) {
    switch (type) {
      case 'exercise':
        return Icons.fitness_center;
      case 'wind_down':
        return Icons.nightlight_outlined;
      default:
        return Icons.menu_book_outlined;
    }
  }

  String _labelFor(String type) {
    switch (type) {
      case 'exercise':
        return 'Exercise';
      case 'wind_down':
        return 'Wind down';
      default:
        return 'Study';
    }
  }
}
