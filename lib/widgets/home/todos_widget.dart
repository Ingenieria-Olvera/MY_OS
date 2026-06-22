import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/todos_provider.dart';
import '../../services/todos_service.dart';
import '../../theme/app_theme.dart';

class TodosWidget extends StatefulWidget {
  const TodosWidget({super.key});

  @override
  State<TodosWidget> createState() => _TodosWidgetState();
}

class _TodosWidgetState extends State<TodosWidget> {
  int _tabIndex = 0; // 0 = Today, 1 = Important/Overarching

  @override
  Widget build(BuildContext context) {
    return Consumer<TodosProvider>(
      builder: (context, provider, child) {
        final items = _tabIndex == 0 ? provider.pendingToday : provider.pendingOverarching;
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
                'TODOS',
                style: TextStyle(
                  color: AppTheme.accentPurple,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 2.0,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _buildTab(0, 'Today'),
                  const SizedBox(width: 16),
                  _buildTab(1, 'Overarching'),
                ],
              ),
              const SizedBox(height: 16),
              if (provider.isLoading)
                const Text('Loading…', style: TextStyle(color: AppTheme.textSecondary))
              else if (items.isEmpty)
                const Text('Nothing here — nice.', style: TextStyle(color: AppTheme.textSecondary))
              else
                Column(
                  children: items.map((item) => _buildTodoRow(provider, item)).toList(),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTab(int index, String title) {
    final isSelected = _tabIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _tabIndex = index),
      child: Text(
        title,
        style: TextStyle(
          color: isSelected ? AppTheme.textPrimary : AppTheme.textSecondary,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          fontSize: 14,
        ),
      ),
    );
  }

  Widget _buildTodoRow(TodosProvider provider, TodoItem item) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: GestureDetector(
        onTap: () => provider.toggleCompleted(item.id),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.check_circle_outline, color: AppTheme.textSecondary, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.text,
                    style: const TextStyle(color: AppTheme.textPrimary),
                  ),
                  if (item.origin.isNotEmpty)
                    Text(
                      item.due != null ? '${item.origin} · due ${item.due}' : item.origin,
                      style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
