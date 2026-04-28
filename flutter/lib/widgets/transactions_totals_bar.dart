import 'package:flutter/material.dart';
import 'package:wallet/l10n/app_localizations.dart';

import 'wallet_dual_balance_trailing.dart';

/// Bottom summary: income (sum of positive values), outcome (sum of absolute negatives), net balance.
class TransactionsTotalsBar extends StatelessWidget {
  const TransactionsTotalsBar({
    super.key,
    required this.l10n,
    required this.income,
    required this.outcome,
    required this.balance,
  });

  final AppLocalizations l10n;
  final double income;
  final double outcome;
  final double balance;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final incomeStr = l10n.transactionAmountValue(income.toStringAsFixed(2));
    final outcomeStr = l10n.transactionAmountValue(outcome.toStringAsFixed(2));
    final balanceStr = l10n.transactionAmountValue(balance.toStringAsFixed(2));

    Widget column(String amount, String label, Color amountColor) {
      return Expanded(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              amount,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                height: 1.2,
                color: amountColor,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              textAlign: TextAlign.center,
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    return Material(
      color: theme.colorScheme.surfaceContainerHighest,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                column(
                  incomeStr,
                  l10n.transactionsTotalIncome,
                  const Color(0xFF1B8736),
                ),
                column(
                  outcomeStr,
                  l10n.transactionsTotalOutcome,
                  theme.colorScheme.error,
                ),
                column(
                  balanceStr,
                  l10n.transactionsTotalBalance,
                  walletListBalanceColor(theme, balance),
                ),
              ],
            ),
          ),
          const SizedBox(height: 2),
        ],
      ),
    );
  }
}
