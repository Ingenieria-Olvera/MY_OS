import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/inbox_provider.dart';
import '../theme/app_theme.dart';

class InboxScreen extends StatefulWidget {
  const InboxScreen({super.key});

  @override
  State<InboxScreen> createState() => _InboxScreenState();
}

class _InboxScreenState extends State<InboxScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<InboxProvider>(
      builder: (context, provider, child) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('INBOX'),
            bottom: TabBar(
              controller: _tabController,
              indicatorColor: AppTheme.accentPurple,
              labelColor: AppTheme.textPrimary,
              unselectedLabelColor: AppTheme.textSecondary,
              tabs: [
                Tab(text: 'Slack${provider.unreadSlackCount > 0 ? ' (${provider.unreadSlackCount})' : ''}'),
                Tab(text: 'Email${provider.unreadEmailCount > 0 ? ' (${provider.unreadEmailCount})' : ''}'),
              ],
            ),
          ),
          body: provider.isLoading
              ? const Center(child: CircularProgressIndicator(color: AppTheme.accentPurple))
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _SlackTab(provider: provider),
                    _EmailTab(provider: provider),
                  ],
                ),
        );
      },
    );
  }
}

class _SlackTab extends StatelessWidget {
  final InboxProvider provider;

  const _SlackTab({required this.provider});

  @override
  Widget build(BuildContext context) {
    if (provider.slackMessages.isEmpty) {
      return _EmptyState(
        onRefresh: provider.refresh,
        message: 'No Slack messages yet. Run python/slack_scraper.py to populate this.',
      );
    }
    return RefreshIndicator(
      onRefresh: provider.refresh,
      color: AppTheme.accentPurple,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: provider.slackMessages.length,
        itemBuilder: (context, i) {
          final message = provider.slackMessages[i];
          final isRead = provider.isRead(message.id);
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Material(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => provider.markRead(message.id),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        message.source == 'mention' ? Icons.alternate_email : Icons.chat_bubble_outline,
                        color: isRead ? AppTheme.textSecondary : AppTheme.accentPurple,
                        size: 24,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    message.sender,
                                    style: TextStyle(
                                      color: AppTheme.textPrimary,
                                      fontWeight: isRead ? FontWeight.normal : FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Text(
                                  _relativeTime(message.timestamp),
                                  style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              message.text,
                              style: const TextStyle(color: AppTheme.textSecondary),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _EmailTab extends StatelessWidget {
  final InboxProvider provider;

  const _EmailTab({required this.provider});

  @override
  Widget build(BuildContext context) {
    if (provider.emails.isEmpty) {
      return _EmptyState(
        onRefresh: provider.refresh,
        message: 'No emails yet. Run python/gmail_scraper.py to populate this.',
      );
    }
    return RefreshIndicator(
      onRefresh: provider.refresh,
      color: AppTheme.accentPurple,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: provider.emails.length,
        itemBuilder: (context, i) {
          final email = provider.emails[i];
          final isRead = provider.isRead(email.id);
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Material(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => provider.markRead(email.id),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.email_outlined,
                        color: isRead ? AppTheme.textSecondary : AppTheme.accentPurple,
                        size: 24,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    email.subject,
                                    style: TextStyle(
                                      color: AppTheme.textPrimary,
                                      fontWeight: isRead ? FontWeight.normal : FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (email.receivedAt != null)
                                  Text(
                                    _relativeTime(email.receivedAt!),
                                    style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              email.sender,
                              style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12, fontWeight: FontWeight.w500),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              email.snippet,
                              style: const TextStyle(color: AppTheme.textSecondary),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String message;
  final Future<void> Function() onRefresh;

  const _EmptyState({required this.message, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      color: AppTheme.accentPurple,
      child: ListView(
        children: [
          const SizedBox(height: 120),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              children: [
                const Icon(Icons.inbox_outlined, size: 64, color: AppTheme.textSecondary),
                const SizedBox(height: 16),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppTheme.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

String _relativeTime(DateTime time) {
  final diff = DateTime.now().difference(time);
  if (diff.inMinutes < 1) return 'now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m';
  if (diff.inHours < 24) return '${diff.inHours}h';
  if (diff.inDays < 7) return '${diff.inDays}d';
  return '${time.month}/${time.day}';
}
