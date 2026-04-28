import 'package:flutter/material.dart';
import 'package:wallet/l10n/app_localizations.dart';

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

  static Color _colorForAmount(ThemeData theme, double v) {
    if (v > 0) return const Color(0xFF1B8736);
    if (v < 0) return theme.colorScheme.error;
    return theme.colorScheme.onSurface;
  }

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
            color: _colorForAmount(theme, balanceWeighted),
          ),
        ),
        Text(
          l10n.listBalanceCountedLine(l10n.transactionAmountValue(c)),
          style: TextStyle(
            fontWeight: FontWeight.w500,
            fontSize: 12,
            height: 1.15,
            color: _colorForAmount(theme, balanceCounted),
          ),
        ),
      ],
    );
  }
}
