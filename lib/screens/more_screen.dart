import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'chat_screen.dart';
import 'financial_screen.dart';
import 'health_screen.dart';
import 'notes_screen.dart';

class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('MORE')),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          _buildTile(context, Icons.chat_bubble_outline, 'Secretary Chat', const ChatScreen()),
          _buildTile(context, Icons.description_outlined, 'Notes', const NotesScreen()),
          _buildTile(context, Icons.account_balance_outlined, 'Financial', const FinancialScreen()),
          _buildTile(context, Icons.favorite_outline, 'Health', const HealthScreen()),
        ],
      ),
    );
  }

  Widget _buildTile(BuildContext context, IconData icon, String title, Widget screen) {
    return ListTile(
      leading: Icon(icon, color: AppTheme.accentPurple),
      title: Text(title, style: const TextStyle(color: AppTheme.textPrimary)),
      trailing: const Icon(Icons.chevron_right, color: AppTheme.textSecondary),
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => screen)),
    );
  }
}
