import 'package:flutter/material.dart';
import '../widgets/home/health_metrics_widget.dart';

class HealthScreen extends StatelessWidget {
  const HealthScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('HEALTH')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: const [
            HealthMetricsWidget(isNutrition: true),
            SizedBox(height: 24),
            HealthMetricsWidget(isNutrition: false),
          ],
        ),
      ),
    );
  }
}
