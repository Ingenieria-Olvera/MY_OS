import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

import '../providers/todos_provider.dart';
import '../services/agent_service.dart';
import '../services/todos_service.dart';
import '../theme/app_theme.dart';

class TrainingScreen extends StatefulWidget {
  const TrainingScreen({super.key});

  @override
  State<TrainingScreen> createState() => _TrainingScreenState();
}

class _TrainingScreenState extends State<TrainingScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<TodoItem> _items = [];
  int _currentIndex = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadItems();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadItems() async {
    final todosProvider = context.read<TodosProvider>();
    // Make sure we have the latest data
    await todosProvider.refresh();
    
    // Combine today and overarching, filter out completed
    final allPending = [
      ...todosProvider.pendingToday,
      ...todosProvider.pendingOverarching,
    ];

    setState(() {
      _items = allPending;
      _isLoading = false;
    });
  }

  void _nextCard() {
    setState(() {
      _currentIndex++;
    });
  }

  Future<void> _handleSwipe(TodoItem item, bool isRightSwipe) async {
    final prefs = await SharedPreferences.getInstance();
    final baseUrl = (prefs.getString('agent_base_url') ?? '').trim();
    if (baseUrl.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Agent base URL not set in chat screen.')),
        );
      }
      return;
    }

    if (isRightSwipe) {
      // Correct! Log the suggested as the chosen.
      try {
        await AgentService.sendFeedback(
          baseUrl: baseUrl,
          text: item.text,
          suggestedCategory: item.category,
          chosenCategory: item.category,
          suggestedUrgency: null, // we don't store suggested urgency on the TodoItem in Flutter right now
          chosenUrgency: null, 
          reason: 'Swiped Right (Correct)',
        );
      } catch (e) {
        debugPrint('Feedback error: $e');
      }
      _nextCard();
    } else {
      // Incorrect! Ask for the correct labels
      _showCorrectionSheet(item, baseUrl);
    }
  }

  void _showCorrectionSheet(TodoItem item, String baseUrl) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => _CorrectionSheet(
        item: item,
        baseUrl: baseUrl,
        onSubmitted: () {
          Navigator.pop(ctx);
          _nextCard();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('TRAINING'),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppTheme.accentPurple,
          labelColor: AppTheme.textPrimary,
          unselectedLabelColor: AppTheme.textSecondary,
          tabs: const [
            Tab(text: 'Swipe Cards'),
            Tab(text: 'Interactive List'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.accentPurple))
          : TabBarView(
              controller: _tabController,
              children: [
                _items.isEmpty || _currentIndex >= _items.length ? _buildEmptyState() : _buildCardStack(),
                _buildListTrainer(),
              ],
            ),
    );
  }

  Widget _buildListTrainer() {
    if (_items.isEmpty) {
      return _buildEmptyState();
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _items.length,
      itemBuilder: (context, i) {
        final item = _items[i];
        return Card(
          color: AppTheme.surface,
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            title: Text(item.text, style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold)),
            subtitle: Text(
              'Suggested: ${item.category?.toUpperCase() ?? 'NONE'}',
              style: const TextStyle(color: AppTheme.textSecondary),
            ),
            trailing: IconButton(
              icon: const Icon(Icons.edit, color: AppTheme.accentPurple),
              onPressed: () async {
                final prefs = await SharedPreferences.getInstance();
                final baseUrl = (prefs.getString('agent_base_url') ?? '').trim();
                if (baseUrl.isNotEmpty && context.mounted) {
                  _showCorrectionSheet(item, baseUrl);
                }
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.done_all, size: 64, color: AppTheme.accentPurple),
          const SizedBox(height: 16),
          const Text('All caught up!', style: TextStyle(color: AppTheme.textPrimary, fontSize: 24)),
          const SizedBox(height: 8),
          const Text('No more items to train right now.', style: TextStyle(color: AppTheme.textSecondary)),
          const SizedBox(height: 24),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accentPurple),
            onPressed: () {
              setState(() {
                _isLoading = true;
                _currentIndex = 0;
              });
              _loadItems();
            },
            child: const Text('Refresh'),
          )
        ],
      ),
    );
  }

  Widget _buildCardStack() {
    // Show top card with a GestureDetector for swiping.
    final item = _items[_currentIndex];
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        children: [
          Expanded(
            child: Center(
              child: SwipeableCard(
                item: item,
                onSwipedLeft: () => _handleSwipe(item, false),
                onSwipedRight: () => _handleSwipe(item, true),
              ),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Swipe Right if correct, Swipe Left to fix',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              IconButton(
                iconSize: 48,
                color: AppTheme.statusRed,
                icon: const Icon(Icons.close),
                onPressed: () => _handleSwipe(item, false),
              ),
              IconButton(
                iconSize: 48,
                color: AppTheme.statusGreen,
                icon: const Icon(Icons.check),
                onPressed: () => _handleSwipe(item, true),
              ),
            ],
          )
        ],
      ),
    );
  }
}

class SwipeableCard extends StatefulWidget {
  final TodoItem item;
  final VoidCallback onSwipedLeft;
  final VoidCallback onSwipedRight;

  const SwipeableCard({
    super.key,
    required this.item,
    required this.onSwipedLeft,
    required this.onSwipedRight,
  });

  @override
  State<SwipeableCard> createState() => _SwipeableCardState();
}

class _SwipeableCardState extends State<SwipeableCard> {
  Offset _position = Offset.zero;
  bool _isDragging = false;
  double _angle = 0;

  @override
  void didUpdateWidget(covariant SwipeableCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.item.id != widget.item.id) {
      _position = Offset.zero;
      _angle = 0;
    }
  }

  void _onPanStart(DragStartDetails details) {
    setState(() {
      _isDragging = true;
    });
  }

  void _onPanUpdate(DragUpdateDetails details) {
    setState(() {
      _position += details.delta;
      _angle = 45 * _position.dx / MediaQuery.of(context).size.width;
    });
  }

  void _onPanEnd(DragEndDetails details) {
    setState(() {
      _isDragging = false;
    });

    final screenWidth = MediaQuery.of(context).size.width;
    if (_position.dx > screenWidth * 0.3) {
      widget.onSwipedRight();
    } else if (_position.dx < -screenWidth * 0.3) {
      widget.onSwipedLeft();
    } else {
      // Snap back
      setState(() {
        _position = Offset.zero;
        _angle = 0;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;

    return GestureDetector(
      onPanStart: _onPanStart,
      onPanUpdate: _onPanUpdate,
      onPanEnd: _onPanEnd,
      child: AnimatedContainer(
        duration: _isDragging ? Duration.zero : const Duration(milliseconds: 300),
        curve: Curves.easeOut,
        transform: Matrix4.identity()
          ..setTranslationRaw(_position.dx, _position.dy, 0)
          ..rotateZ(_angle * 3.14159 / 180),
        child: Container(
          width: double.infinity,
          height: 400,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Badge for source
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppTheme.accentPurple.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  item.source.toUpperCase(),
                  style: const TextStyle(color: AppTheme.accentPurple, fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                item.text,
                style: const TextStyle(color: AppTheme.textPrimary, fontSize: 24, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 16),
              if (item.due != null)
                Row(
                  children: [
                    const Icon(Icons.calendar_today, color: AppTheme.textSecondary, size: 16),
                    const SizedBox(width: 8),
                    Text(
                      item.due!, // We can format this if it includes time, else just date
                      style: const TextStyle(color: AppTheme.textSecondary, fontSize: 16),
                    ),
                  ],
                ),
              const Spacer(),
              const Divider(color: Colors.white24),
              const SizedBox(height: 16),
              const Text('Suggested Category:', style: TextStyle(color: AppTheme.textSecondary, fontSize: 14)),
              const SizedBox(height: 4),
              Text(
                item.category?.toUpperCase() ?? 'NONE',
                style: TextStyle(
                  color: item.category != null ? AppTheme.accentPurple : AppTheme.textSecondary,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CorrectionSheet extends StatefulWidget {
  final TodoItem item;
  final String baseUrl;
  final VoidCallback onSubmitted;

  const _CorrectionSheet({
    required this.item,
    required this.baseUrl,
    required this.onSubmitted,
  });

  @override
  State<_CorrectionSheet> createState() => _CorrectionSheetState();
}

class _CorrectionSheetState extends State<_CorrectionSheet> {
  String? _chosenCategory;
  String? _chosenUrgency;
  bool _isNotImportant = false;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _chosenCategory = widget.item.category;
    // We default to something or null.
  }

  Future<void> _submit() async {
    setState(() => _isSubmitting = true);
    
    String? finalCat = _chosenCategory;
    String? finalUrg = _chosenUrgency;
    if (_isNotImportant) {
      finalCat = 'other'; // Log as 'other' so the AI learns to ignore similar ones
      finalUrg = 'overarching';
    }

    try {
      await AgentService.sendFeedback(
        baseUrl: widget.baseUrl,
        text: widget.item.text,
        suggestedCategory: widget.item.category,
        chosenCategory: finalCat,
        suggestedUrgency: null,
        chosenUrgency: finalUrg,
        reason: _isNotImportant ? 'Not Important' : 'Manual Correction',
      );
    } catch (e) {
      debugPrint('Correction error: $e');
    }
    widget.onSubmitted();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Correction', style: TextStyle(color: AppTheme.textPrimary, fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          
          SwitchListTile(
            title: const Text('Not Important', style: TextStyle(color: AppTheme.textPrimary)),
            subtitle: const Text('e.g. shopping list, irrelevant item', style: TextStyle(color: AppTheme.textSecondary)),
            value: _isNotImportant,
            activeColor: AppTheme.accentPurple,
            onChanged: (val) {
              setState(() => _isNotImportant = val);
            },
          ),
          
          if (!_isNotImportant) ...[
            const Divider(color: Colors.white24),
            const SizedBox(height: 16),
            const Text('Category', style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: ['personal', 'work', 'uni', 'project'].map((cat) {
                final isSelected = _chosenCategory == cat;
                return ChoiceChip(
                  label: Text(cat.toUpperCase()),
                  selected: isSelected,
                  selectedColor: AppTheme.accentPurple.withOpacity(0.2),
                  labelStyle: TextStyle(color: isSelected ? AppTheme.accentPurple : AppTheme.textPrimary),
                  onSelected: (val) => setState(() => _chosenCategory = val ? cat : null),
                );
              }).toList(),
            ),
            
            const SizedBox(height: 16),
            const Text('Urgency', style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: ['today', 'this_week', 'overarching'].map((urg) {
                final isSelected = _chosenUrgency == urg;
                return ChoiceChip(
                  label: Text(urg.toUpperCase()),
                  selected: isSelected,
                  selectedColor: AppTheme.accentPurple.withOpacity(0.2),
                  labelStyle: TextStyle(color: isSelected ? AppTheme.accentPurple : AppTheme.textPrimary),
                  onSelected: (val) => setState(() => _chosenUrgency = val ? urg : null),
                );
              }).toList(),
            ),
          ],
          
          const SizedBox(height: 24),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.accentPurple,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: _isSubmitting ? null : _submit,
            child: _isSubmitting
                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Text('Submit Correction', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          )
        ],
      ),
    );
  }
}
