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

/// Local calendar day (midnight) used as a group key for [transactedAt].
DateTime groupedTxCalendarDayLocal(DateTime utcOrLocal) {
  final l = utcOrLocal.toLocal();
  return DateTime(l.year, l.month, l.day);
}

sealed class GroupedTxnRow {
  const GroupedTxnRow();
}

final class GroupedTxnDayMarker extends GroupedTxnRow {
  const GroupedTxnDayMarker(this.day);
  final DateTime day;
}

final class GroupedTxnTxMarker extends GroupedTxnRow {
  const GroupedTxnTxMarker(this.transaction);
  final TransactionEntity transaction;
}

final class GroupedTxnTransferPairMarker extends GroupedTxnRow {
  const GroupedTxnTransferPairMarker({
    required this.source,
    required this.target,
  });
  final TransactionEntity source;
  final TransactionEntity target;
}

/// Groups by descending day, intra-day descending time; pairs transfers by group id like [transactions_page].
List<GroupedTxnRow> groupedTransactionsForList(List<TransactionEntity> list) {
  final byDay = <DateTime, List<TransactionEntity>>{};
  for (final t in list) {
    final k = groupedTxCalendarDayLocal(t.transactedAt);
    byDay.putIfAbsent(k, () => []).add(t);
  }
  final days = byDay.keys.toList()..sort((a, b) => b.compareTo(a));
  for (final d in days) {
    byDay[d]!.sort((a, b) => b.transactedAt.compareTo(a.transactedAt));
  }

  final entries = <GroupedTxnRow>[];
  for (final d in days) {
    entries.add(GroupedTxnDayMarker(d));
    final dayList = byDay[d]!;
    final byGroup = <String, List<TransactionEntity>>{};
    for (final t in dayList) {
      final g = t.transferGroupId;
      if (g != null && g.isNotEmpty) {
        byGroup.putIfAbsent(g, () => []).add(t);
      }
    }
    final usedIds = <String>{};
    for (final t in dayList) {
      final gid = t.transferGroupId;
      if (gid == null || gid.isEmpty) {
        entries.add(GroupedTxnTxMarker(t));
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
          entries.add(
            GroupedTxnTransferPairMarker(source: src, target: tgt),
          );
          usedIds.add(src.id);
          usedIds.add(tgt.id);
          continue;
        }
      }
      entries.add(GroupedTxnTxMarker(t));
    }
  }
  return entries;
}

class GroupedTxnDayHeader extends StatelessWidget {
  const GroupedTxnDayHeader({super.key, required this.day});

  final DateTime day;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final text = DateFormat('yyyy-MM-dd').format(day);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          text,
          style: theme.textTheme.titleSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class GroupedTxnTransactionTile extends StatelessWidget {
  const GroupedTxnTransactionTile({
    super.key,
    /// When null, taken from [BlocProvider<TransactionsCubit>]. Pass in overlays
    /// (e.g. transaction editor sheet) that are not under page-scoped bloc.
    this.cubit,
    required this.transaction,
    required this.l10n,
    this.useWeightedAmounts = true,
    this.onTap,
  });

  final TransactionsCubit? cubit;
  final TransactionEntity transaction;
  final AppLocalizations l10n;

  /// When true, primary amount is weighted; dashboard follows app toggle. [/transactions] uses true.
  final bool useWeightedAmounts;
  final VoidCallback? onTap;

  List<String> _relationNames(TransactionEntity t) => [
    if (t.categoryName?.isNotEmpty == true) t.categoryName!,
    if (t.accountName?.isNotEmpty == true) t.accountName!,
    if (t.cardName?.isNotEmpty == true) t.cardName!,
    if (t.tagName?.isNotEmpty == true) t.tagName!,
  ];

  @override
  Widget build(BuildContext context) {
    final bloc = cubit ?? context.read<TransactionsCubit>();
    final relationNames = _relationNames(transaction);
    final theme = Theme.of(context);
    final locale = Localizations.localeOf(context);
    final localTime = transaction.transactedAt.toLocal();

    final weightedValue = transaction.value * transaction.percentage / 100.0;
    final primaryAmount =
        useWeightedAmounts ? weightedValue : transaction.value;

    Color primaryColor() {
      if (primaryAmount > 0) return const Color(0xFF1B8736);
      if (primaryAmount < 0) return theme.colorScheme.error;
      return theme.colorScheme.onSurfaceVariant;
    }

    final notFullPercentage = (transaction.percentage - 100.0).abs() > 0.01;
    final strikeAmount =
        useWeightedAmounts ? transaction.value : weightedValue;

    Widget titleSection() {
      final chunks = <Widget>[];
      final desc = transaction.description;
      final hasDesc = desc != null && desc.isNotEmpty;

      if (hasDesc) {
        if (notFullPercentage) {
          chunks.add(
            Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: '(${transaction.percentage.toStringAsFixed(2)}%) ',
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w700,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                  TextSpan(
                    text: desc,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          );
        } else {
          chunks.add(
            Text(
              desc,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
          );
        }
      } else if (notFullPercentage) {
        chunks.add(
          Text(
            '(${transaction.percentage.toStringAsFixed(2)}%)',
            style: theme.textTheme.labelLarge?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.w700,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        );
      }

      if (relationNames.isNotEmpty) {
        chunks.add(
          Padding(
            padding: EdgeInsets.only(top: chunks.isNotEmpty ? 4 : 0),
            child: Text(
              relationNames.join(' · '),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        );
      }

      if (chunks.isEmpty) {
        return const SizedBox.shrink();
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: chunks,
      );
    }

    final trailingPrices = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          l10n.transactionAmountValue(primaryAmount.toStringAsFixed(2)),
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
            color: primaryColor(),
            height: 1.2,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
        if (notFullPercentage) ...[
          const SizedBox(height: 2),
          Text(
            l10n.transactionAmountValue(strikeAmount.toStringAsFixed(2)),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.1,
              decoration: TextDecoration.lineThrough,
              decorationColor: theme.colorScheme.onSurfaceVariant,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
        const SizedBox(height: 4),
        Text(
          DateFormat.Hm(locale.toString()).format(localTime),
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );

    void openEdit() {
      showTransactionEditorBottomSheet(
        context,
        l10n: l10n,
        cubit: bloc,
        transaction: transaction,
      );
    }

    Widget tile = SwipeableListTile(
      itemKey: transaction.id,
      title: titleSection(),
      trailing: trailingPrices,
      onTap: onTap,
      onEdit: openEdit,
      confirmDelete:
          transaction.creditLedgerGroupingKey != null &&
                  transaction.creditLedgerGroupingKey!.isNotEmpty
              ? () => confirmDeleteCreditGroupTransactionDialog(context, l10n)
              : () => confirmDeleteTransactionDialog(context, l10n),
      onDelete: () => bloc.delete(
        id: transaction.id,
        creditLedgerKey: transaction.creditLedgerGroupingKey,
      ),
    );

    if (transaction.ignore) {
      tile = Opacity(opacity: 0.52, child: tile);
      tile = Tooltip(message: l10n.transactionIgnoredBadge, child: tile);
    }
    return tile;
  }
}

class GroupedTxnTransferPairTile extends StatelessWidget {
  const GroupedTxnTransferPairTile({
    super.key,
    /// When null, taken from [BlocProvider<TransactionsCubit>]. Pass in overlays
    /// (e.g. search) that are not under page-scoped bloc.
    this.cubit,
    required this.source,
    required this.target,
    required this.l10n,
    this.onTap,
  });

  final TransactionsCubit? cubit;
  final TransactionEntity source;
  final TransactionEntity target;
  final AppLocalizations l10n;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final bloc = cubit ?? context.read<TransactionsCubit>();
    final theme = Theme.of(context);
    final locale = Localizations.localeOf(context);
    final timeLocal = source.transactedAt.toLocal();
    final timeStr = DateFormat.Hm(locale.toString()).format(timeLocal);
    final amountStr = l10n.transactionAmountValue(
      target.value.toStringAsFixed(2),
    );
    final gid = source.transferGroupId;
    String payLabel(TransactionEntity t) => t.accountName ?? t.cardName ?? '—';

    final title = Text(
      payLabel(target),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w500),
    );

    final subtitle = Column(
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
        const SizedBox(height: 2),
        Text(
          timeStr,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );

    final trailing = Text(
      amountStr,
      style: theme.textTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.w700,
        color: theme.colorScheme.onSurfaceVariant,
        height: 1.2,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
    );

    void openEdit() {
      showAccountTransferEditorBottomSheet(
        context,
        l10n: l10n,
        editingSource: source,
        editingTarget: target,
        cubit: cubit,
      );
    }

    Widget tile = SwipeableListTile(
      itemKey: gid != null && gid.isNotEmpty
          ? 'pair_$gid'
          : '${source.id}|${target.id}',
      leading: Icon(
        Icons.swap_vert_rounded,
        size: 26,
        color: theme.colorScheme.onSurfaceVariant,
      ),
      title: title,
      subtitle: subtitle,
      trailing: trailing,
      onTap: onTap,
      onEdit: openEdit,
      confirmDelete: () => confirmDeleteTransferPairDialog(context, l10n),
      onDelete: () => bloc.deleteMany([source.id, target.id]),
    );

    if (source.ignore || target.ignore) {
      tile = Opacity(opacity: 0.52, child: tile);
      tile = Tooltip(message: l10n.transactionIgnoredBadge, child: tile);
    }
    return tile;
  }
}
