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
          floatingActionButton: FloatingActionButton(
            backgroundColor: AppTheme.accentPurple,
            onPressed: () => _showAddTodoDialog(context, provider),
            child: const Icon(Icons.add, color: Colors.white),
          ),
        );
      },
    );
  }

  void _showAddTodoDialog(BuildContext context, TodosProvider provider) {
    final textController = TextEditingController();
    String? category;
    bool ongoing = false;
    bool pinToday = false;
    DateTime? due;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: AppTheme.surface,
          title: const Text('New Todo', style: TextStyle(color: AppTheme.textPrimary)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: textController,
                  autofocus: true,
                  style: const TextStyle(color: AppTheme.textPrimary),
                  decoration: const InputDecoration(
                    labelText: 'What needs doing?',
                    labelStyle: TextStyle(color: AppTheme.textSecondary),
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  children: [
                    ChoiceChip(
                      label: const Text('Personal'),
                      selected: category == 'personal',
                      onSelected: (sel) => setDialogState(() => category = sel ? 'personal' : null),
                    ),
                    ChoiceChip(
                      label: const Text('Work'),
                      selected: category == 'work',
                      onSelected: (sel) => setDialogState(() => category = sel ? 'work' : null),
                    ),
                  ],
                ),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  title: const Text('Pin to today (#today)', style: TextStyle(color: AppTheme.textPrimary)),
                  value: pinToday,
                  onChanged: (v) => setDialogState(() => pinToday = v ?? false),
                ),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  title: const Text('Ongoing (#ongoing)', style: TextStyle(color: AppTheme.textPrimary)),
                  value: ongoing,
                  onChanged: (v) => setDialogState(() => ongoing = v ?? false),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.calendar_today_outlined, color: AppTheme.textSecondary),
                  title: Text(
                    due == null ? 'No due date' : 'Due ${due!.toIso8601String().split('T').first}',
                    style: const TextStyle(color: AppTheme.textPrimary),
                  ),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: due ?? DateTime.now(),
                      firstDate: DateTime.now().subtract(const Duration(days: 365)),
                      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
                    );
                    if (picked != null) setDialogState(() => due = picked);
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: AppTheme.textSecondary)),
            ),
            TextButton(
              onPressed: () async {
                final dueIso = due?.toIso8601String().split('T').first;
                final added = await provider.addTodo(
                  text: textController.text,
                  due: dueIso,
                  ongoing: ongoing,
                  pinToday: pinToday,
                  category: category,
                );
                if (!context.mounted) return;
                Navigator.pop(context);
                if (!added) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Pick a vault folder first, or enter some text.')),
                  );
                }
              },
              child: const Text('Add', style: TextStyle(color: AppTheme.accentPurple)),
            ),
          ],
        ),
      ),
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
