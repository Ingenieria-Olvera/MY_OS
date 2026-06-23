import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/calendar_provider.dart';
import '../providers/inbox_provider.dart';
import '../providers/todos_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/home/next_event_widget.dart';
import '../widgets/home/calendar_suggestions_widget.dart';
import '../widgets/home/todos_widget.dart';
import '../widgets/home/notifications_widget.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  Future<void> _refresh(BuildContext context) async {
    final calendar = context.read<CalendarProvider>();
    final todos    = context.read<TodosProvider>();
    final inbox    = context.read<InboxProvider>();
    await Future.wait([calendar.refresh(), todos.refresh(), inbox.refresh()]);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('TODAY')),
      body: RefreshIndicator(
        onRefresh: () => _refresh(context),
        color: AppTheme.accentPurple,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const NextEventWidget(),
              const SizedBox(height: 24),
              const CalendarSuggestionsWidget(),
              const SizedBox(height: 24),
              const TodosWidget(),
              const SizedBox(height: 24),
              const NotificationsWidget(),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
