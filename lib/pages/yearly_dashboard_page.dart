import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:wallet/l10n/app_localizations.dart';

import '../core/di/injection.dart';
import '../core/ui/app_icons.dart';
import '../features/transactions/domain/entities/transaction_entity.dart';
import '../features/transactions/presentation/cubit/transactions_cubit.dart';
import '../features/transactions/presentation/cubit/yearly_dashboard_cubit.dart';
import '../widgets/dashboard_view_options_bottom_sheet.dart';
import '../widgets/grouped_transactions_list.dart';
import '../widgets/monthly_category_expense_pie_chart.dart';
import '../widgets/monthly_tag_pie_chart.dart';
import '../widgets/offline_cached_data_banner.dart';
import '../widgets/remote_load_failure_panel.dart';
import '../widgets/shell_scaffold.dart';
import '../widgets/yearly_dashboard_scope.dart';
import '../widgets/yearly_weighted_income_bar_chart.dart';

class YearlyDashboardPage extends StatelessWidget {
  const YearlyDashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return YearlyDashboardHost(
      child: MultiBlocProvider(
        providers: [
          BlocProvider(create: (_) => getIt<YearlyDashboardCubit>()),
          BlocProvider(create: (_) => getIt<TransactionsCubit>()),
        ],
        child: const _YearlyDashboardView(),
      ),
    );
  }
}

class _YearlyDashboardView extends StatefulWidget {
  const _YearlyDashboardView();

  @override
  State<_YearlyDashboardView> createState() => _YearlyDashboardViewState();
}

class _YearlyDashboardViewState extends State<_YearlyDashboardView> {
  ValueNotifier<DateTime>? _yearNotifier;
  bool _listenerAttached = false;

  /// When true, ignored rows count toward yearly chart bars.
  bool _includeIgnored = true;

  /// When true, monthly bars use `value × percentage`; when false, raw row value.
  bool _useWeightedAmounts = true;

  /// When false, transactions linked to a credit (installments) are excluded entirely.
  bool _showCredits = true;

  /// Same semantics as the monthly dashboard pies: null = all.
  Set<String>? _tagKeysFilter;
  Set<String>? _categoryKeysFilter;

  /// Rows whose local date falls in [year]. The year fetch also includes earlier
  /// history for the cumulative chart; the pies are this year's totals only.
  List<TransactionEntity> _transactionsInYear(
    List<TransactionEntity> txs,
    int year,
  ) {
    return txs.where((t) => t.transactedAt.toLocal().year == year).toList();
  }

  List<TransactionEntity> _filterByTag(
    List<TransactionEntity> txs,
    Set<String>? tagKeysFilter,
  ) {
    if (tagKeysFilter == null) return txs;
    return txs.where((t) {
      final id = t.tagId;
      return id != null && id.isNotEmpty && tagKeysFilter.contains(id);
    }).toList();
  }

  List<TransactionEntity> _transactionsForList(
    List<TransactionEntity> txs,
    Set<String>? tagKeysFilter,
    Set<String>? categoryKeysFilter,
  ) {
    return txs.where((t) {
      if (!_includeIgnored && t.ignore) return false;
      if (tagKeysFilter != null) {
        final tid = t.tagId;
        if (tid == null || tid.isEmpty || !tagKeysFilter.contains(tid)) {
          return false;
        }
      }
      if (categoryKeysFilter != null) {
        final cid = t.categoryId;
        if (cid == null || cid.isEmpty || !categoryKeysFilter.contains(cid)) {
          return false;
        }
      }
      return true;
    }).toList();
  }

  List<TransactionEntity> _filterByCategory(
    List<TransactionEntity> txs,
    Set<String>? categoryKeysFilter,
  ) {
    if (categoryKeysFilter == null) return txs;
    return txs.where((t) {
      final id = t.categoryId;
      return id != null && id.isNotEmpty && categoryKeysFilter.contains(id);
    }).toList();
  }

  /// Respects [_showCredits]: excludes credit-linked installments entirely when off.
  List<TransactionEntity> _filterCredits(List<TransactionEntity> txs) {
    if (_showCredits) return txs;
    return txs.where((t) => t.creditId == null || t.creditId!.isEmpty).toList();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_listenerAttached) return;
    _listenerAttached = true;
    _yearNotifier = YearlyDashboardScope.of(context);
    _yearNotifier!.addListener(_onYearChanged);
    context.read<YearlyDashboardCubit>().loadYear(_yearNotifier!.value);
  }

  void _onYearChanged() {
    final n = _yearNotifier;
    if (n == null) return;
    context.read<YearlyDashboardCubit>().loadYear(n.value);
  }

  @override
  void dispose() {
    _yearNotifier?.removeListener(_onYearChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final yearNotifier = YearlyDashboardScope.of(context);

    return ValueListenableBuilder<DateTime>(
      valueListenable: yearNotifier,
      builder: (context, visibleYear, _) {
        final y = visibleYear.year;
        return BlocBuilder<YearlyDashboardCubit, YearlyDashboardState>(
          builder: (context, state) {
            return ShellScaffold(
              title: l10n.yearlyDashboard,
              appBarBottom: YearlyDashboardAppBarBottom(notifier: yearNotifier),
              appBarActionsBeforeSettings: switch (state) {
                YearlyDashboardLoaded() => <Widget>[
                  IconButton(
                    icon: const Icon(AppIcons.filter),
                    tooltip: l10n.monthlyDashboardConfigureTooltip,
                    onPressed: () => showDashboardViewOptionsBottomSheet(
                      context: context,
                      l10n: l10n,
                      includeIgnored: _includeIgnored,
                      useWeightedAmounts: _useWeightedAmounts,
                      showCredits: _showCredits,
                      onApply: (inc, wt, credits) => setState(() {
                        _includeIgnored = inc;
                        _useWeightedAmounts = wt;
                        _showCredits = credits;
                      }),
                    ),
                  ),
                ],
                _ => null,
              },
              body: switch (state) {
                YearlyDashboardInitial() || YearlyDashboardLoading() =>
                  const Center(child: CircularProgressIndicator()),
                YearlyDashboardError(:final failure) => RemoteLoadFailurePanel(
                  l10n: l10n,
                  failure: failure,
                  onRetry: () => context.read<YearlyDashboardCubit>().loadYear(
                    visibleYear,
                  ),
                ),
                YearlyDashboardLoaded(
                  :final transactions,
                  :final recurringMonthlyIncome,
                  :final recurringMonthlyOutcome,
                  :final recurringMonthlyNet,
                  :final servedFromOfflineCache,
                ) =>
                  _yearlyBody(
                    context,
                    l10n,
                    visibleYear,
                    y: y,
                    transactions: transactions,
                    recurringMonthlyIncome: recurringMonthlyIncome,
                    recurringMonthlyOutcome: recurringMonthlyOutcome,
                    recurringMonthlyNet: recurringMonthlyNet,
                    servedFromOfflineCache: servedFromOfflineCache,
                  ),
              },
            );
          },
        );
      },
    );
  }

  Widget _yearlyBody(
    BuildContext context,
    AppLocalizations l10n,
    DateTime visibleYear, {
    required int y,
    required List<TransactionEntity> transactions,
    required double recurringMonthlyIncome,
    required double recurringMonthlyOutcome,
    required double recurringMonthlyNet,
    required bool servedFromOfflineCache,
  }) {
    final yearTxs = _filterCredits(_transactionsInYear(transactions, y));
    final categoryFilter = pruneCategoryKeysFilter(
      yearTxs,
      _includeIgnored,
      _categoryKeysFilter,
      _useWeightedAmounts,
    );
    final tagFilter = pruneTagKeysFilter(
      yearTxs,
      _includeIgnored,
      _tagKeysFilter,
      _useWeightedAmounts,
    );
    if (!setEquals(tagFilter, _tagKeysFilter) ||
        !setEquals(categoryFilter, _categoryKeysFilter)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() {
          _tagKeysFilter = tagFilter;
          _categoryKeysFilter = categoryFilter;
        });
      });
    }

    return RefreshIndicator(
      onRefresh: () =>
          context.read<YearlyDashboardCubit>().loadYear(visibleYear),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        children: [
          OfflineCachedDataBanner(visible: servedFromOfflineCache),
          YearlyCumulativeNetBarChart(
            l10n: l10n,
            year: y,
            transactions: transactions,
            recurringMonthlyNet: recurringMonthlyNet,
          ),
          YearlyWeightedNetBarChart(
            l10n: l10n,
            year: y,
            transactions: _filterCredits(transactions),
            includeIgnored: _includeIgnored,
            useWeightedAmounts: _useWeightedAmounts,
            recurringMonthlyNet: recurringMonthlyNet,
          ),
          YearlyWeightedIncomeBarChart(
            l10n: l10n,
            year: y,
            transactions: _filterCredits(transactions),
            includeIgnored: _includeIgnored,
            useWeightedAmounts: _useWeightedAmounts,
            recurringMonthlyIncome: recurringMonthlyIncome,
          ),
          YearlyWeightedOutcomeBarChart(
            l10n: l10n,
            year: y,
            transactions: _filterCredits(transactions),
            includeIgnored: _includeIgnored,
            useWeightedAmounts: _useWeightedAmounts,
            recurringMonthlyOutcome: recurringMonthlyOutcome,
          ),
          MonthlyTagPieChart(
            l10n: l10n,
            transactions: _filterByCategory(yearTxs, categoryFilter),
            includeIgnored: _includeIgnored,
            useWeightedAmounts: _useWeightedAmounts,
            tagKeysFilter: tagFilter,
            onTagKeysFilterChanged: (v) => setState(() {
              _tagKeysFilter = v;
              if (v == null) _categoryKeysFilter = null;
            }),
          ),
          MonthlyCategoryExpensePieChart(
            l10n: l10n,
            transactions: _filterByTag(yearTxs, tagFilter),
            includeIgnored: _includeIgnored,
            useWeightedAmounts: _useWeightedAmounts,
            categoryKeysFilter: categoryFilter,
            onCategoryKeysFilterChanged: (v) =>
                setState(() => _categoryKeysFilter = v),
          ),
          _YearTransactionsList(
            l10n: l10n,
            year: y,
            transactions: _transactionsForList(
              yearTxs,
              tagFilter,
              categoryFilter,
            ),
            useWeightedAmounts: _useWeightedAmounts,
            onLedgerChanged: () => context
                .read<YearlyDashboardCubit>()
                .loadYear(DateTime(y, 1, 1)),
          ),
        ],
      ),
    );
  }
}

/// Transactions already recorded in [year], grouped by day. Pie filters narrow it
/// to where that money went. Days with no rows are omitted.
class _YearTransactionsList extends StatelessWidget {
  const _YearTransactionsList({
    required this.l10n,
    required this.year,
    required this.transactions,
    required this.useWeightedAmounts,
    required this.onLedgerChanged,
  });

  final AppLocalizations l10n;
  final int year;
  final List<TransactionEntity> transactions;
  final bool useWeightedAmounts;
  final VoidCallback onLedgerChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final rows = groupedTransactionsForList(transactions);
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
        if (rows.isEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 16),
            child: Text(
              l10n.noTransactionsInMonth('$year'),
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          )
        else
          for (final row in rows)
            switch (row) {
              GroupedTxnDayMarker(:final day) => GroupedTxnDayHeader(day: day),
              GroupedTxnEmptyDayMarker() => GroupedTxnEmptyDayLabel(l10n: l10n),
              GroupedTxnTxMarker(:final transaction) =>
                GroupedTxnTransactionTile(
                  transaction: transaction,
                  l10n: l10n,
                  useWeightedAmounts: useWeightedAmounts,
                  onLedgerChanged: onLedgerChanged,
                ),
              GroupedTxnTransferPairMarker(:final source, :final target) =>
                GroupedTxnTransferPairTile(
                  source: source,
                  target: target,
                  l10n: l10n,
                  onLedgerChanged: onLedgerChanged,
                ),
            },
      ],
    );
  }
}
