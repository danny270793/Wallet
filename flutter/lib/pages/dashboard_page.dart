import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:wallet/l10n/app_localizations.dart';

import '../core/di/injection.dart';
import '../features/transactions/domain/entities/transaction_entity.dart';
import '../features/transactions/presentation/cubit/transactions_cubit.dart';
import '../features/transactions/presentation/cubit/transactions_state.dart';
import '../widgets/dashboard_month_transactions_list.dart';
import '../widgets/monthly_category_expense_pie_chart.dart';
import '../widgets/monthly_tag_pie_chart.dart';
import '../widgets/shell_scaffold.dart';
import '../widgets/transaction_month_totals.dart';
import '../widgets/transactions_month_scope.dart';
import '../widgets/transactions_totals_bar.dart';
import 'transactions_page.dart'
    show
        TransactionsExpandableFab,
        showAccountTransferCreateBottomSheet,
        showTransactionEditorBottomSheet;

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => getIt<TransactionsCubit>(),
      child: TransactionsMonthHost(
        child: TransactionsMonthCubitSync(child: const _MonthlyDashboardView()),
      ),
    );
  }
}

class _MonthlyDashboardView extends StatefulWidget {
  const _MonthlyDashboardView();

  @override
  State<_MonthlyDashboardView> createState() => _MonthlyDashboardViewState();
}

class _MonthlyDashboardViewState extends State<_MonthlyDashboardView> {
  /// When true, ignored rows count toward income/outcome/balance (account/card transfer legs are always excluded).
  bool _includeIgnored = true;

  /// When true, list row amounts mirror `value × percentage`; when false, full row value.
  bool _useWeightedAmounts = true;

  bool _fabMenuOpen = false;

  /// Same semantics as [MonthlyTagPieChart.tagKeysFilter]: null = all tags.
  Set<String>? _tagKeysFilter;

  /// Same semantics as [MonthlyCategoryExpensePieChart.categoryKeysFilter]: null = all categories.
  Set<String>? _categoryKeysFilter;

  List<TransactionEntity> _monthTransactions(TransactionsState state) {
    return switch (state) {
      TransactionsLoaded(:final transactions) => transactions,
      TransactionsActionError(:final transactions) => transactions,
      _ => <TransactionEntity>[],
    };
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

  /// Respects [_includeIgnored] and optional tag/category pie filters.
  List<TransactionEntity> _transactionsForDashboardList(
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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final monthNotifier = TransactionsMonthScope.of(context);

    return BlocConsumer<TransactionsCubit, TransactionsState>(
      listener: (context, state) {
        final msg = switch (state) {
          TransactionsError(:final message) => message,
          TransactionsActionError(:final message) => message,
          _ => null,
        };
        if (msg != null && msg.isNotEmpty) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(msg)));
        }
      },
      builder: (context, state) {
        final txs = _monthTransactions(state);
        // Prune filters using the same ignored basis as pies and list.
        var categoryFilter = pruneCategoryKeysFilter(
          txs,
          _includeIgnored,
          _categoryKeysFilter,
          _useWeightedAmounts,
        );
        var tagFilter = pruneTagKeysFilter(
          _filterByCategory(txs, categoryFilter),
          _includeIgnored,
          _tagKeysFilter,
          _useWeightedAmounts,
        );
        categoryFilter = pruneCategoryKeysFilter(
          _filterByTag(txs, tagFilter),
          _includeIgnored,
          _categoryKeysFilter,
          _useWeightedAmounts,
        );
        tagFilter = pruneTagKeysFilter(
          _filterByCategory(txs, categoryFilter),
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
        final tagPieTxs = _filterByCategory(txs, categoryFilter);
        final categoryPieTxs = _filterByTag(txs, tagFilter);
        final listTxs = _transactionsForDashboardList(
          txs,
          tagFilter,
          categoryFilter,
        );

        // Income / outcome / balance for the same filtered set as the charts and list below.
        final dashboardViewTotals = transactionMonthTotalsBreakdown(
          listTxs,
          include: (_) => true,
          amount: _useWeightedAmounts
              ? (t) => t.value * t.percentage / 100.0
              : (t) => t.value,
        );

        final showBar =
            state is TransactionsLoaded || state is TransactionsActionError;

        final preferredTagId = tagFilter != null && tagFilter.length == 1
            ? tagFilter.first
            : null;
        final preferredCategoryId =
            categoryFilter != null && categoryFilter.length == 1
            ? categoryFilter.first
            : null;
        final cubit = context.read<TransactionsCubit>();

        return ShellScaffold(
          title: l10n.monthlyDashboard,
          appBarBottom: TransactionsMonthAppBarBottom(notifier: monthNotifier),
          bottomNavigationBar: showBar
              ? TransactionsTotalsBar(
                  l10n: l10n,
                  income: dashboardViewTotals.income,
                  outcome: dashboardViewTotals.outcome,
                  balance: dashboardViewTotals.balance,
                )
              : null,
          floatingActionButton: showBar
              ? TransactionsExpandableFab(
                  l10n: l10n,
                  isOpen: _fabMenuOpen,
                  onOpenChanged: (v) => setState(() => _fabMenuOpen = v),
                  transferHeroTag: 'dashboard_fab_transfer',
                  newTransactionHeroTag: 'dashboard_fab_new',
                  toggleHeroTag: 'dashboard_fab_toggle',
                  onNewTransaction: () => showTransactionEditorBottomSheet(
                    context,
                    l10n: l10n,
                    cubit: cubit,
                    preferredCategoryId: preferredCategoryId,
                    preferredTagId: preferredTagId,
                  ),
                  onTransfer: () =>
                      showAccountTransferCreateBottomSheet(context, l10n: l10n),
                )
              : null,
          body: _body(
            context,
            state,
            l10n,
            monthNotifier,
            tagFilter,
            categoryFilter,
            tagPieTxs,
            categoryPieTxs,
            listTxs,
          ),
        );
      },
    );
  }

  Widget _body(
    BuildContext context,
    TransactionsState state,
    AppLocalizations l10n,
    ValueNotifier<DateTime> monthNotifier,
    Set<String>? tagKeysFilter,
    Set<String>? categoryKeysFilter,
    List<TransactionEntity> tagPieTransactions,
    List<TransactionEntity> categoryPieTransactions,
    List<TransactionEntity> listTransactions,
  ) {
    Future<void> pullRefresh() =>
        context.read<TransactionsCubit>().loadForMonth(
              monthNotifier.value,
              showLoading: false,
            );

    Future<void> reloadWithOverlay() =>
        context.read<TransactionsCubit>().loadForMonth(
              monthNotifier.value,
              showLoading: true,
            );

    final visibleMonth = monthNotifier.value;

    if (state is TransactionsLoading || state is TransactionsInitial) {
      return RefreshIndicator(
        onRefresh: pullRefresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            SizedBox(
              height: MediaQuery.sizeOf(context).height * 0.35,
              child: const Center(child: CircularProgressIndicator()),
            ),
          ],
        ),
      );
    }

    if (state is TransactionsError) {
      return RefreshIndicator(
        onRefresh: pullRefresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            SizedBox(
              height: MediaQuery.sizeOf(context).height * 0.35,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(state.message ?? l10n.unexpectedError),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: reloadWithOverlay,
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: pullRefresh,
      child: Stack(
        fit: StackFit.expand,
        children: [
          IgnorePointer(
            ignoring: _fabMenuOpen,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              children: [
                SwitchListTile(
                  title: Text(l10n.dashboardIncludeIgnoredInTotals),
                  value: _includeIgnored,
                  onChanged: (v) => setState(() => _includeIgnored = v),
                ),
                SwitchListTile(
                  title: Text(l10n.dashboardUseWeightedAmounts),
                  value: _useWeightedAmounts,
                  onChanged: (v) => setState(() => _useWeightedAmounts = v),
                ),
                MonthlyTagPieChart(
                  l10n: l10n,
                  transactions: tagPieTransactions,
                  includeIgnored: _includeIgnored,
                  useWeightedAmounts: _useWeightedAmounts,
                  tagKeysFilter: tagKeysFilter,
                  onTagKeysFilterChanged: (v) =>
                      setState(() => _tagKeysFilter = v),
                ),
                MonthlyCategoryExpensePieChart(
                  l10n: l10n,
                  transactions: categoryPieTransactions,
                  includeIgnored: _includeIgnored,
                  useWeightedAmounts: _useWeightedAmounts,
                  categoryKeysFilter: categoryKeysFilter,
                  onCategoryKeysFilterChanged: (v) =>
                      setState(() => _categoryKeysFilter = v),
                ),
                DashboardMonthTransactionsList(
                  l10n: l10n,
                  transactions: listTransactions,
                  visibleMonth: visibleMonth,
                  useWeightedAmounts: _useWeightedAmounts,
                ),
              ],
            ),
          ),
          if (_fabMenuOpen)
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => setState(() => _fabMenuOpen = false),
                child: const ColoredBox(color: Colors.transparent),
              ),
            ),
        ],
      ),
    );
  }
}
