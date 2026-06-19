import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:my_os/providers/dashboard_provider.dart';
import 'package:my_os/widgets/home/todos_widget.dart';
import 'package:my_os/widgets/home/financial_goals_widget.dart';

void main() {
  Future<void> pumpOnNarrowScreen(WidgetTester tester, Widget child) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(MaterialApp(home: Scaffold(body: child)));
    await tester.pump();
  }

  testWidgets('TodosWidget does not overflow on a narrow screen', (tester) async {
    await pumpOnNarrowScreen(tester, const TodosWidget());
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
}
