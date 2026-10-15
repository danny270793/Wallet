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

/// Trailing amounts for a card row: regular purchases and payments on top,
/// deferred installments below.
class WalletCardBalanceAmounts extends StatelessWidget {
  const WalletCardBalanceAmounts({
    super.key,
    required this.l10n,
    required this.balance,
    required this.creditBalance,
  });

  final AppLocalizations l10n;
  final double balance;
  final double creditBalance;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    Widget amount(double v, {required bool emphasized}) {
      final base = emphasized
          ? theme.textTheme.bodyMedium
          : theme.textTheme.bodySmall;
      return Text(
        l10n.transactionAmountValue(v.toStringAsFixed(2)),
        style: base?.copyWith(
          fontWeight: emphasized ? FontWeight.w600 : FontWeight.w500,
          color: walletListBalanceColor(theme, v),
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        amount(balance, emphasized: true),
        const SizedBox(height: 2),
        amount(creditBalance, emphasized: false),
      ],
    );
  }
}

/// Pinned footer: non-credits, credits, and their sum across all cards.
class WalletCardTotalsBar extends StatelessWidget {
  const WalletCardTotalsBar({
    super.key,
    required this.l10n,
    required this.nonCredits,
    required this.credits,
  });

  final AppLocalizations l10n;
  final double nonCredits;
  final double credits;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final total = nonCredits + credits;
    final amountStyle = theme.textTheme.titleMedium?.copyWith(
      fontWeight: FontWeight.w700,
      height: 1.2,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    final labelStyle = theme.textTheme.labelMedium?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
      fontWeight: FontWeight.w500,
    );

    Widget column(double value, String label) {
      return Expanded(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              l10n.transactionAmountValue(value.toStringAsFixed(2)),
              textAlign: TextAlign.center,
              style: amountStyle?.copyWith(
                color: walletListBalanceColor(theme, value),
              ),
            ),
            const SizedBox(height: 2),
            Text(label, textAlign: TextAlign.center, style: labelStyle),
          ],
        ),
      );
    }

    return Material(
      color: theme.colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: EdgeInsets.only(
          bottom: walletBottomBarExtraBottomInset(context),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 10, 8, 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              column(nonCredits, l10n.cardsTotalNonCredits),
              column(credits, l10n.cardsTotalCredits),
              column(total, l10n.listBalanceTotalLabel),
            ],
          ),
        ),
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
