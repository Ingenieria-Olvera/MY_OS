import 'package:flutter/material.dart';
import '../services/obsidian_vault.dart';
import '../theme/app_theme.dart';
import 'note_viewer_screen.dart';

class TagNotesScreen extends StatelessWidget {
  final String tag;
  final VaultIndex index;

  const TagNotesScreen({super.key, required this.tag, required this.index});

  @override
  Widget build(BuildContext context) {
    final notes = index.notesWithTag(tag);

    return Scaffold(
      appBar: AppBar(title: Text('#$tag')),
      body: notes.isEmpty
          ? const Center(
              child: Text('No notes with this tag.', style: TextStyle(color: AppTheme.textSecondary)),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: notes.length,
              itemBuilder: (context, i) {
                final note = notes[i];
                return ListTile(
                  leading: const Icon(Icons.description_outlined, color: AppTheme.accentPurple),
                  title: Text(note.title, style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold)),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => NoteViewerScreen(entry: note.entry, index: index)),
                  ),
                );
              },
            ),
    );
  }
}
