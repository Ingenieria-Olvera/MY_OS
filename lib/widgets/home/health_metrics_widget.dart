import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/dashboard_provider.dart';
import '../../theme/app_theme.dart';

class HealthMetricsWidget extends StatelessWidget {
  final bool isNutrition;

  const HealthMetricsWidget({super.key, required this.isNutrition});

  @override
  Widget build(BuildContext context) {
    return Consumer<DashboardProvider>(
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
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    isNutrition ? 'NUTRITION' : 'SLEEP',
                    style: const TextStyle(
                      color: AppTheme.accentPurple,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 2.0,
                    ),
                  ),
                  if (provider.isFetchingHealth)
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
              if (!provider.isHealthConnected)
                Center(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.accentPurple.withOpacity(0.2),
                      foregroundColor: AppTheme.accentPurple,
                    ),
                    onPressed: () => provider.connectHealth(),
                    child: const Text('Connect Samsung Health'),
                  ),
                )
              else if (isNutrition)
                _buildNutritionContent(provider)
              else
                _buildSleepContent(provider),
            ],
          ),
        );
      },
    );
  }

  Widget _buildNutritionContent(DashboardProvider provider) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _buildMetricColumn('Calories', '${provider.totalCalories.toStringAsFixed(0)} kcal'),
        _buildMetricColumn('Protein', '${provider.proteinGrams.toStringAsFixed(0)} g'),
      ],
    );
  }

  Widget _buildSleepContent(DashboardProvider provider) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _buildMetricColumn('Duration', '${provider.sleepHours.toStringAsFixed(1)} h'),
        _buildMetricColumn('Score', '${provider.sleepScore > 0 ? provider.sleepScore : "--"}', color: AppTheme.statusOrange),
      ],
    );
  }

  Widget _buildMetricColumn(String label, String value, {Color color = AppTheme.textPrimary}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 14)),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}
