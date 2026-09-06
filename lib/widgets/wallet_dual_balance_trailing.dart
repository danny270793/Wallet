import 'package:flutter/material.dart';
import 'package:wallet/l10n/app_localizations.dart';

import 'wallet_bottom_bar_insets.dart';

Color walletListBalanceColor(ThemeData theme, double v) {
  if (v > 0) return const Color(0xFF1B8736);
  if (v < 0) return theme.colorScheme.error;
  return theme.colorScheme.onSurface;
}

/// Trailing amount for account/card rows (sum of transaction `value`, full amounts).
class WalletListBalanceAmount extends StatelessWidget {
  const WalletListBalanceAmount({
    super.key,
    required this.l10n,
    required this.balance,
  });

  final AppLocalizations l10n;
  final double balance;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final s = balance.toStringAsFixed(2);
    return Text(
      l10n.transactionAmountValue(s),
      style: TextStyle(
        fontWeight: FontWeight.w600,
        color: walletListBalanceColor(theme, balance),
      ),
    );
  }
}

/// Pinned footer: sum of [balance] across all accounts or cards.
class WalletListBalanceTotalBar extends StatelessWidget {
  const WalletListBalanceTotalBar({
    super.key,
    required this.l10n,
    required this.total,
  });

  final AppLocalizations l10n;
  final double total;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final s = total.toStringAsFixed(2);
    return Material(
      color: theme.colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: EdgeInsets.only(
          bottom: walletBottomBarExtraBottomInset(context),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      l10n.transactionAmountValue(s),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 18,
                        height: 1.2,
                        color: walletListBalanceColor(theme, total),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      l10n.listBalanceTotalLabel,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
