import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/todos_provider.dart';
import '../services/todos_service.dart';
import '../services/agent_service.dart';
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
          final hasCategory = item.category != null && item.category!.isNotEmpty;
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Material(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () async {
                  // UI optimistic update
                  provider.toggleCompleted(item.id);
                  // Backend update
                  final prefs = await SharedPreferences.getInstance();
                  final baseUrl = (prefs.getString('agent_base_url') ?? '').trim();
                  if (baseUrl.isEmpty) return;
                  
                  try {
                    await AgentService.toggleTodo(
                      baseUrl: baseUrl,
                      text: item.text,
                    );
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to toggle on backend: $e')));
                    }
                  }
                },
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(_iconFor(item.source), color: AppTheme.accentPurple, size: 24),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(item.text, style: const TextStyle(color: AppTheme.textPrimary, fontSize: 16)),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 4,
                              children: [
                                if (item.origin.isNotEmpty)
                                  Text(
                                    item.due != null ? '${item.origin} · due ${item.due}' : item.origin,
                                    style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                                  ),
                                if (hasCategory)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: _colorForCategory(item.category!),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      item.category!.toUpperCase(),
                                      style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.radio_button_unchecked, color: AppTheme.textSecondary),
                    ],
                  ),
                ),
              ),
            ),
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
      case 'vault_inferred':
        return Icons.auto_awesome;
      default:
        return Icons.check_box_outline_blank;
    }
  }

  Color _colorForCategory(String category) {
    switch (category) {
      case 'work': return AppTheme.statusOrange;
      case 'personal': return AppTheme.statusGreen;
      case 'uni': return AppTheme.accentPurple;
      case 'project': return AppTheme.statusRed;
      default: return AppTheme.textSecondary;
    }
  }
}
