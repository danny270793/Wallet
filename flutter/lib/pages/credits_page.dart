import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:wallet/l10n/app_localizations.dart';

import '../core/credit_group_description.dart';
import '../core/di/injection.dart';
import '../features/transactions/domain/entities/transaction_entity.dart';
import '../features/transactions/domain/usecases/list_transactions_having_credit_group_usecase.dart';
import '../features/transactions/presentation/cubit/transactions_cubit.dart';
import '../widgets/shell_scaffold.dart';
import '../widgets/wallet_bottom_bar_insets.dart';
import '../widgets/swipeable_list_tile.dart';
import '../widgets/transaction_delete_dialogs.dart';
import 'transactions_page.dart' show showTransactionEditorBottomSheet;

/// Groups rows by [TransactionEntity.creditLedgerGroupingKey]; newest groups (by latest date) first.
List<({String id, List<TransactionEntity> rows})> groupedCreditLedger(
  List<TransactionEntity> flat,
) {
  final m = <String, List<TransactionEntity>>{};
  for (final t in flat) {
    final g = t.creditLedgerGroupingKey;
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

  final keys = m.keys.toList()
    ..sort((a, b) => newest(m[b]!).compareTo(newest(m[a]!)));
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

double _weighted(TransactionEntity t) => t.value * t.percentage / 100.0;

/// Installment is treated as already posted when its local calendar date is on or before today.
bool _installmentIsPaidThroughToday(TransactionEntity t) {
  final now = DateTime.now();
  final local = t.transactedAt.toLocal();
  final d = DateTime(local.year, local.month, local.day);
  final today = DateTime(now.year, now.month, now.day);
  return !d.isAfter(today);
}

/// Sum of weighted amounts for installments not yet reached by local calendar date.
double creditLedgerTotalPendingWeighted(List<TransactionEntity> flat) {
  var sum = 0.0;
  for (final t in flat) {
    final g = t.creditLedgerGroupingKey;
    if (g == null || g.isEmpty) continue;
    if (!_installmentIsPaidThroughToday(t)) {
      sum += _weighted(t);
    }
  }
  return sum;
}

/// Weighted sum of installments due in the current local month (due date on or after today).
double creditLedgerDueThisMonthWeighted(List<TransactionEntity> flat) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  var sum = 0.0;
  for (final t in flat) {
    final g = t.creditLedgerGroupingKey;
    if (g == null || g.isEmpty) continue;
    final local = t.transactedAt.toLocal();
    if (local.year != now.year || local.month != now.month) continue;
    final dueDay = DateTime(local.year, local.month, local.day);
    if (dueDay.isBefore(today)) continue;
    sum += _weighted(t);
  }
  return sum;
}

class _CreditsPendingTotalsBar extends StatelessWidget {
  const _CreditsPendingTotalsBar({
    required this.l10n,
    required this.pendingWeighted,
    required this.dueThisMonthWeighted,
  });

  final AppLocalizations l10n;
  final double pendingWeighted;
  final double dueThisMonthWeighted;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final amountStr = l10n.transactionAmountValue(
      pendingWeighted.toStringAsFixed(2),
    );
    final hasPending = pendingWeighted.abs() > 0.005;
    final amountColor = hasPending
        ? theme.colorScheme.error
        : theme.colorScheme.onSurfaceVariant;

    final monthStr = l10n.transactionAmountValue(
      dueThisMonthWeighted.toStringAsFixed(2),
    );
    final hasMonthDue = dueThisMonthWeighted.abs() > 0.005;
    final monthColor = hasMonthDue
        ? theme.colorScheme.error
        : theme.colorScheme.onSurfaceVariant;

    return Material(
      color: theme.colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: EdgeInsets.only(
          bottom: walletBottomBarExtraBottomInset(context),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      amountStr,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        height: 1.2,
                        fontFeatures: const [FontFeature.tabularFigures()],
                        color: amountColor,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      l10n.creditsPendingTotalsLabel,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      monthStr,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        height: 1.2,
                        fontFeatures: const [FontFeature.tabularFigures()],
                        color: monthColor,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      l10n.creditsDueThisMonthLabel,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CreditGroupTile extends StatelessWidget {
  const _CreditGroupTile({
    required this.cubit,
    required this.rows,
    required this.creditLedgerKey,
    required this.l10n,
    required this.onSwipeEdit,
  });

  final TransactionsCubit cubit;
  final List<TransactionEntity> rows;
  final String creditLedgerKey;
  final AppLocalizations l10n;

  /// Opens the editor for the group's first installment and reloads the page list.
  final VoidCallback onSwipeEdit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final first = rows.first;

    final totalRaw = rows.fold<double>(0, (a, t) => a + t.value);
    final groupPartialPct = rows.any(
      (t) => (t.percentage - 100.0).abs() > 0.01,
    );

    double paidWeighted = 0;
    double pendingWeighted = 0;
    var pendingInstallmentCount = 0;
    for (final t in rows) {
      final w = _weighted(t);
      if (_installmentIsPaidThroughToday(t)) {
        paidWeighted += w;
      } else {
        pendingWeighted += w;
        pendingInstallmentCount++;
      }
    }

    final totalWeighted = pendingWeighted + paidWeighted;

    const paidGreen = Color(0xFF1B8736);

    final relationNames = _relationNames(first);

    Widget titleSection() {
      final chunks = <Widget>[];
      final displayDesc = stripLeadingCreditInstallmentDescription(
        first.description,
      ).trim();
      final hasDesc = displayDesc.isNotEmpty;

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
                    text: displayDesc,
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
              displayDesc,
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

      final creditAt = first.creditTransactedAt;
      if (creditAt != null) {
        final locale = Localizations.localeOf(context);
        final when = DateFormat(
          'yMMMd, HH:mm',
          locale.toString(),
        ).format(creditAt.toLocal());
        chunks.add(
          Padding(
            padding: EdgeInsets.only(top: chunks.isNotEmpty ? 4 : 0),
            child: Text(
              l10n.creditsWalletCreditTransactedAt(when),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
        );
      }

      chunks.add(
        Padding(
          padding: EdgeInsets.only(top: chunks.isNotEmpty ? 4 : 0),
          child: Text(
            l10n.creditsInstallmentsWithPending(
              rows.length,
              pendingInstallmentCount,
            ),
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
        if (groupPartialPct) ...[
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
          const SizedBox(height: 8),
        ],
        if (pendingWeighted.abs() > 0.005) ...[
          Text(
            l10n.transactionAmountValue(pendingWeighted.toStringAsFixed(2)),
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: theme.colorScheme.error,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 4),
        ],
        Text(
          l10n.transactionAmountValue(
            paidWeighted.abs() > 0.005
                ? paidWeighted.abs().toStringAsFixed(2)
                : '0.00',
          ),
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
            color: paidGreen,
            height: 1.15,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          l10n.transactionAmountValue(totalWeighted.toStringAsFixed(2)),
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
            color: theme.colorScheme.onSurface,
            height: 1.15,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );

    return SwipeableListTile(
      itemKey: creditLedgerKey,
      title: titleSection(),
      trailing: trailingPrices,
      onEdit: onSwipeEdit,
      confirmDelete: () =>
          confirmDeleteCreditGroupTransactionDialog(context, l10n),
      onDelete: () =>
          cubit.delete(id: first.id, creditLedgerKey: creditLedgerKey),
    );
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

  Future<void> _openNewCreditPurchase(AppLocalizations l10n) async {
    final cubit = context.read<TransactionsCubit>();
    await showTransactionEditorBottomSheet(
      context,
      l10n: l10n,
      cubit: cubit,
      forceDeferredCredit: true,
      paymentMethodCardsOnly: true,
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
        floatingActionButton: FloatingActionButton(
          onPressed: () => _openNewCreditPurchase(l10n),
          child: const Icon(Icons.add),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(l10n.unexpectedError, textAlign: TextAlign.center),
          ),
        ),
      );
    }

    final groups = groupedCreditLedger(_flat);
    final showPendingBar = !_loading && groups.isNotEmpty;

    return ShellScaffold(
      title: l10n.creditsTitle,
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openNewCreditPurchase(l10n),
        child: const Icon(Icons.add),
      ),
      bottomNavigationBar: showPendingBar
          ? _CreditsPendingTotalsBar(
              l10n: l10n,
              pendingWeighted: creditLedgerTotalPendingWeighted(_flat),
              dueThisMonthWeighted: creditLedgerDueThisMonthWeighted(_flat),
            )
          : null,
      body: RefreshIndicator(
        onRefresh: _load,
        child: _loading
            ? ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(0, 120, 0, 88),
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
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 88),
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
                    padding: const EdgeInsets.fromLTRB(0, 0, 0, 88),
                    itemCount: groups.length,
                    itemBuilder: (context, i) {
                      final g = groups[i];
                      return _CreditGroupTile(
                        cubit: cubit,
                        rows: g.rows,
                        creditLedgerKey: g.id,
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
