import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:wallet/l10n/app_localizations.dart';

import '../features/transactions/domain/entities/transaction_entity.dart';
import '../features/transactions/presentation/cubit/transactions_cubit.dart';
import '../pages/transactions_page.dart'
    show showAccountTransferEditorBottomSheet, showTransactionEditorBottomSheet;
import 'swipeable_list_tile.dart';
import 'transaction_delete_dialogs.dart';

DateTime _calendarDayLocal(DateTime utcOrLocal) {
  final l = utcOrLocal.toLocal();
  return DateTime(l.year, l.month, l.day);
}

sealed class _DashGroupedRow {
  const _DashGroupedRow();
}

final class _DashDayMarker extends _DashGroupedRow {
  const _DashDayMarker(this.day);
  final DateTime day;
}

final class _DashTxMarker extends _DashGroupedRow {
  const _DashTxMarker(this.transaction);
  final TransactionEntity transaction;
}

final class _DashTransferPairMarker extends _DashGroupedRow {
  const _DashTransferPairMarker({required this.source, required this.target});
  final TransactionEntity source;
  final TransactionEntity target;
}

List<_DashGroupedRow> _groupTransactionsByDay(List<TransactionEntity> list) {
  final byDay = <DateTime, List<TransactionEntity>>{};
  for (final t in list) {
    final k = _calendarDayLocal(t.transactedAt);
    byDay.putIfAbsent(k, () => []).add(t);
  }
  final days = byDay.keys.toList()..sort((a, b) => b.compareTo(a));
  for (final d in days) {
    byDay[d]!.sort((a, b) => b.transactedAt.compareTo(a.transactedAt));
  }

  final entries = <_DashGroupedRow>[];
  for (final d in days) {
    entries.add(_DashDayMarker(d));
    final dayList = byDay[d]!;
    final byGroup = <String, List<TransactionEntity>>{};
    for (final t in dayList) {
      final g = t.transactionGroupId;
      if (g != null && g.isNotEmpty) {
        byGroup.putIfAbsent(g, () => []).add(t);
      }
    }
    final usedIds = <String>{};
    for (final t in dayList) {
      final gid = t.transactionGroupId;
      if (gid == null || gid.isEmpty) {
        entries.add(_DashTxMarker(t));
        continue;
      }
      if (usedIds.contains(t.id)) continue;
      final peers = byGroup[gid]!;
      if (peers.length == 2) {
        TransactionEntity? src;
        TransactionEntity? tgt;
        for (final p in peers) {
          if (p.value < 0) src = p;
          if (p.value > 0) tgt = p;
        }
        if (src != null &&
            tgt != null &&
            (src.value.abs() - tgt.value.abs()).abs() < 0.0001) {
          entries.add(_DashTransferPairMarker(source: src, target: tgt));
          usedIds.add(src.id);
          usedIds.add(tgt.id);
          continue;
        }
      }
      entries.add(_DashTxMarker(t));
    }
  }
  return entries;
}

List<String> _relationNames(TransactionEntity t) => [
  if (t.accountName?.isNotEmpty == true) t.accountName!,
  if (t.cardName?.isNotEmpty == true) t.cardName!,
  if (t.categoryName?.isNotEmpty == true) t.categoryName!,
  if (t.tagName?.isNotEmpty == true) t.tagName!,
];

/// Grouped month transactions for the dashboard (same grouping as the transactions page).
class DashboardMonthTransactionsList extends StatelessWidget {
  const DashboardMonthTransactionsList({
    super.key,
    required this.l10n,
    required this.transactions,
    required this.visibleMonth,
  });

  final AppLocalizations l10n;
  final List<TransactionEntity> transactions;
  final DateTime visibleMonth;

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

    final rows = _groupTransactionsByDay(transactions);
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
            _DashDayMarker(:final day) => Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  DateFormat('yyyy-MM-dd').format(day),
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            _DashTxMarker(:final transaction) => _DashboardTxListTile(
              transaction: transaction,
              l10n: l10n,
            ),
            _DashTransferPairMarker(:final source, :final target) =>
              _DashboardTransferListTile(
                source: source,
                target: target,
                l10n: l10n,
              ),
          },
      ],
    );
  }
}

class _DashboardTxListTile extends StatelessWidget {
  const _DashboardTxListTile({required this.transaction, required this.l10n});

  final TransactionEntity transaction;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<TransactionsCubit>();
    final theme = Theme.of(context);
    final locale = Localizations.localeOf(context);
    final weighted = transaction.value * transaction.percentage / 100.0;
    final relations = _relationNames(transaction);
    final desc = transaction.description?.isNotEmpty == true
        ? transaction.description!
        : l10n.none;
    final sub = relations.isNotEmpty ? relations.join(' · ') : null;

    Color amountColor() {
      if (weighted > 0) return const Color(0xFF1B8736);
      if (weighted < 0) return theme.colorScheme.error;
      return theme.colorScheme.onSurfaceVariant;
    }

    void openEdit() {
      showTransactionEditorBottomSheet(
        context,
        l10n: l10n,
        cubit: cubit,
        transaction: transaction,
      );
    }

    Widget tile = SwipeableListTile(
      itemKey: transaction.id,
      title: Text(desc, maxLines: 2, overflow: TextOverflow.ellipsis),
      subtitle: sub != null
          ? Text(sub, maxLines: 2, overflow: TextOverflow.ellipsis)
          : Text(
              DateFormat.Hm(
                locale.toString(),
              ).format(transaction.transactedAt.toLocal()),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            l10n.transactionAmountValue(weighted.toStringAsFixed(2)),
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: amountColor(),
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          if (sub != null)
            Text(
              DateFormat.Hm(
                locale.toString(),
              ).format(transaction.transactedAt.toLocal()),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
        ],
      ),
      onEdit: openEdit,
      confirmDelete: () => confirmDeleteTransactionDialog(context, l10n),
      onDelete: () => cubit.delete(id: transaction.id),
    );

    if (transaction.ignore) {
      tile = Opacity(opacity: 0.52, child: tile);
      tile = Tooltip(message: l10n.transactionIgnoredBadge, child: tile);
    }
    return tile;
  }
}

class _DashboardTransferListTile extends StatelessWidget {
  const _DashboardTransferListTile({
    required this.source,
    required this.target,
    required this.l10n,
  });

  final TransactionEntity source;
  final TransactionEntity target;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<TransactionsCubit>();
    final theme = Theme.of(context);
    final locale = Localizations.localeOf(context);
    String payLabel(TransactionEntity t) => t.accountName ?? t.cardName ?? '—';
    final amountStr = l10n.transactionAmountValue(
      target.value.toStringAsFixed(2),
    );
    final timeStr = DateFormat.Hm(
      locale.toString(),
    ).format(source.transactedAt.toLocal());
    final gid = source.transactionGroupId;
    final pairKey = gid != null && gid.isNotEmpty
        ? 'pair_$gid'
        : '${source.id}|${target.id}';

    void openEdit() {
      showAccountTransferEditorBottomSheet(
        context,
        l10n: l10n,
        editingSource: source,
        editingTarget: target,
      );
    }

    Widget tile = SwipeableListTile(
      itemKey: pairKey,
      leading: Icon(
        Icons.swap_vert_rounded,
        color: theme.colorScheme.onSurfaceVariant,
      ),
      title: Text(
        payLabel(target),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            payLabel(source),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          Text(
            timeStr,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
      trailing: Text(
        amountStr,
        style: theme.textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.w700,
          color: theme.colorScheme.onSurfaceVariant,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
      onEdit: openEdit,
      confirmDelete: () => confirmDeleteTransferPairDialog(context, l10n),
      onDelete: () => cubit.deleteMany([source.id, target.id]),
    );

    if (source.ignore || target.ignore) {
      tile = Opacity(opacity: 0.52, child: tile);
      tile = Tooltip(message: l10n.transactionIgnoredBadge, child: tile);
    }
    return tile;
  }
}
