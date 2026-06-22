import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/todos_provider.dart';
import '../services/todos_service.dart';
import '../theme/app_theme.dart';

class TodosScreen extends StatefulWidget {
  const TodosScreen({super.key});

  @override
  State<TodosScreen> createState() => _TodosScreenState();
}

class _TodosScreenState extends State<TodosScreen> with SingleTickerProviderStateMixin {
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
    return Consumer<TodosProvider>(
      builder: (context, provider, child) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('TODOS'),
            bottom: TabBar(
              controller: _tabController,
              indicatorColor: AppTheme.accentPurple,
              labelColor: AppTheme.textPrimary,
              unselectedLabelColor: AppTheme.textSecondary,
              tabs: [
                Tab(text: 'Today (${provider.pendingToday.length})'),
                Tab(text: 'Overarching (${provider.pendingOverarching.length})'),
              ],
            ),
          ),
          body: provider.isLoading
              ? const Center(child: CircularProgressIndicator(color: AppTheme.accentPurple))
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _TodoList(items: provider.pendingToday, provider: provider),
                    _TodoList(items: provider.pendingOverarching, provider: provider),
                  ],
                ),
        );
      },
    );
  }
}

class _TodoList extends StatelessWidget {
  final List<TodoItem> items;
  final TodosProvider provider;

  const _TodoList({required this.items, required this.provider});

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return RefreshIndicator(
        onRefresh: provider.refresh,
        color: AppTheme.accentPurple,
        child: ListView(
          children: const [
            SizedBox(height: 120),
            Center(
              child: Icon(Icons.check_circle_outline, size: 64, color: AppTheme.textSecondary),
            ),
            SizedBox(height: 16),
            Center(
              child: Text('Nothing here — nice.', style: TextStyle(color: AppTheme.textSecondary)),
            ),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: provider.refresh,
      color: AppTheme.accentPurple,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: items.length,
        itemBuilder: (context, i) {
          final item = items[i];
          return ListTile(
            onTap: () => provider.toggleCompleted(item.id),
            leading: Icon(_iconFor(item.source), color: AppTheme.accentPurple),
            title: Text(item.text, style: const TextStyle(color: AppTheme.textPrimary)),
            subtitle: item.origin.isNotEmpty
                ? Text(
                    item.due != null ? '${item.origin} · due ${item.due}' : item.origin,
                    style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                  )
                : null,
          );
        },
      ),
    );
  }

  IconData _iconFor(String source) {
    switch (source) {
      case 'calendar':
        return Icons.event_outlined;
      case 'email':
        return Icons.email_outlined;
      default:
        return Icons.check_circle_outline;
    }
  }
}
