import 'package:flutter/material.dart';
import 'package:wallet/l10n/app_localizations.dart';

import '../features/transactions/domain/entities/transaction_entity.dart';
import 'transaction_month_totals.dart';
import 'wallet_bottom_bar_insets.dart';
import 'wallet_dual_balance_trailing.dart';
import 'wallet_totals_pager_dots.dart';

/// Bottom summary: income (sum of positive amounts), outcome (sum of absolute negatives),
/// net balance. Transfer legs ([TransactionEntity.isAccountTransferLeg]) are not included upstream.
/// When [totalsDotsCount] is at least 2, shows page-indicator dots beneath the Income / Outcome / Balance row;
/// highlight follows [totalsDotsSelectedIndex] (typically the same index as totals mode).
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
    this.totalsDotsCount = 0,
    this.totalsDotsSelectedIndex = 0,
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

  /// When ≥ 2, shows pager dots under Income / Outcome / Balance.
  /// Index [totalsDotsSelectedIndex] is clamped to `[0, totalsDotsCount)`.
  final int totalsDotsCount;
  final int totalsDotsSelectedIndex;

  bool get _hasSecondary =>
      secondaryIncome != null &&
      secondaryOutcome != null &&
      secondaryBalance != null;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: theme.colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: EdgeInsets.only(
          bottom: walletBottomBarExtraBottomInset(context),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 10, 8, 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _TotalsBarPage(
                l10n: l10n,
                income: income,
                outcome: outcome,
                balance: balance,
                primarySubtitle: primarySubtitle,
                secondaryIncome: secondaryIncome,
                secondaryOutcome: secondaryOutcome,
                secondaryBalance: secondaryBalance,
                secondarySubtitle: secondarySubtitle,
                hasSecondary: _hasSecondary,
              ),
              if (totalsDotsCount >= 2) ...[
                const SizedBox(height: 10),
                WalletTotalsPagerDots(
                  count: totalsDotsCount,
                  selectedIndex: totalsDotsSelectedIndex,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _TotalsBarPage extends StatelessWidget {
  const _TotalsBarPage({
    required this.l10n,
    required this.income,
    required this.outcome,
    required this.balance,
    required this.primarySubtitle,
    required this.secondaryIncome,
    required this.secondaryOutcome,
    required this.secondaryBalance,
    required this.secondarySubtitle,
    required this.hasSecondary,
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
  final bool hasSecondary;

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

    return Column(
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
        if (hasSecondary) ...[
          Divider(height: 20, thickness: 1, color: theme.dividerColor),
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
    );
  }
}

/// Same five-mode totals bar as the transactions list: drag horizontally
/// through weighted → weighted excluding credit → weighted excluding ignored → not weighted → not weighted excluding ignored.
class TransactionsTotalsBarHost extends StatefulWidget {
  const TransactionsTotalsBarHost({
    super.key,
    required this.l10n,
    required this.transactions,
  });

  final AppLocalizations l10n;
  final List<TransactionEntity> transactions;

  @override
  State<TransactionsTotalsBarHost> createState() =>
      _TransactionsTotalsBarHostState();
}

class _TransactionsTotalsBarHostState extends State<TransactionsTotalsBarHost> {
  static const _kTotalsModeCount = 5;

  final _controller = PageController();
  int _page = 0;

  /// Page order (`_page` 0…4):
  /// * Weighted — `value * percentage / 100` for **all** non–transfer-leg rows (including ignored).
  /// * Weighted excluding credit — weighted for rows without [TransactionEntity.creditId].
  /// * Weighted excluding ignored — weighted formula only for rows with `ignore == false`.
  /// * Not weighted — raw `value` for **all** such rows (including ignored).
  /// * Not weighted excluding ignored — raw `value` only for rows with `ignore == false`.

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final txs = widget.transactions;
    final l10n = widget.l10n;
    final theme = Theme.of(context);
    double weightedAmount(TransactionEntity t) =>
        t.value * t.percentage / 100.0;

    final totalsWeightedAll = transactionMonthTotalsBreakdown(
      txs,
      include: (_) => true,
      amount: weightedAmount,
    );
    final totalsWeightedNoCredit = transactionMonthTotalsBreakdown(
      txs,
      include: (t) => t.creditId == null || t.creditId!.isEmpty,
      amount: weightedAmount,
    );
    final totalsRawValueAll = transactionMonthTotalsBreakdown(
      txs,
      include: (_) => true,
      amount: (t) => t.value,
    );
    final totalsWeightedNonIgnoredOnly = transactionMonthTotalsBreakdown(
      txs,
      include: (t) => !t.ignore,
      amount: weightedAmount,
    );
    final totalsRawValueNonIgnoredOnly = transactionMonthTotalsBreakdown(
      txs,
      include: (t) => !t.ignore,
      amount: (t) => t.value,
    );

    _TotalsBarPage page({
      required String subtitle,
      required ({double income, double outcome, double balance}) totals,
    }) {
      return _TotalsBarPage(
        l10n: l10n,
        income: totals.income,
        outcome: totals.outcome,
        balance: totals.balance,
        primarySubtitle: subtitle,
        secondaryIncome: null,
        secondaryOutcome: null,
        secondaryBalance: null,
        secondarySubtitle: null,
        hasSecondary: false,
      );
    }

    final pages = <Widget>[
      page(
        subtitle: l10n.transactionsTotalsWeightedHint,
        totals: totalsWeightedAll,
      ),
      page(
        subtitle: l10n.transactionsTotalsWeightedExcludingCreditHint,
        totals: totalsWeightedNoCredit,
      ),
      page(
        subtitle: l10n.transactionsTotalsWeightedExcludingIgnoredHint,
        totals: totalsWeightedNonIgnoredOnly,
      ),
      page(
        subtitle: l10n.transactionsTotalsNotWeightedHint,
        totals: totalsRawValueAll,
      ),
      page(
        subtitle: l10n.transactionsTotalsNotWeightedExcludingIgnoredHint,
        totals: totalsRawValueNonIgnoredOnly,
      ),
    ];

    return Material(
      color: theme.colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: EdgeInsets.only(
          bottom: walletBottomBarExtraBottomInset(context),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 10, 8, 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                children: [
                  for (final p in pages)
                    Opacity(opacity: 0, child: IgnorePointer(child: p)),
                  Positioned.fill(
                    child: PageView(
                      controller: _controller,
                      onPageChanged: (i) => setState(() => _page = i),
                      children: pages,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              WalletTotalsPagerDots(
                count: _kTotalsModeCount,
                selectedIndex: _page,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
