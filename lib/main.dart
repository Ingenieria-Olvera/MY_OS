import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'theme/app_theme.dart';
import 'providers/dashboard_provider.dart';
import 'providers/academics_provider.dart';
import 'providers/inbox_provider.dart';
import 'providers/calendar_provider.dart';
import 'providers/todos_provider.dart';
import 'providers/chat_provider.dart';
import 'screens/dashboard_screen.dart';
import 'screens/chat_screen.dart';
import 'screens/todos_screen.dart';
import 'screens/inbox_screen.dart';
import 'screens/more_screen.dart';
import 'screens/vault_setup_screen.dart';
import 'services/notification_service.dart';
import 'services/vault_access.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NotificationService.init();
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => DashboardProvider()),
        ChangeNotifierProvider(create: (_) => AcademicsProvider()),
        ChangeNotifierProvider(create: (_) => InboxProvider()),
        ChangeNotifierProvider(create: (_) => CalendarProvider()),
        ChangeNotifierProvider(create: (_) => TodosProvider()),
        ChangeNotifierProvider(create: (_) => ChatProvider()),
      ],
      child: const MyOSApp(),
    ),
  );
}

class MyOSApp extends StatelessWidget {
  const MyOSApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MY OS',
      theme: AppTheme.darkTheme,
      debugShowCheckedModeBanner: false,
      home: const VaultGate(),
    );
  }
}

/// Gates the app behind picking a vault folder on first launch. Once a
/// folder is picked (or was already picked in a previous session), shows
/// the normal [MainShell] and kicks off the providers' first refresh +
/// notification scheduling.
class VaultGate extends StatefulWidget {
  const VaultGate({super.key});

  @override
  State<VaultGate> createState() => _VaultGateState();
}

class _VaultGateState extends State<VaultGate> {
  bool? _hasVault;

  @override
  void initState() {
    super.initState();
    VaultAccess.hasVaultAccess().then((has) {
      if (!mounted) return;
      setState(() => _hasVault = has);
      if (has) _refreshAndScheduleNotifications();
    });
  }

  void _refreshAndScheduleNotifications() {
    final calendar = context.read<CalendarProvider>();
    final todos = context.read<TodosProvider>();
    final inbox = context.read<InboxProvider>();
    Future.wait([calendar.refresh(), todos.refresh(), inbox.refresh()]).then((_) {
      NotificationService.scheduleAll(
        todos: todos.pendingToday + todos.pendingOverarching,
        events: calendar.events,
        emails: inbox.emails,
      );
    });
  }

  void _onVaultPicked() {
    setState(() => _hasVault = true);
    _refreshAndScheduleNotifications();
  }

  @override
  Widget build(BuildContext context) {
    if (_hasVault == null) {
      return const Scaffold(
        backgroundColor: AppTheme.background,
        body: Center(child: CircularProgressIndicator(color: AppTheme.accentPurple)),
      );
    }
    if (_hasVault == false) {
      return VaultSetupScreen(onPicked: _onVaultPicked);
    }
    return const MainShell();
  }
}

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    const DashboardScreen(),
    const ChatScreen(),
    const TodosScreen(),
    const InboxScreen(),
    const MoreScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.speed_outlined),
            activeIcon: Icon(Icons.speed),
            label: 'Today',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.auto_awesome_outlined),
            activeIcon: Icon(Icons.auto_awesome),
            label: 'Secretary',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.check_circle_outline),
            activeIcon: Icon(Icons.check_circle),
            label: 'Todos',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.inbox_outlined),
            activeIcon: Icon(Icons.inbox),
            label: 'Inbox',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.more_horiz),
            activeIcon: Icon(Icons.more_horiz),
            label: 'More',
          ),
        ],
      ),
    );
  }
}
