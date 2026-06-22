import 'package:flutter/material.dart';
import '../widgets/home/investments_widget.dart';
import '../widgets/home/financial_goals_widget.dart';

class FinancialScreen extends StatelessWidget {
  const FinancialScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('FINANCIAL')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: const [
            InvestmentsWidget(),
            SizedBox(height: 24),
            FinancialGoalsWidget(),
          ],
        ),
      ),
    );
  }
}
