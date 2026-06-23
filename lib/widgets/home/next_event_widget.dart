import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/calendar_provider.dart';
import '../../theme/app_theme.dart';
import 'package:intl/intl.dart';

class NextEventWidget extends StatelessWidget {
  const NextEventWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<CalendarProvider>(
      builder: (context, provider, child) {
        final next = provider.nextEvent;
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
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Expanded(
                    child: Text(
                      'NEXT EVENT',
                      style: TextStyle(
                        color: AppTheme.accentPurple,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 2.0,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (provider.isLoading)
                    const SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppTheme.accentPurple,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              if (next == null)
                const Text('No upcoming events', style: TextStyle(color: AppTheme.textSecondary))
              else
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      next.summary,
                      style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.access_time, color: AppTheme.textSecondary, size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '${DateFormat('h:mm a').format(next.start.toLocal())} · ${next.label}',
                            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 14),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
            ],
          ),
        );
      },
    );
  }
}
