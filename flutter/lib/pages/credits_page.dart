import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:wallet/l10n/app_localizations.dart';

import '../core/di/injection.dart';
import '../features/transactions/domain/entities/transaction_entity.dart';
import '../features/transactions/domain/usecases/list_transactions_having_credit_group_usecase.dart';
import '../features/transactions/presentation/cubit/transactions_cubit.dart';
import '../widgets/shell_scaffold.dart';
import '../widgets/swipeable_list_tile.dart';
import '../widgets/transaction_delete_dialogs.dart';
import 'transactions_page.dart' show showTransactionEditorBottomSheet;

/// Groups rows by [TransactionEntity.creditGroupId]; newest groups (by latest date) first.
List<({String id, List<TransactionEntity> rows})> groupedCreditLedger(
    List<TransactionEntity> flat) {
  final m = <String, List<TransactionEntity>>{};
  for (final t in flat) {
    final g = t.creditGroupId;
    if (g == null || g.isEmpty) continue;
    m.putIfAbsent(g, () => []).add(t);
  }
  for (final rows in m.values) {
    rows.sort((a, b) => a.transactedAt.compareTo(b.transactedAt));
  }
  final out = <({String id, List<TransactionEntity> rows})>[];
  DateTime newest(List<TransactionEntity> r) {
    DateTime mx = r.first.transactedAt;
    for (final x in r) {
      if (x.transactedAt.isAfter(mx)) mx = x.transactedAt;
    }
    return mx;
  }

  final keys = m.keys.toList()..sort((a, b) => newest(m[b]!).compareTo(newest(m[a]!)));
  for (final k in keys) {
    final rows = m[k]!;
    out.add((id: k, rows: rows));
  }
  return out;
}

List<String> _relationNames(TransactionEntity t) => [
  if (t.categoryName?.isNotEmpty == true) t.categoryName!,
  if (t.accountName?.isNotEmpty == true) t.accountName!,
  if (t.cardName?.isNotEmpty == true) t.cardName!,
  if (t.tagName?.isNotEmpty == true) t.tagName!,
];

class _CreditGroupTile extends StatelessWidget {
  const _CreditGroupTile({
    required this.cubit,
    required this.rows,
    required this.creditGroupId,
    required this.l10n,
    required this.onSwipeEdit,
  });

  final TransactionsCubit cubit;
  final List<TransactionEntity> rows;
  final String creditGroupId;
  final AppLocalizations l10n;
  /// Opens the editor for the group's first installment and reloads the page list.
  final VoidCallback onSwipeEdit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final locale = Localizations.localeOf(context);
    final first = rows.first;

    final totalWeighted = rows.fold<double>(
      0,
      (a, t) => a + t.value * t.percentage / 100.0,
    );
    final totalRaw = rows.fold<double>(0, (a, t) => a + t.value);
    final groupPartialPct = rows.any(
      (t) => (t.percentage - 100.0).abs() > 0.01,
    );

    Color weightedColor() {
      if (totalWeighted > 0) return const Color(0xFF1B8736);
      if (totalWeighted < 0) return theme.colorScheme.error;
      return theme.colorScheme.onSurfaceVariant;
    }

    final relationNames = _relationNames(first);
    final localTime = first.transactedAt.toLocal();

    Widget titleSection() {
      final chunks = <Widget>[];
      final desc = first.description;
      final hasDesc = desc != null && desc.isNotEmpty;

      if (!hasDesc && (first.percentage - 100.0).abs() <= 0.01) {
        chunks.add(
          Text(
            l10n.creditsUntitledGroup,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodyLarge?.copyWith(
              fontWeight: FontWeight.w500,
            ),
          ),
        );
      }

      if (hasDesc) {
        if ((first.percentage - 100.0).abs() > 0.01) {
          chunks.add(
            Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: '(${first.percentage.toStringAsFixed(2)}%) ',
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
      } else if ((first.percentage - 100.0).abs() > 0.01) {
        chunks.add(
          Text(
            '(${first.percentage.toStringAsFixed(2)}%)',
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

      chunks.add(
        Padding(
          padding: EdgeInsets.only(top: chunks.isNotEmpty ? 4 : 0),
          child: Text(
            l10n.creditsInstallmentsCount(rows.length),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      );

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
          l10n.transactionAmountValue(totalWeighted.toStringAsFixed(2)),
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
            color: weightedColor(),
            height: 1.2,
          ),
        ),
        if (groupPartialPct) ...[
          const SizedBox(height: 2),
          Text(
            l10n.transactionAmountValue(totalRaw.toStringAsFixed(2)),
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

    Widget tile = SwipeableListTile(
      itemKey: creditGroupId,
      title: titleSection(),
      trailing: trailingPrices,
      onEdit: onSwipeEdit,
      confirmDelete: () =>
          confirmDeleteCreditGroupTransactionDialog(context, l10n),
      onDelete: () => cubit.delete(
        id: first.id,
        creditGroupId: creditGroupId,
      ),
    );

    final allIgnored = rows.every((t) => t.ignore);
    if (allIgnored) {
      tile = Opacity(opacity: 0.52, child: tile);
      tile = Tooltip(message: l10n.transactionIgnoredBadge, child: tile);
    }
    return tile;
  }
}

class CreditsPage extends StatefulWidget {
  const CreditsPage({super.key});

  @override
  State<CreditsPage> createState() => _CreditsPageState();
}

class _CreditsPageState extends State<CreditsPage> {
  bool _loading = true;
  Object? _error;
  List<TransactionEntity> _flat = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await getIt<ListTransactionsHavingCreditGroupUsecase>()();
      if (!mounted) return;
      setState(() {
        _flat = list;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  Future<void> _openEditor(TransactionEntity t, AppLocalizations l10n) async {
    final cubit = context.read<TransactionsCubit>();
    await showTransactionEditorBottomSheet(
      context,
      l10n: l10n,
      cubit: cubit,
      transaction: t,
    );
    if (mounted) await _load();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    if (_error != null && !_loading) {
      return ShellScaffold(
        title: l10n.creditsTitle,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              l10n.unexpectedError,
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    final groups = groupedCreditLedger(_flat);

    return ShellScaffold(
      title: l10n.creditsTitle,
      body: RefreshIndicator(
        onRefresh: _load,
        child: _loading
            ? ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.only(top: 120),
                children: const [
                  Center(
                    child: SizedBox(
                      width: 32,
                      height: 32,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                ],
              )
            : groups.isEmpty
            ? ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(24),
                children: [
                  SizedBox(height: MediaQuery.paddingOf(context).top + 40),
                  Text(
                    l10n.creditsEmpty,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              )
            : Builder(
              builder: (context) {
                final cubit = context.read<TransactionsCubit>();
                return ListView.builder(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.only(bottom: 8),
                  itemCount: groups.length,
                  itemBuilder: (context, i) {
                    final g = groups[i];
                    return _CreditGroupTile(
                      cubit: cubit,
                      rows: g.rows,
                      creditGroupId: g.id,
                      l10n: l10n,
                      onSwipeEdit: () => _openEditor(g.rows.first, l10n),
                    );
                  },
                );
              },
            ),
      ),
    );
  }
}
