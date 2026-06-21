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
import 'screens/academics_screen.dart';
import 'screens/todos_screen.dart';
import 'screens/inbox_screen.dart';
import 'screens/more_screen.dart';

void main() {
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
      home: const MainShell(),
    );
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
    const TodosScreen(),
    const InboxScreen(),
    const AcademicsScreen(),
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
            icon: Icon(Icons.school_outlined),
            activeIcon: Icon(Icons.school),
            label: 'Academics',
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
