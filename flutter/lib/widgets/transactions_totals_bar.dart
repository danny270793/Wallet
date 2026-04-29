import 'package:flutter/material.dart';
import 'package:wallet/l10n/app_localizations.dart';

import 'wallet_dual_balance_trailing.dart';

/// Bottom summary: income (sum of positive amounts), outcome (sum of absolute negatives),
/// net balance. Transfer legs ([TransactionEntity.isAccountTransferLeg]) are not included upstream.
/// [onDoubleTap] toggles including vs excluding ignored transactions.
class TransactionsTotalsBar extends StatelessWidget {
  const TransactionsTotalsBar({
    super.key,
    required this.l10n,
    required this.income,
    required this.outcome,
    required this.balance,
    this.primarySubtitle,
    this.secondaryIncome,
    this.secondaryOutcome,
    this.secondaryBalance,
    this.secondarySubtitle,
    this.onDoubleTap,
  });

  final AppLocalizations l10n;
  final double income;
  final double outcome;
  final double balance;
  final String? primarySubtitle;
  final double? secondaryIncome;
  final double? secondaryOutcome;
  final double? secondaryBalance;
  final String? secondarySubtitle;
  final VoidCallback? onDoubleTap;

  bool get _hasSecondary =>
      secondaryIncome != null &&
      secondaryOutcome != null &&
      secondaryBalance != null;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    Widget row(double inc, double out, double bal, {required bool compact}) {
      final amountStyle = compact
          ? theme.textTheme.bodyLarge?.copyWith(
              fontWeight: FontWeight.w700,
              height: 1.2,
              fontFeatures: const [FontFeature.tabularFigures()],
            )
          : theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              height: 1.2,
              fontFeatures: const [FontFeature.tabularFigures()],
            );
      final labelStyle = theme.textTheme.labelMedium?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
        fontWeight: FontWeight.w500,
      );

      Widget column(String amount, String label, Color amountColor) {
        return Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                amount,
                textAlign: TextAlign.center,
                style: amountStyle?.copyWith(color: amountColor),
              ),
              const SizedBox(height: 2),
              Text(label, textAlign: TextAlign.center, style: labelStyle),
            ],
          ),
        );
      }

      final incStr = l10n.transactionAmountValue(inc.toStringAsFixed(2));
      final outStr = l10n.transactionAmountValue(out.toStringAsFixed(2));
      final balStr = l10n.transactionAmountValue(bal.toStringAsFixed(2));

      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          column(incStr, l10n.transactionsTotalIncome, const Color(0xFF1B8736)),
          column(
            outStr,
            l10n.transactionsTotalOutcome,
            theme.colorScheme.error,
          ),
          column(
            balStr,
            l10n.transactionsTotalBalance,
            walletListBalanceColor(theme, bal),
          ),
        ],
      );
    }

    return GestureDetector(
      onDoubleTap: onDoubleTap,
      behavior: HitTestBehavior.opaque,
      child: Material(
        color: theme.colorScheme.surfaceContainerHighest,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 10, 8, 10),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (primarySubtitle != null) ...[
                    Text(
                      primarySubtitle!,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                  row(income, outcome, balance, compact: false),
                  if (_hasSecondary) ...[
                    Divider(
                      height: 20,
                      thickness: 1,
                      color: theme.dividerColor,
                    ),
                    if (secondarySubtitle != null) ...[
                      Text(
                        secondarySubtitle!,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                    row(
                      secondaryIncome!,
                      secondaryOutcome!,
                      secondaryBalance!,
                      compact: true,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
