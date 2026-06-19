import 'package:flutter/material.dart';
import '../widgets/home/investments_widget.dart';
import '../widgets/home/next_event_widget.dart';
import '../widgets/home/health_metrics_widget.dart';
import '../widgets/home/todos_widget.dart';
import '../widgets/home/notifications_widget.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('DAILY DASHBOARD')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Row 1: Investments + Next Event
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 3, child: const InvestmentsWidget()),
                const SizedBox(width: 16),
                Expanded(flex: 2, child: const NextEventWidget()),
              ],
            ),
            const SizedBox(height: 24),
            // Row 2: Nutrition
            const HealthMetricsWidget(isNutrition: true),
            const SizedBox(height: 24),
            // Row 3: Todos
            const TodosWidget(),
            const SizedBox(height: 24),
            // Row 4: Notifications
            const NotificationsWidget(),
            const SizedBox(height: 24),
            // Row 4: Sleep
            const HealthMetricsWidget(isNutrition: false),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

