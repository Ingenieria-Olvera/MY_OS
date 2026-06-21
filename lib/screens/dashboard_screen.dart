import 'package:flutter/material.dart';
import '../widgets/home/next_event_widget.dart';
import '../widgets/home/calendar_suggestions_widget.dart';
import '../widgets/home/todos_widget.dart';
import '../widgets/home/notifications_widget.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('TODAY')),
      body: SingleChildScrollView(
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
    );
  }
}
