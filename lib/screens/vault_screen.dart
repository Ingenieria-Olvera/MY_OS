import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../theme/app_theme.dart';

class VaultScreen extends StatelessWidget {
  const VaultScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final List<String> dummyFiles = [
      "Scholarship_Radar.md",
      "Financial_Telemetry.md",
      "Sudden_thoughts.md"
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('VAULT')),
      body: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
        itemCount: dummyFiles.length,
        separatorBuilder: (context, index) => const SizedBox(height: 16),
        itemBuilder: (context, index) {
          final filename = dummyFiles[index];
          return InkWell(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => MarkdownViewerScreen(filename: filename),
                ),
              );
            },
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withOpacity(0.05)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.description_outlined, color: AppTheme.accentPurple, size: 28),
                  const SizedBox(width: 16),
                  Text(
                    filename,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class MarkdownViewerScreen extends StatelessWidget {
  final String filename;

  const MarkdownViewerScreen({super.key, required this.filename});

  @override
  Widget build(BuildContext context) {
    const String placeholderMarkdown = """
# System Overview

This is a placeholder for the Markdown content of **[File_Name]**.

## Current Directives
- **Directive Alpha:** Establish baseline metrics.
- **Directive Beta:** Integrate local markdown files from path.

> "Discipline equals freedom."

### Tactical Notes
1. Connect `path_provider` to load true .md files.
2. Render content directly from the local machine's filesystem.
3. Observe and update without cloud synchronization.
    """;

    return Scaffold(
      appBar: AppBar(
        title: Text(filename, style: const TextStyle(fontSize: 18)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Markdown(
        data: placeholderMarkdown.replaceAll('[File_Name]', filename),
        styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
          p: const TextStyle(color: AppTheme.textPrimary, fontSize: 16, height: 1.5),
          h1: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold),
          h2: const TextStyle(color: AppTheme.accentPurple, fontWeight: FontWeight.bold),
          blockquoteDecoration: BoxDecoration(
            border: const Border(left: BorderSide(color: AppTheme.accentPurple, width: 4)),
            color: AppTheme.surface,
          ),
          blockquotePadding: const EdgeInsets.all(16),
          code: const TextStyle(backgroundColor: AppTheme.surface, color: AppTheme.statusGreen),
          codeblockDecoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
    );
  }
}
