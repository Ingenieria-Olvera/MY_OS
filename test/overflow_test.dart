import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:my_os/providers/dashboard_provider.dart';
import 'package:my_os/providers/inbox_provider.dart';
import 'package:my_os/providers/todos_provider.dart';
import 'package:my_os/services/inbox_service.dart';
import 'package:my_os/widgets/home/todos_widget.dart';
import 'package:my_os/widgets/home/financial_goals_widget.dart';
import 'package:my_os/screens/inbox_screen.dart';

void main() {
  Future<void> pumpOnNarrowScreen(WidgetTester tester, Widget child, {bool wrapInScaffold = true}) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(MaterialApp(home: wrapInScaffold ? Scaffold(body: child) : child));
    await tester.pump();
  }

  testWidgets('TodosWidget does not overflow on a narrow screen', (tester) async {
    final provider = FakeTodosProvider();
    await pumpOnNarrowScreen(
      tester,
      ChangeNotifierProvider<TodosProvider>.value(
        value: provider,
        child: const TodosWidget(),
      ),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('FinancialGoalsWidget does not overflow with a long goal name', (tester) async {
    final provider = DashboardProvider();
    provider.goals.add(FinancialGoal(
      name: 'Save up for a brand new car down payment fund',
      targetAmount: 10000,
      currentAmount: 2500,
      targetDate: DateTime.now().add(const Duration(days: 200)),
    ));

    await pumpOnNarrowScreen(
      tester,
      ChangeNotifierProvider<DashboardProvider>.value(
        value: provider,
        child: const FinancialGoalsWidget(),
      ),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('InboxScreen does not overflow with long sender/subject text', (tester) async {
    final provider = FakeInboxProvider();
    provider.slackMessages = [
      SlackMessage(
        id: '1',
        source: 'mention',
        channel: 'general',
        sender: 'A Very Long Display Name That Should Be Truncated Cleanly',
        text: 'A very long message body that goes on and on and should wrap or ellipsize instead of overflowing the row',
        timestamp: DateTime.now(),
      ),
    ];
    provider.emails = [
      EmailMessage(
        id: 'a',
        sender: 'someone.with.a.very.long.email.address@example.com',
        subject: 'An extremely long email subject line that must not overflow the list tile',
        snippet: 'A long snippet of the email body preview text that keeps going for a while',
        receivedAt: DateTime.now(),
        labels: const ['IMPORTANT'],
      ),
    ];

    await pumpOnNarrowScreen(
      tester,
      ChangeNotifierProvider<InboxProvider>.value(value: provider, child: const InboxScreen()),
      wrapInScaffold: false,
    );
    expect(tester.takeException(), isNull);

    await tester.tap(find.textContaining('Email'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}

class FakeTodosProvider extends TodosProvider {
  FakeTodosProvider() {
    isLoading = false;
    today = [];
    overarching = [];
  }
  @override
  Future<void> refresh() async {}
  @override
  Future<void> _loadCompletedIds() async {}
}

class FakeInboxProvider extends InboxProvider {
  FakeInboxProvider() {
    isLoading = false;
  }
  @override
  Future<void> refresh() async {}
  @override
  Future<void> _loadReadIds() async {}
}
