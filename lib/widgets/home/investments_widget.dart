import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/dashboard_provider.dart';
import '../../theme/app_theme.dart';

class InvestmentsWidget extends StatelessWidget {
  const InvestmentsWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<DashboardProvider>(
      builder: (context, provider, child) {
        if (provider.investments.isEmpty) return const SizedBox.shrink();

        double totalUnrealizedPL = 0;
        for (var inv in provider.investments) {
          totalUnrealizedPL += inv.unrealizedPL;
        }

        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.05)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'PORTFOLIO',
                    style: TextStyle(
                      color: AppTheme.accentPurple,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 2.0,
                    ),
                  ),
                  if (provider.isFetchingInvestments)
                    const SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppTheme.accentPurple,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                'Total P/L: ${totalUnrealizedPL >= 0 ? '+' : ''}${totalUnrealizedPL.toStringAsFixed(2)}',
                style: TextStyle(
                  color: totalUnrealizedPL >= 0 ? AppTheme.statusGreen : AppTheme.statusRed,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              ...provider.investments.map((inv) => _buildHoldingRow(context, inv, provider)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHoldingRow(BuildContext context, Investment inv, DashboardProvider provider) {
    final bool isUp = inv.dailyChange >= 0;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: GestureDetector(
        onTap: () => _showEditDialog(context, inv, provider),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            SizedBox(
              width: 50,
              child: Text(
                inv.symbol,
                style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: Text(
                  '\$${inv.currentPrice.toStringAsFixed(2)}',
                  style: const TextStyle(color: AppTheme.textPrimary, fontSize: 16),
                  textAlign: TextAlign.right,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: isUp ? AppTheme.statusGreen.withOpacity(0.1) : AppTheme.statusRed.withOpacity(0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                '${isUp ? '+' : ''}${inv.dailyChangePercent.toStringAsFixed(2)}%',
                style: TextStyle(
                  color: isUp ? AppTheme.statusGreen : AppTheme.statusRed,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditDialog(BuildContext context, Investment inv, DashboardProvider provider) {
    final qtyController = TextEditingController(text: inv.quantity.toString());
    final costController = TextEditingController(text: inv.costBasis.toString());

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppTheme.surface,
          title: Text('Edit ${inv.symbol}', style: const TextStyle(color: AppTheme.textPrimary)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: qtyController,
                decoration: const InputDecoration(labelText: 'Quantity', labelStyle: TextStyle(color: AppTheme.textSecondary)),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                style: const TextStyle(color: AppTheme.textPrimary),
              ),
              TextField(
                controller: costController,
                decoration: const InputDecoration(labelText: 'Cost Basis', labelStyle: TextStyle(color: AppTheme.textSecondary)),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                style: const TextStyle(color: AppTheme.textPrimary),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: AppTheme.textSecondary)),
            ),
            TextButton(
              onPressed: () {
                final newQty = double.tryParse(qtyController.text) ?? inv.quantity;
                final newCost = double.tryParse(costController.text) ?? inv.costBasis;
                int index = provider.investments.indexOf(inv);
                provider.updateInvestment(index, newQty, newCost);
                Navigator.pop(context);
              },
              child: const Text('Save', style: TextStyle(color: AppTheme.accentPurple)),
            ),
          ],
        );
      },
    );
  }
}
