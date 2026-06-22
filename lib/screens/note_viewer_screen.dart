import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../services/obsidian_vault.dart';
import '../services/vault_access.dart';
import '../theme/app_theme.dart';
import 'tag_notes_screen.dart';

class NoteViewerScreen extends StatefulWidget {
  final VaultEntry entry;
  final VaultIndex index;

  const NoteViewerScreen({super.key, required this.entry, required this.index});

  @override
  State<NoteViewerScreen> createState() => _NoteViewerScreenState();
}

class _NoteViewerScreenState extends State<NoteViewerScreen> {
  String _content = '';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final raw = await VaultAccess.readAsString(widget.entry.uri);
    setState(() {
      _content = raw ?? '';
      _isLoading = false;
    });
  }

  String get _title {
    final name = widget.entry.name;
    return name.endsWith('.md') ? name.substring(0, name.length - 3) : name;
  }

  @override
  Widget build(BuildContext context) {
    final backlinks = widget.index.backlinksFor(widget.entry);

    return Scaffold(
      appBar: AppBar(title: Text(_title)),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.accentPurple))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  MarkdownBody(
                    data: ObsidianMarkdown.preprocess(_content),
                    selectable: true,
                    onTapLink: _handleTapLink,
                    styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
                      p: const TextStyle(color: AppTheme.textPrimary, fontSize: 16, height: 1.5),
                      h1: const TextStyle(color: AppTheme.accentPurple, fontSize: 24, fontWeight: FontWeight.bold),
                      h2: const TextStyle(color: AppTheme.textPrimary, fontSize: 20, fontWeight: FontWeight.bold),
                      a: const TextStyle(
                        color: AppTheme.accentPurple,
                        fontWeight: FontWeight.w600,
                        decoration: TextDecoration.underline,
                      ),
                      code: const TextStyle(backgroundColor: Color(0xFF1E1E1E), color: AppTheme.statusGreen),
                    ),
                  ),
                  if (backlinks.isNotEmpty) ...[
                    const SizedBox(height: 32),
                    Divider(color: Colors.white.withOpacity(0.08)),
                    const SizedBox(height: 12),
                    Text(
                      'LINKED MENTIONS (${backlinks.length})',
                      style: const TextStyle(
                        color: AppTheme.accentPurple,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 2.0,
                      ),
                    ),
                    ...backlinks.map((n) => ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.description_outlined, color: AppTheme.textSecondary),
                          title: Text(n.title, style: const TextStyle(color: AppTheme.textPrimary)),
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => NoteViewerScreen(entry: n.entry, index: widget.index)),
                          ),
                        )),
                  ],
                ],
              ),
            ),
    );
  }

  void _handleTapLink(String text, String? href, String title) {
    if (href == null) return;

    if (href.startsWith('wikilink:')) {
      final target = Uri.decodeComponent(href.substring('wikilink:'.length));
      final entry = widget.index.resolveLink(target);
      if (entry != null) {
        Navigator.push(context, MaterialPageRoute(builder: (_) => NoteViewerScreen(entry: entry, index: widget.index)));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Note "$target" not found in vault')),
        );
      }
    } else if (href.startsWith('tag:')) {
      final tag = Uri.decodeComponent(href.substring('tag:'.length));
      Navigator.push(context, MaterialPageRoute(builder: (_) => TagNotesScreen(tag: tag, index: widget.index)));
    }
  }
}
