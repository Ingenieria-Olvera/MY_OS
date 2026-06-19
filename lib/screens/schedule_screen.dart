import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class ScheduleScreen extends StatelessWidget {
  const ScheduleScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final List<Map<String, String>> schedule = [
      {'time': '04:50 AM', 'event': 'Wakeup & Mobility'},
      {'time': '06:00 AM', 'event': 'Work'},
      {'time': '11:00 AM', 'event': 'Fuel Window (High Protein)'},
      {'time': '02:10 PM', 'event': 'Workout / Cardio'},
      {'time': '04:45 PM', 'event': 'Post-Workout Recovery'},
      {'time': '10:10 PM', 'event': 'Sleep Protocol'},
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('TACTICAL FLOW')),
      body: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 24.0),
        itemCount: schedule.length,
        itemBuilder: (context, index) {
          final item = schedule[index];
          final isLast = index == schedule.length - 1;
          return _buildTimelineItem(
            time: item['time']!,
            event: item['event']!,
            isLast: isLast,
          );
        },
      ),
    );
  }

  Widget _buildTimelineItem({required String time, required String event, required bool isLast}) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Time Column
          SizedBox(
            width: 75,
            child: Padding(
              padding: const EdgeInsets.only(top: 16.0),
              child: Text(
                time,
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
                textAlign: TextAlign.right,
              ),
            ),
          ),
          const SizedBox(width: 16),
          // Timeline Line and Dot
          Column(
            children: [
              Container(
                margin: const EdgeInsets.only(top: 18),
                width: 12,
                height: 12,
                decoration: const BoxDecoration(
                  color: AppTheme.accentPurple,
                  shape: BoxShape.circle,
                ),
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    color: Colors.white.withOpacity(0.1),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 16),
          // Event Content
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 24.0),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withOpacity(0.05)),
                ),
                child: Text(
                  event,
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
