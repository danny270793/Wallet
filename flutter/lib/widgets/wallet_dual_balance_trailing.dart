import 'package:flutter/material.dart';
import 'package:wallet/l10n/app_localizations.dart';

Color walletListBalanceColor(ThemeData theme, double v) {
  if (v > 0) return const Color(0xFF1B8736);
  if (v < 0) return theme.colorScheme.error;
  return theme.colorScheme.onSurface;
}

/// Two-line trailing: weighted (value × %/100) and counted (excluding ignored transactions).
class WalletDualBalanceTrailing extends StatelessWidget {
  const WalletDualBalanceTrailing({
    super.key,
    required this.l10n,
    required this.balanceWeighted,
    required this.balanceCounted,
  });

  final AppLocalizations l10n;
  final double balanceWeighted;
  final double balanceCounted;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final w = balanceWeighted.toStringAsFixed(2);
    final c = balanceCounted.toStringAsFixed(2);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          l10n.listBalanceWeightedLine(l10n.transactionAmountValue(w)),
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 13,
            height: 1.15,
            color: walletListBalanceColor(theme, balanceWeighted),
          ),
        ),
        Text(
          l10n.listBalanceCountedLine(l10n.transactionAmountValue(c)),
          style: TextStyle(
            fontWeight: FontWeight.w500,
            fontSize: 12,
            height: 1.15,
            color: walletListBalanceColor(theme, balanceCounted),
          ),
        ),
      ],
    );
  }
}

/// Footer row: sums of weighted and counted balances across all items in the list.
class WalletDualBalanceListFooter extends StatelessWidget {
  const WalletDualBalanceListFooter({
    super.key,
    required this.l10n,
    required this.totalWeighted,
    required this.totalCounted,
  });

  final AppLocalizations l10n;
  final double totalWeighted;
  final double totalCounted;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final w = totalWeighted.toStringAsFixed(2);
    final c = totalCounted.toStringAsFixed(2);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Divider(height: 1, thickness: 1, color: theme.dividerColor),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Align(
            alignment: Alignment.centerRight,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  l10n.listBalanceTotalWeightedLine(l10n.transactionAmountValue(w)),
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    height: 1.15,
                    color: walletListBalanceColor(theme, totalWeighted),
                  ),
                ),
                Text(
                  l10n.listBalanceTotalCountedLine(l10n.transactionAmountValue(c)),
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 12,
                    height: 1.15,
                    color: walletListBalanceColor(theme, totalCounted),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
