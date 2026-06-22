import 'package:flutter/material.dart';
import '../services/obsidian_vault.dart';
import '../services/vault_access.dart';
import '../theme/app_theme.dart';
import 'note_viewer_screen.dart';
import 'vault_tags_screen.dart';

class NotesScreen extends StatefulWidget {
  const NotesScreen({super.key});

  @override
  State<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends State<NotesScreen> {
  final List<VaultEntry> _pathStack = [];
  List<VaultEntry> _entities = [];
  final VaultIndex _index = VaultIndex();
  bool _hasAccess = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final hasAccess = await VaultAccess.hasVaultAccess();
    if (!hasAccess) {
      setState(() {
        _hasAccess = false;
        _isLoading = false;
      });
      return;
    }
    final rootUri = await VaultAccess.getVaultRootUri();
    _pathStack
      ..clear()
      ..add(VaultEntry(uri: rootUri!, name: 'VAULT', isDir: true));
    await _loadDirectory();
    await _rebuildIndex();
    setState(() {
      _hasAccess = true;
      _isLoading = false;
    });
  }

  Future<void> _pickFolder() async {
    final uri = await VaultAccess.pickVaultFolder();
    if (uri == null) return;
    setState(() => _isLoading = true);
    _pathStack
      ..clear()
      ..add(VaultEntry(uri: uri, name: 'VAULT', isDir: true));
    await _loadDirectory();
    await _rebuildIndex();
    setState(() {
      _hasAccess = true;
      _isLoading = false;
    });
  }

  Future<void> _rebuildIndex() async {
    await _index.build(_pathStack.isEmpty ? null : _pathStack.first.uri);
  }

  Future<void> _loadDirectory() async {
    final children = await VaultAccess.list(_pathStack.last.uri);
    final items = children.where((e) {
      if (e.isDir) return e.name != VaultAccess.inboxFolderName && !e.name.startsWith('.');
      return e.name.toLowerCase().endsWith('.md');
    }).toList();

    items.sort((a, b) {
      if (a.isDir && !b.isDir) return -1;
      if (!a.isDir && b.isDir) return 1;
      return a.name.compareTo(b.name);
    });

    setState(() => _entities = items);
  }

  void _openNote(VaultEntry entry) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => NoteViewerScreen(entry: entry, index: _index)),
    );
  }

  Future<void> _enterDir(VaultEntry entry) async {
    _pathStack.add(entry);
    await _loadDirectory();
  }

  Future<void> _goUp() async {
    if (_pathStack.length > 1) {
      _pathStack.removeLast();
      await _loadDirectory();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isRoot = _pathStack.length <= 1;

    return Scaffold(
      appBar: AppBar(
        leading: (_hasAccess && !isRoot)
            ? IconButton(icon: const Icon(Icons.arrow_back), onPressed: _goUp)
            : null,
        title: Text(isRoot ? 'OBSIDIAN VAULT' : _pathStack.last.name),
        actions: [
          if (_hasAccess)
            IconButton(
              icon: const Icon(Icons.tag),
              tooltip: 'Browse by tag',
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => VaultTagsScreen(index: _index)),
              ),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.accentPurple))
          : !_hasAccess
              ? _buildChooseFolder()
              : _buildDirectoryList(),
      floatingActionButton: (!_isLoading && _hasAccess)
          ? FloatingActionButton(
              backgroundColor: AppTheme.accentPurple,
              onPressed: () => _showCreateNoteDialog(),
              child: const Icon(Icons.add, color: Colors.white),
            )
          : null,
    );
  }

  void _showCreateNoteDialog() {
    final titleController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: const Text('New Note', style: TextStyle(color: AppTheme.textPrimary)),
        content: TextField(
          controller: titleController,
          style: const TextStyle(color: AppTheme.textPrimary),
          decoration: const InputDecoration(labelText: 'Note Title', labelStyle: TextStyle(color: AppTheme.textSecondary)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: AppTheme.textSecondary)),
          ),
          TextButton(
            onPressed: () async {
              final title = titleController.text.trim();
              if (title.isEmpty) return;
              final dirUri = _pathStack.last.uri;
              await VaultAccess.writeString(dirUri, '$title.md', '# $title\n\n');
              await _loadDirectory();
              await _rebuildIndex();
              if (!context.mounted) return;
              Navigator.pop(context);
              final newEntry = await VaultAccess.child(dirUri, '$title.md');
              if (newEntry != null) _openNote(newEntry);
            },
            child: const Text('Create', style: TextStyle(color: AppTheme.accentPurple)),
          ),
        ],
      ),
    );
  }

  Widget _buildChooseFolder() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.folder_open, size: 64, color: AppTheme.textSecondary),
          const SizedBox(height: 16),
          const Text('No vault folder selected', style: TextStyle(color: AppTheme.textPrimary)),
          const SizedBox(height: 8),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              'Pick the synced Obsidian vault folder on this device. The app only gets access to that one folder.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accentPurple),
            onPressed: _pickFolder,
            child: const Text('Choose Vault Folder'),
          ),
        ],
      ),
    );
  }

  Widget _buildDirectoryList() {
    if (_entities.isEmpty) {
      return const Center(
        child: Text('Folder is empty.', style: TextStyle(color: AppTheme.textSecondary)),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_pathStack.length <= 1) ...[
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 24, 16, 8),
            child: Text(
              'CURRENT FOCUS FLOWS',
              style: TextStyle(
                color: AppTheme.accentPurple,
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 2.0,
              ),
            ),
          ),
          Divider(color: Colors.white.withOpacity(0.05)),
        ],
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _entities.length,
            itemBuilder: (context, index) {
              final entity = _entities[index];
              final isDir = entity.isDir;
              final name = isDir ? entity.name : entity.name.replaceAll('.md', '');

              return ListTile(
                leading: Icon(
                  isDir ? Icons.folder : Icons.description,
                  color: isDir ? AppTheme.statusOrange : AppTheme.accentPurple,
                ),
                title: Text(name, style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold)),
                trailing: isDir ? const Icon(Icons.chevron_right, color: AppTheme.textSecondary) : null,
                onTap: () {
                  if (isDir) {
                    _enterDir(entity);
                  } else {
                    _openNote(entity);
                  }
                },
              );
            },
          ),
        ),
      ],
    );
  }
}
