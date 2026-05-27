import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:wallet/l10n/app_localizations.dart';

import '../features/transactions/domain/entities/transaction_entity.dart';
import 'grouped_transactions_list.dart';

/// Grouped month transactions for the dashboard — reuses the same row widgets as [/transactions].
class DashboardMonthTransactionsList extends StatelessWidget {
  const DashboardMonthTransactionsList({
    super.key,
    required this.l10n,
    required this.transactions,
    required this.visibleMonth,
    required this.useWeightedAmounts,
  });

  final AppLocalizations l10n;
  final List<TransactionEntity> transactions;
  final DateTime visibleMonth;
  final bool useWeightedAmounts;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (transactions.isEmpty) {
      final locale = Localizations.localeOf(context).toString();
      final monthYear = DateFormat.yMMMM(locale).format(visibleMonth);
      return Padding(
        padding: const EdgeInsets.fromLTRB(8, 24, 8, 16),
        child: Text(
          l10n.noTransactionsInMonth(monthYear),
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }

    final monthStart = DateTime(visibleMonth.year, visibleMonth.month, 1);
    final monthEndExclusive = DateTime(
      visibleMonth.year,
      visibleMonth.month + 1,
      1,
    );
    final now = DateTime.now();
    final tomorrow = DateTime(now.year, now.month, now.day + 1);
    final endExclusive = monthEndExclusive.isBefore(tomorrow)
        ? monthEndExclusive
        : tomorrow;
    final fillRange = endExclusive.isAfter(monthStart)
        ? (start: monthStart, endExclusive: endExclusive)
        : null;
    final rows = groupedTransactionsForList(
      transactions,
      fillRange: fillRange,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 20, 8, 8),
          child: Text(
            l10n.monthlyDashboardTransactionsListTitle,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        for (final row in rows)
          switch (row) {
            GroupedTxnDayMarker(:final day) => GroupedTxnDayHeader(day: day),
            GroupedTxnEmptyDayMarker() => GroupedTxnEmptyDayLabel(l10n: l10n),
            GroupedTxnTxMarker(:final transaction) => GroupedTxnTransactionTile(
                transaction: transaction,
                l10n: l10n,
                useWeightedAmounts: useWeightedAmounts,
              ),
            GroupedTxnTransferPairMarker(:final source, :final target) =>
              GroupedTxnTransferPairTile(
                source: source,
                target: target,
                l10n: l10n,
              ),
          },
      ],
    );
  }
}
