import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

class TodosWidget extends StatefulWidget {
  const TodosWidget({super.key});

  @override
  State<TodosWidget> createState() => _TodosWidgetState();
}

class _TodosWidgetState extends State<TodosWidget> {
  int _tabIndex = 0; // 0 = Today, 1 = Tomorrow, 2 = Important, 3 = Projects

  @override
  Widget build(BuildContext context) {
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
                'TASKS & PROJECTS',
                style: TextStyle(
                  color: AppTheme.accentPurple,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 2.0,
                ),
              ),
              Row(
                children: [
                  _buildTab(0, 'Today'),
                  const SizedBox(width: 8),
                  _buildTab(1, 'Tomorrow'),
                  const SizedBox(width: 8),
                  _buildTab(2, 'Important'),
                  const SizedBox(width: 8),
                  _buildTab(3, 'Projects'),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_tabIndex == 0) _buildTodoList('Today\'s List (Isar syncing...)'),
          if (_tabIndex == 1) _buildTodoList('Tomorrow\'s List (Rolls over at midnight)'),
          if (_tabIndex == 2) _buildTodoList('Important Tasks (Flagged)'),
          if (_tabIndex == 3) _buildTodoList('Project Hierarchies'),
        ],
      ),
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

  Widget _buildTodoList(String placeholderText) {
    return Column(
      children: [
        Row(
          children: [
            const Icon(Icons.check_circle_outline, color: AppTheme.textSecondary, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                placeholderText, 
                style: const TextStyle(color: AppTheme.textPrimary),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
