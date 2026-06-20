import 'dart:io';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../constants/vault_paths.dart';
import '../services/obsidian_vault.dart';
import '../theme/app_theme.dart';
import 'note_viewer_screen.dart';
import 'vault_tags_screen.dart';

class NotesScreen extends StatefulWidget {
  const NotesScreen({super.key});

  @override
  State<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends State<NotesScreen> {
  final String vaultPath = vaultRootPath;
  late Directory _currentDir;
  List<FileSystemEntity> _entities = [];
  final VaultIndex _index = VaultIndex();
  bool _hasPermission = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _currentDir = Directory(vaultPath);
    _requestPermissions();
  }

  Future<void> _requestPermissions() async {
    if (await Permission.manageExternalStorage.request().isGranted ||
        await Permission.storage.request().isGranted) {
      setState(() => _hasPermission = true);
      _loadDirectory();
      _rebuildIndex();
    } else {
      setState(() {
        _hasPermission = false;
        _isLoading = false;
      });
    }
  }

  Future<void> _rebuildIndex() async {
    await _index.build(Directory(vaultPath));
  }

  void _loadDirectory() {
    if (_currentDir.existsSync()) {
      final List<FileSystemEntity> items = _currentDir.listSync().where((e) {
        if (e is Directory) return !e.path.replaceAll('\\', '/').split('/').last.startsWith('.');
        if (e is File) return e.path.endsWith('.md');
        return false;
      }).toList();
      
      // Sort directories first, then files
      items.sort((a, b) {
        if (a is Directory && b is File) return -1;
        if (a is File && b is Directory) return 1;
        return a.path.compareTo(b.path);
      });

      setState(() {
        _entities = items;
        _isLoading = false;
      });
    } else {
      setState(() {
        _entities = [];
        _isLoading = false;
      });
    }
  }

  void _openNote(File file) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => NoteViewerScreen(file: file, index: _index)),
    );
  }

  void _goUp() {
    if (_currentDir.path != vaultPath) {
      setState(() {
        _currentDir = _currentDir.parent;
      });
      _loadDirectory();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isRoot = _currentDir.path == vaultPath;

    return Scaffold(
      appBar: AppBar(
        leading: !isRoot
            ? IconButton(icon: const Icon(Icons.arrow_back), onPressed: _goUp)
            : null,
        title: Text(isRoot ? 'OBSIDIAN VAULT' : _currentDir.path.replaceAll('\\', '/').split('/').last),
        actions: [
          if (_hasPermission)
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
          : !_hasPermission
              ? _buildPermissionError()
              : _buildDirectoryList(),
      floatingActionButton: (!_isLoading && _hasPermission)
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
              if (title.isNotEmpty) {
                if (!_currentDir.existsSync()) {
                  _currentDir.createSync(recursive: true);
                }
                final newFile = File('\${_currentDir.path}/$title.md');
                await newFile.writeAsString('# $title\n\n');
                _loadDirectory();
                await _rebuildIndex();
                Navigator.pop(context);
                _openNote(newFile);
              }
            },
            child: const Text('Create', style: TextStyle(color: AppTheme.accentPurple)),
          ),
        ],
      ),
    );
  }

  Widget _buildPermissionError() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.folder_off, size: 64, color: AppTheme.textSecondary),
          const SizedBox(height: 16),
          const Text('Storage Permission Required', style: TextStyle(color: AppTheme.textPrimary)),
          const SizedBox(height: 16),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accentPurple),
            onPressed: () => openAppSettings(),
            child: const Text('Open Settings'),
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
        if (_currentDir.path == vaultPath) ...[
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
              final isDir = entity is Directory;
              final name = entity.path.replaceAll('\\', '/').split('/').last.replaceAll('.md', '');
              
              return ListTile(
                leading: Icon(
                  isDir ? Icons.folder : Icons.description, 
                  color: isDir ? AppTheme.statusOrange : AppTheme.accentPurple,
                ),
                title: Text(name, style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold)),
                trailing: isDir ? const Icon(Icons.chevron_right, color: AppTheme.textSecondary) : null,
                onTap: () {
                  if (isDir) {
                    setState(() {
                      _currentDir = entity;
                    });
                    _loadDirectory();
                  } else {
                    _openNote(entity as File);
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
