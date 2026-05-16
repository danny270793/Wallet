import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:wallet/l10n/app_localizations.dart';

import '../core/credit_group_description.dart';
import '../core/di/injection.dart';
import '../core/remote_load_failure.dart';
import '../features/transactions/domain/entities/transaction_entity.dart';
import '../features/transactions/domain/usecases/list_transactions_having_credit_group_usecase.dart';
import '../features/transactions/presentation/cubit/transactions_cubit.dart';
import '../widgets/offline_cached_data_banner.dart';
import '../widgets/remote_load_failure_panel.dart';
import '../widgets/shell_scaffold.dart';
import '../widgets/transactions_month_scope.dart';
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

/// Number of ledger rows (installments) in the credit group [creditLedgerKey] across [flat].
int creditLedgerTotalInstallmentCountForGroup(
  List<TransactionEntity> flat,
  String creditLedgerKey,
) {
  var n = 0;
  for (final t in flat) {
    final g = t.creditLedgerGroupingKey;
    if (g == creditLedgerKey) {
      n++;
    }
  }
  return n;
}

List<String> _relationNames(TransactionEntity t) => [
  if (t.categoryName?.isNotEmpty == true) t.categoryName!,
  if (t.accountName?.isNotEmpty == true) t.accountName!,
  if (t.cardName?.isNotEmpty == true) t.cardName!,
  if (t.tagName?.isNotEmpty == true) t.tagName!,
];

/// Installment is treated as already posted when its local calendar date is on or before today.
bool _installmentIsPaidThroughToday(TransactionEntity t) {
  final now = DateTime.now();
  final local = t.transactedAt.toLocal();
  final d = DateTime(local.year, local.month, local.day);
  final today = DateTime(now.year, now.month, now.day);
  return !d.isAfter(today);
}

/// Installments due in [monthStart]'s calendar month (credit rows only).
/// For the current local month, excludes due dates before today.
List<TransactionEntity> creditLedgerInstallmentsInSelectedMonth(
  List<TransactionEntity> flat,
  DateTime monthStart,
) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final y = monthStart.year;
  final m = monthStart.month;
  final isCurrentMonth = y == today.year && m == today.month;
  final out = <TransactionEntity>[];
  for (final t in flat) {
    final g = t.creditLedgerGroupingKey;
    if (g == null || g.isEmpty) continue;
    final local = t.transactedAt.toLocal();
    if (local.year != y || local.month != m) continue;
    final dueDay = DateTime(local.year, local.month, local.day);
    if (isCurrentMonth && dueDay.isBefore(today)) continue;
    out.add(t);
  }
  return out;
}

/// Sum of [TransactionEntity.value] for credit installments still unpaid (local due after today)
/// whose **due date** is on or after the first day of [monthStart]'s month.
///
/// Advancing the selected month excludes installments due in earlier months, e.g. three \$100
/// dues in three consecutive months show 300 → 200 → 100 → 0.
double creditLedgerPendingTotalFromSelectedMonth(
  List<TransactionEntity> flat,
  DateTime monthStart,
) {
  final monthFirst = DateTime(monthStart.year, monthStart.month, 1);
  var sum = 0.0;
  for (final t in flat) {
    final g = t.creditLedgerGroupingKey;
    if (g == null || g.isEmpty) continue;
    if (_installmentIsPaidThroughToday(t)) continue;
    final local = t.transactedAt.toLocal();
    final dueDay = DateTime(local.year, local.month, local.day);
    if (dueDay.isBefore(monthFirst)) continue;
    sum += t.value;
  }
  return sum;
}

/// Unpaid installments in [creditLedgerKey] with due date on or after the first day of
/// [monthStart] (same window as [creditLedgerPendingTotalFromSelectedMonth] for one group).
int creditLedgerPendingInstallmentCountFromSelectedMonth(
  List<TransactionEntity> flat,
  String creditLedgerKey,
  DateTime monthStart,
) {
  final monthFirst = DateTime(monthStart.year, monthStart.month, 1);
  var n = 0;
  for (final t in flat) {
    final g = t.creditLedgerGroupingKey;
    if (g != creditLedgerKey) continue;
    if (_installmentIsPaidThroughToday(t)) continue;
    final local = t.transactedAt.toLocal();
    final dueDay = DateTime(local.year, local.month, local.day);
    if (dueDay.isBefore(monthFirst)) continue;
    n++;
  }
  return n;
}

/// Sum of raw values for installments due in [monthStart]'s calendar month.
/// For the current local month, only dues on or after today are included.
double creditLedgerDueInSelectedMonth(
  List<TransactionEntity> flat,
  DateTime monthStart,
) {
  return creditLedgerInstallmentsInSelectedMonth(flat, monthStart)
      .fold<double>(0, (a, t) => a + t.value);
}

class _CreditsPendingTotalsBar extends StatelessWidget {
  const _CreditsPendingTotalsBar({
    required this.l10n,
    required this.pendingTotal,
    required this.dueInSelectedMonthTotal,
  });

  final AppLocalizations l10n;
  /// Remaining installment principal for dues on or after the visible month (see [creditLedgerPendingTotalFromSelectedMonth]).
  final double pendingTotal;
  /// Sum for installments due in the selected month ([creditLedgerDueInSelectedMonth]).
  final double dueInSelectedMonthTotal;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final amountStr = l10n.transactionAmountValue(
      pendingTotal.toStringAsFixed(2),
    );
    final hasPending = pendingTotal.abs() > 0.005;
    final amountColor = hasPending
        ? theme.colorScheme.error
        : theme.colorScheme.onSurfaceVariant;

    final monthStr = l10n.transactionAmountValue(
      dueInSelectedMonthTotal.toStringAsFixed(2),
    );
    final hasMonthDue = dueInSelectedMonthTotal.abs() > 0.005;
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
    required this.totalInstallmentCount,
    required this.pendingInstallmentsForwardFromMonth,
    required this.l10n,
    required this.onSwipeEdit,
  });

  final TransactionsCubit cubit;
  final List<TransactionEntity> rows;
  final String creditLedgerKey;
  /// Full credit plan size (all installments in the group), not only [rows] in the visible month.
  final int totalInstallmentCount;
  /// Unpaid installments with due on/after visible month's first day (see [creditLedgerPendingInstallmentCountFromSelectedMonth]).
  final int pendingInstallmentsForwardFromMonth;
  final AppLocalizations l10n;

  /// Opens the editor for the group's first installment and reloads the page list.
  final VoidCallback onSwipeEdit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final first = rows.first;

    final pendingRows =
        rows.where((t) => !_installmentIsPaidThroughToday(t)).toList();
    final paidRows = rows.where(_installmentIsPaidThroughToday).toList();
    final pendingTotal =
        pendingRows.fold<double>(0, (a, t) => a + t.value);
    // Sum of each paid installment's full [TransactionEntity.value], not × percentage/100.
    final paidTotal = paidRows.fold<double>(0, (a, t) => a + t.value);

    final fullyPaid = pendingTotal.abs() <= 0.005;

    const paidGreen = Color(0xFF1B8736);

    final relationNames = _relationNames(first);

    Widget titleSection() {
      final chunks = <Widget>[];
      final displayDesc = stripLeadingCreditInstallmentDescription(
        first.description,
      ).trim();
      final hasDesc = displayDesc.isNotEmpty;

      if (hasDesc) {
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
      } else {
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
              totalInstallmentCount,
              pendingInstallmentsForwardFromMonth,
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
        if (pendingTotal.abs() > 0.005) ...[
          Text(
            l10n.transactionAmountValue(pendingTotal.toStringAsFixed(2)),
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: theme.colorScheme.error,
              height: 1.15,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(height: 2),
        ],
        Text(
          l10n.transactionAmountValue(
            paidTotal.abs() > 0.005 ? paidTotal.toStringAsFixed(2) : '0.00',
          ),
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
            color: fullyPaid
                ? theme.colorScheme.onSurfaceVariant
                : paidGreen,
            height: 1.15,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );

    Widget tile = SwipeableListTile(
      itemKey: creditLedgerKey,
      title: titleSection(),
      trailing: trailingPrices,
      onEdit: onSwipeEdit,
      confirmDelete: () =>
          confirmDeleteCreditGroupTransactionDialog(context, l10n),
      onDelete: () =>
          cubit.delete(id: first.id, creditLedgerKey: creditLedgerKey),
    );
    if (fullyPaid) {
      tile = Opacity(opacity: 0.52, child: tile);
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
  late final ValueNotifier<DateTime> _dueMonthNotifier;
  bool _loading = true;
  Object? _error;
  List<TransactionEntity> _flat = const [];
  bool _servedFromOfflineCache = false;

  @override
  void initState() {
    super.initState();
    final n = DateTime.now();
    _dueMonthNotifier = ValueNotifier(DateTime(n.year, n.month, 1));
    _load();
  }

  @override
  void dispose() {
    _dueMonthNotifier.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final bundle = await getIt<ListTransactionsHavingCreditGroupUsecase>()();
      if (!mounted) return;
      setState(() {
        _flat = bundle.value;
        _servedFromOfflineCache = bundle.servedFromOfflineCache;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _loading = false;
        _servedFromOfflineCache = false;
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
      final failure = classifyRemoteLoadError(_error!);
      return ShellScaffold(
        title: l10n.creditsTitle,
        appBarBottom: TransactionsMonthAppBarBottom(notifier: _dueMonthNotifier),
        floatingActionButton: FloatingActionButton(
          onPressed: () => _openNewCreditPurchase(l10n),
          child: const Icon(Icons.add),
        ),
        body: RemoteLoadFailurePanel(
          l10n: l10n,
          failure: failure,
          onRetry: _load,
          listPadding: const EdgeInsets.fromLTRB(24, 24, 24, 24 + 88),
        ),
      );
    }

    return ValueListenableBuilder<DateTime>(
      valueListenable: _dueMonthNotifier,
      builder: (context, visibleMonth, _) {
        final hasAnyCredits = groupedCreditLedger(_flat).isNotEmpty;
        final flatMonth =
            creditLedgerInstallmentsInSelectedMonth(_flat, visibleMonth);
        final groups = groupedCreditLedger(flatMonth);
        final showPendingBar = !_loading && hasAnyCredits;
        final dueInMonth = creditLedgerDueInSelectedMonth(_flat, visibleMonth);
        final pendingTotal =
            creditLedgerPendingTotalFromSelectedMonth(_flat, visibleMonth);

        return ShellScaffold(
          title: l10n.creditsTitle,
          appBarBottom:
              TransactionsMonthAppBarBottom(notifier: _dueMonthNotifier),
          floatingActionButton: FloatingActionButton(
            onPressed: () => _openNewCreditPurchase(l10n),
            child: const Icon(Icons.add),
          ),
          bottomNavigationBar: showPendingBar
              ? _CreditsPendingTotalsBar(
                  l10n: l10n,
                  pendingTotal: pendingTotal,
                  dueInSelectedMonthTotal: dueInMonth,
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
                : !hasAnyCredits
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 88),
                    children: [
                      OfflineCachedDataBanner(visible: _servedFromOfflineCache),
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
                : groups.isEmpty
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 88),
                    children: [
                      OfflineCachedDataBanner(visible: _servedFromOfflineCache),
                      SizedBox(height: MediaQuery.paddingOf(context).top + 40),
                      Text(
                        l10n.creditsEmptyForSelectedMonth,
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
                        itemCount:
                            groups.length + (_servedFromOfflineCache ? 1 : 0),
                        itemBuilder: (context, i) {
                          if (_servedFromOfflineCache && i == 0) {
                            return const OfflineCachedDataBanner(visible: true);
                          }
                          final gi = i - (_servedFromOfflineCache ? 1 : 0);
                          final g = groups[gi];
                          return _CreditGroupTile(
                            cubit: cubit,
                            rows: g.rows,
                            creditLedgerKey: g.id,
                            totalInstallmentCount:
                                creditLedgerTotalInstallmentCountForGroup(
                              _flat,
                              g.id,
                            ),
                            pendingInstallmentsForwardFromMonth:
                                creditLedgerPendingInstallmentCountFromSelectedMonth(
                              _flat,
                              g.id,
                              visibleMonth,
                            ),
                            l10n: l10n,
                            onSwipeEdit: () => _openEditor(g.rows.first, l10n),
                          );
                        },
                      );
                    },
                  ),
          ),
        );
      },
    );
  }
}
