import 'package:flutter/material.dart';
import '../services/obsidian_vault.dart';
import '../theme/app_theme.dart';
import 'tag_notes_screen.dart';

class VaultTagsScreen extends StatelessWidget {
  final VaultIndex index;

  const VaultTagsScreen({super.key, required this.index});

  @override
  Widget build(BuildContext context) {
    final tags = index.allTags.toList()..sort();

    return Scaffold(
      appBar: AppBar(title: const Text('TAGS')),
      body: tags.isEmpty
          ? const Center(
              child: Text('No tags found in vault.', style: TextStyle(color: AppTheme.textSecondary)),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: tags.length,
              itemBuilder: (context, i) {
                final tag = tags[i];
                final count = index.notesWithTag(tag).length;
                return ListTile(
                  leading: const Icon(Icons.tag, color: AppTheme.accentPurple),
                  title: Text('#$tag', style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold)),
                  trailing: Text('$count', style: const TextStyle(color: AppTheme.textSecondary)),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => TagNotesScreen(tag: tag, index: index)),
                  ),
                );
              },
            ),
    );
  }
}
