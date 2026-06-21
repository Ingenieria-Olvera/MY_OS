import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/inbox_provider.dart';
import '../../theme/app_theme.dart';

class NotificationsWidget extends StatelessWidget {
  const NotificationsWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<InboxProvider>(
      builder: (context, provider, child) {
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
                'NEEDS A RESPONSE',
                style: TextStyle(
                  color: AppTheme.accentPurple,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 2.0,
                ),
              ),
              const SizedBox(height: 16),
              _buildNotificationItem(
                icon: Icons.mail_outline,
                title: 'Email',
                subtitle: provider.unreadEmailCount > 0
                    ? '${provider.unreadEmailCount} unread important email${provider.unreadEmailCount == 1 ? '' : 's'}'
                    : 'No recent critical emails detected.',
                color: Colors.redAccent,
              ),
              const SizedBox(height: 16),
              _buildNotificationItem(
                icon: Icons.chat_bubble_outline,
                title: 'Slack',
                subtitle: provider.unreadSlackCount > 0
                    ? '${provider.unreadSlackCount} unread message${provider.unreadSlackCount == 1 ? '' : 's'}'
                    : 'No unread direct messages.',
                color: Colors.blueAccent,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildNotificationItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 12,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
