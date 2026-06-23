import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/setup_status_service.dart';
import '../theme/app_theme.dart';

/// Lets you list the Google accounts you expect to see digests from
/// (personal/work/school) and shows, per account, whether email/calendar
/// data is actually showing up yet. OAuth consent itself can only happen in
/// a browser on the machine running the Python scrapers (it's a desktop-app
/// flow with a local callback) — this screen can't grant access, only tell
/// you what's missing and point at the fix.
class SetupChecklistScreen extends StatefulWidget {
  const SetupChecklistScreen({super.key});

  @override
  State<SetupChecklistScreen> createState() => _SetupChecklistScreenState();
}

class _SetupChecklistScreenState extends State<SetupChecklistScreen> {
  static const _accountsKey = 'setup_expected_accounts';

  List<String> _expectedAccounts = ['personal'];
  DigestStatus _emailStatus = DigestStatus.empty;
  DigestStatus _calendarStatus = DigestStatus.empty;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList(_accountsKey);
    if (saved != null && saved.isNotEmpty) _expectedAccounts = saved;

    final email = await SetupStatusService.emailStatus();
    final calendar = await SetupStatusService.calendarStatus();
    if (!mounted) return;
    setState(() {
      _emailStatus = email;
      _calendarStatus = calendar;
      _isLoading = false;
    });
  }

  Future<void> _editAccounts() async {
    final controller = TextEditingController(text: _expectedAccounts.join(', '));
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: const Text('Expected accounts', style: TextStyle(color: AppTheme.textPrimary)),
        content: TextField(
          controller: controller,
          style: const TextStyle(color: AppTheme.textPrimary),
          decoration: const InputDecoration(
            hintText: 'personal, work, school',
            hintStyle: TextStyle(color: AppTheme.textSecondary),
            helperText: 'Match the names you used for GOOGLE_ACCOUNTS in .env',
            helperStyle: TextStyle(color: AppTheme.textSecondary),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: AppTheme.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Save', style: TextStyle(color: AppTheme.accentPurple)),
          ),
        ],
      ),
    );
    if (result == null) return;
    final parsed = result.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
    if (parsed.isEmpty) return;
    setState(() => _expectedAccounts = parsed);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_accountsKey, parsed);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('SETUP CHECKLIST'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
          IconButton(icon: const Icon(Icons.edit_outlined), onPressed: _editAccounts),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.accentPurple))
          : RefreshIndicator(
              onRefresh: _load,
              color: AppTheme.accentPurple,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _freshnessTile('Email digest', _emailStatus.generatedAt),
                  _freshnessTile('Calendar digest', _calendarStatus.generatedAt),
                  const SizedBox(height: 16),
                  const Text('Per-account status', style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  for (final account in _expectedAccounts) _accountTile(account),
                  const SizedBox(height: 24),
                  _instructions(),
                ],
              ),
            ),
    );
  }

  Widget _freshnessTile(String title, DateTime? generatedAt) {
    final stale = generatedAt == null || DateTime.now().difference(generatedAt).inHours > 6;
    return ListTile(
      leading: Icon(
        generatedAt == null ? Icons.help_outline : (stale ? Icons.warning_amber_outlined : Icons.check_circle_outline),
        color: generatedAt == null ? AppTheme.textSecondary : (stale ? AppTheme.statusRed : AppTheme.accentPurple),
      ),
      title: Text(title, style: const TextStyle(color: AppTheme.textPrimary)),
      subtitle: Text(
        generatedAt == null ? 'No digest found yet' : 'Last refreshed $generatedAt',
        style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
      ),
    );
  }

  Widget _accountTile(String account) {
    final inEmail = _emailStatus.accountsSeen.contains(account);
    final inCalendar = _calendarStatus.accountsSeen.contains(account);
    final ok = inEmail && inCalendar;
    return ListTile(
      leading: Icon(
        ok ? Icons.check_circle : Icons.error_outline,
        color: ok ? AppTheme.accentPurple : AppTheme.statusRed,
      ),
      title: Text(account, style: const TextStyle(color: AppTheme.textPrimary)),
      subtitle: Text(
        'Email: ${inEmail ? "✓" : "missing"}   Calendar: ${inCalendar ? "✓" : "missing"}',
        style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
      ),
    );
  }

  Widget _instructions() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppTheme.surface, borderRadius: BorderRadius.circular(12)),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('If an account is missing', style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold)),
          SizedBox(height: 8),
          Text(
            'OAuth consent has to happen in a browser on the machine running the '
            'Python scrapers — this app can\'t grant access for you. On that machine:\n\n'
            '1. Add the account\'s email to "Test users" on the OAuth consent screen '
            'in Google Cloud Console (APIs & Services).\n'
            '2. If it\'s a work/school Google Workspace account, its admin may block '
            'unverified third-party apps entirely — ask IT to allow it, or use a '
            'personal Google account instead for that inbox.\n'
            '3. Add the account to GOOGLE_ACCOUNTS / GOOGLE_CREDENTIALS_FILES / '
            'GOOGLE_TOKEN_FILES in python/.env (comma-separated, positionally aligned).\n'
            '4. Run gmail_scraper.py / calendar_scraper.py once by hand to go through '
            'the consent screen for that account; after that it refreshes silently.\n\n'
            'See python/README.md and python/.env.example for the exact variable format.',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
          ),
        ],
      ),
    );
  }
}
