import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/dashboard_provider.dart';
import '../../theme/app_theme.dart';

class FinancialGoalsWidget extends StatelessWidget {
  const FinancialGoalsWidget({super.key});

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
                  const Text(
                    'FINANCIAL GOALS',
                    style: TextStyle(
                      color: AppTheme.accentPurple,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 2.0,
                    ),
                  ),
                  GestureDetector(
                    onTap: () => _showEditDialog(context, provider),
                    child: const Icon(Icons.add_circle_outline, color: AppTheme.accentPurple, size: 20),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (provider.goals.isEmpty)
                const Text('No goals yet. Tap + to add one.', style: TextStyle(color: AppTheme.textSecondary))
              else
                ...provider.goals.asMap().entries.map((entry) => _buildGoalRow(context, entry.key, entry.value, provider)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildGoalRow(BuildContext context, int index, FinancialGoal goal, DashboardProvider provider) {
    final monthly = goal.requiredMonthlyContribution;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: GestureDetector(
        onTap: () => _showEditDialog(context, provider, index: index, goal: goal),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  goal.name,
                  style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold, fontSize: 16),
                ),
                Text(
                  '\$${goal.currentAmount.toStringAsFixed(0)} / \$${goal.targetAmount.toStringAsFixed(0)}',
                  style: const TextStyle(color: AppTheme.textSecondary, fontSize: 14),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: goal.progress,
                minHeight: 6,
                backgroundColor: Colors.white.withOpacity(0.08),
                color: goal.isComplete ? AppTheme.statusGreen : AppTheme.accentPurple,
              ),
            ),
            if (!goal.isComplete && monthly != null) ...[
              const SizedBox(height: 6),
              Text(
                'Save \$${monthly.toStringAsFixed(0)}/mo to hit this by ${_formatDate(goal.targetDate!)}',
                style: const TextStyle(color: AppTheme.statusOrange, fontSize: 12),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${months[date.month - 1]} ${date.year}';
  }

  void _showEditDialog(BuildContext context, DashboardProvider provider, {int? index, FinancialGoal? goal}) {
    final nameController = TextEditingController(text: goal?.name ?? '');
    final targetController = TextEditingController(text: goal?.targetAmount.toString() ?? '');
    final currentController = TextEditingController(text: goal?.currentAmount.toString() ?? '0');
    DateTime? selectedDate = goal?.targetDate;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              backgroundColor: AppTheme.surface,
              title: Text(
                goal == null ? 'New Goal' : 'Edit ${goal.name}',
                style: const TextStyle(color: AppTheme.textPrimary),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(labelText: 'Goal name', labelStyle: TextStyle(color: AppTheme.textSecondary)),
                    style: const TextStyle(color: AppTheme.textPrimary),
                  ),
                  TextField(
                    controller: targetController,
                    decoration: const InputDecoration(labelText: 'Target amount', labelStyle: TextStyle(color: AppTheme.textSecondary)),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    style: const TextStyle(color: AppTheme.textPrimary),
                  ),
                  TextField(
                    controller: currentController,
                    decoration: const InputDecoration(labelText: 'Current amount', labelStyle: TextStyle(color: AppTheme.textSecondary)),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    style: const TextStyle(color: AppTheme.textPrimary),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        selectedDate == null ? 'No target date' : 'Target: ${_formatDate(selectedDate!)}',
                        style: const TextStyle(color: AppTheme.textSecondary),
                      ),
                      TextButton(
                        onPressed: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: selectedDate ?? DateTime.now().add(const Duration(days: 365)),
                            firstDate: DateTime.now(),
                            lastDate: DateTime.now().add(const Duration(days: 365 * 30)),
                          );
                          if (picked != null) setState(() => selectedDate = picked);
                        },
                        child: const Text('Pick date', style: TextStyle(color: AppTheme.accentPurple)),
                      ),
                    ],
                  ),
                ],
              ),
              actions: [
                if (goal != null && index != null)
                  TextButton(
                    onPressed: () {
                      provider.deleteGoal(index);
                      Navigator.pop(context);
                    },
                    child: const Text('Delete', style: TextStyle(color: AppTheme.statusRed)),
                  ),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel', style: TextStyle(color: AppTheme.textSecondary)),
                ),
                TextButton(
                  onPressed: () {
                    final name = nameController.text.trim();
                    final target = double.tryParse(targetController.text);
                    if (name.isEmpty || target == null) return;
                    final updated = FinancialGoal(
                      name: name,
                      targetAmount: target,
                      currentAmount: double.tryParse(currentController.text) ?? 0.0,
                      targetDate: selectedDate,
                    );
                    if (index != null) {
                      provider.updateGoal(index, updated);
                    } else {
                      provider.addGoal(updated);
                    }
                    Navigator.pop(context);
                  },
                  child: const Text('Save', style: TextStyle(color: AppTheme.accentPurple)),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
