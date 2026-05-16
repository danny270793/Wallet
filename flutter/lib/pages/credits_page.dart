import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:wallet/l10n/app_localizations.dart';

import '../core/credit_group_description.dart';
import '../core/credit_ledger_grouping.dart';
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

/// Sum of [TransactionEntity.value] for the credit group [creditLedgerKey] across [flat].
double creditLedgerTotalValueForGroup(
  List<TransactionEntity> flat,
  String creditLedgerKey,
) {
  var sum = 0.0;
  for (final t in flat) {
    final g = t.creditLedgerGroupingKey;
    if (g == creditLedgerKey) {
      sum += t.value;
    }
  }
  return sum;
}

/// Number of ledger rows (installments / quotes) for [creditLedgerKey] in [flat].
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

/// Transactions for [creditLedgerKey] whose local due date is **strictly after** the
/// selected calendar month [monthStart] (on or after the first day of the following month).
int creditLedgerTransactionCountAfterSelectedMonth(
  List<TransactionEntity> flat,
  String creditLedgerKey,
  DateTime monthStart,
) {
  final firstDayAfterSelectedMonth =
      DateTime(monthStart.year, monthStart.month + 1, 1);
  var n = 0;
  for (final t in flat) {
    if (t.creditLedgerGroupingKey != creditLedgerKey) continue;
    final local = t.transactedAt.toLocal();
    final dueDay = DateTime(local.year, local.month, local.day);
    if (dueDay.isBefore(firstDayAfterSelectedMonth)) continue;
    n++;
  }
  return n;
}

/// Sum of [TransactionEntity.value] for [creditLedgerKey] rows whose local due date is
/// on or after the first day of the month **following** [monthStart] (upcoming months).
double creditLedgerTotalValueAfterSelectedMonth(
  List<TransactionEntity> flat,
  String creditLedgerKey,
  DateTime monthStart,
) {
  final firstDayAfterSelectedMonth =
      DateTime(monthStart.year, monthStart.month + 1, 1);
  var sum = 0.0;
  for (final t in flat) {
    if (t.creditLedgerGroupingKey != creditLedgerKey) continue;
    final local = t.transactedAt.toLocal();
    final dueDay = DateTime(local.year, local.month, local.day);
    if (dueDay.isBefore(firstDayAfterSelectedMonth)) continue;
    sum += t.value;
  }
  return sum;
}

List<String> _relationNames(TransactionEntity t) => [
  if (t.categoryName?.isNotEmpty == true) t.categoryName!,
  if (t.accountName?.isNotEmpty == true) t.accountName!,
  if (t.cardName?.isNotEmpty == true) t.cardName!,
  if (t.tagName?.isNotEmpty == true) t.tagName!,
];

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
    if (installmentIsPaidThroughToday(t)) continue;
    final local = t.transactedAt.toLocal();
    final dueDay = DateTime(local.year, local.month, local.day);
    if (dueDay.isBefore(monthFirst)) continue;
    sum += t.value;
  }
  return sum;
}

/// Sum of raw values for installments due in [monthStart]'s calendar month
/// (see [creditLedgerInstallmentsInSelectedMonth]).
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
    required this.headerRow,
    required this.monthRows,
    required this.groupLeadRow,
    required this.creditLedgerKey,
    required this.totalInstallmentCount,
    required this.pendingCountAfterSelectedMonth,
    required this.futureMonthsPendingTotal,
    required this.totalCreditValue,
    required this.l10n,
    required this.onSwipeEdit,
  });

  final TransactionsCubit cubit;
  /// Row used for title (relations, purchase time); first in month if any, else first in plan.
  final TransactionEntity headerRow;
  /// Installments for the visible month only; first trailing line (this month's quote).
  final List<TransactionEntity> monthRows;
  /// First installment of the plan (chronological); used as delete anchor for the group.
  final TransactionEntity groupLeadRow;
  final String creditLedgerKey;
  /// All quotes / installments for this credit (full plan).
  final int totalInstallmentCount;
  /// Transactions for this credit with due date after the visible month (> last day of selected month).
  final int pendingCountAfterSelectedMonth;
  /// Sum of installment values due in months after the visible month (same window as [pendingCountAfterSelectedMonth]).
  final double futureMonthsPendingTotal;
  /// Sum of [TransactionEntity.value] for all installments in this group (full ledger).
  final double totalCreditValue;
  final AppLocalizations l10n;

  /// Opens the editor for the group's first installment and reloads the page list.
  final VoidCallback onSwipeEdit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final first = headerRow;

    final quoteThisMonth =
        monthRows.fold<double>(0, (a, t) => a + t.value);

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
            pendingCountAfterSelectedMonth > 0
                ? l10n.creditsInstallmentsWithPending(
                    totalInstallmentCount,
                    pendingCountAfterSelectedMonth,
                  )
                : l10n.creditsInstallmentsEndsThisMonth(
                    totalInstallmentCount,
                  ),
            style: theme.textTheme.bodySmall?.copyWith(
              color: pendingCountAfterSelectedMonth > 0
                  ? theme.colorScheme.onSurfaceVariant
                  : const Color(0xFF1B8736),
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

    Widget trailingAmountText(
      double amount,
      Color amountColor, {
      bool compact = false,
    }) {
      final base = compact
          ? theme.textTheme.bodySmall
          : theme.textTheme.titleSmall;
      return Text(
        l10n.transactionAmountValue(amount.toStringAsFixed(2)),
        textAlign: TextAlign.end,
        style: base?.copyWith(
          fontWeight: compact ? FontWeight.w600 : FontWeight.w700,
          color: amountColor,
          height: 1.15,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      );
    }

    final trailingPrices = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        trailingAmountText(quoteThisMonth, theme.colorScheme.error),
        const SizedBox(height: 2),
        trailingAmountText(
          futureMonthsPendingTotal,
          theme.colorScheme.onSurface,
          compact: true,
        ),
        const SizedBox(height: 2),
        trailingAmountText(
          totalCreditValue,
          theme.colorScheme.onSurface,
          compact: true,
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
          cubit.delete(id: groupLeadRow.id, creditLedgerKey: creditLedgerKey),
    );
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
        final allCreditGroups = groupedCreditLedger(_flat);
        final hasAnyCredits = allCreditGroups.isNotEmpty;
        final monthInstallments =
            creditLedgerInstallmentsInSelectedMonth(_flat, visibleMonth);
        final groups = groupedCreditLedger(monthInstallments);
        final showPendingBar = !_loading && hasAnyCredits;
        final dueInMonth = creditLedgerDueInSelectedMonth(_flat, visibleMonth);
        final pendingTotal =
            creditLedgerPendingTotalFromSelectedMonth(_flat, visibleMonth);
        final fullGroupsById = {
          for (final fg in allCreditGroups) fg.id: fg,
        };

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
                          final monthRows = g.rows;
                          final full = fullGroupsById[g.id]!;
                          final headerRow = monthRows.first;
                          return _CreditGroupTile(
                            cubit: cubit,
                            headerRow: headerRow,
                            monthRows: monthRows,
                            groupLeadRow: full.rows.first,
                            creditLedgerKey: g.id,
                            totalInstallmentCount:
                                creditLedgerTotalInstallmentCountForGroup(
                              _flat,
                              g.id,
                            ),
                            pendingCountAfterSelectedMonth:
                                creditLedgerTransactionCountAfterSelectedMonth(
                              _flat,
                              g.id,
                              visibleMonth,
                            ),
                            totalCreditValue:
                                creditLedgerTotalValueForGroup(_flat, g.id),
                            futureMonthsPendingTotal:
                                creditLedgerTotalValueAfterSelectedMonth(
                              _flat,
                              g.id,
                              visibleMonth,
                            ),
                            l10n: l10n,
                            onSwipeEdit: () =>
                                _openEditor(headerRow, l10n),
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
