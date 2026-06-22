import 'package:flutter/material.dart';
import '../services/vault_access.dart';
import '../theme/app_theme.dart';

/// First-launch screen: asks the user to pick the synced Obsidian vault
/// folder via the Storage Access Framework. No broad storage permission is
/// requested — the OS grants persisted access to just this one folder tree.
class VaultSetupScreen extends StatefulWidget {
  final VoidCallback onPicked;

  const VaultSetupScreen({super.key, required this.onPicked});

  @override
  State<VaultSetupScreen> createState() => _VaultSetupScreenState();
}

class _VaultSetupScreenState extends State<VaultSetupScreen> {
  bool _picking = false;
  String? _error;

  Future<void> _pick() async {
    setState(() {
      _picking = true;
      _error = null;
    });
    try {
      final uri = await VaultAccess.pickVaultFolder();
      if (uri == null) {
        setState(() => _picking = false);
        return;
      }
      widget.onPicked();
    } catch (_) {
      setState(() {
        _error = "Couldn't access that folder. Try again.";
        _picking = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.folder_open, size: 72, color: AppTheme.accentPurple),
              const SizedBox(height: 24),
              const Text(
                'WELCOME TO MY OS',
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Pick the synced Obsidian vault folder on this device '
                '(the one Syncthing keeps up to date). MY OS only gets '
                'access to that one folder — no broad storage permission.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 14, height: 1.4),
              ),
              const SizedBox(height: 32),
              if (_error != null) ...[
                Text(_error!, style: const TextStyle(color: AppTheme.statusRed)),
                const SizedBox(height: 16),
              ],
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.accentPurple,
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                ),
                onPressed: _picking ? null : _pick,
                child: _picking
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Choose Vault Folder'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
