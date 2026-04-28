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

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => getIt<TransactionsCubit>(),
      child: TransactionsMonthHost(
        child: TransactionsMonthCubitSync(
          child: const _MonthlyDashboardView(),
        ),
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
  /// When true, ignored rows count toward income/outcome/balance (matches transactions totals default).
  bool _includeIgnored = true;

  /// Same semantics as [MonthlyTagPieChart.tagKeysFilter]: null = all tags.
  Set<String>? _tagKeysFilter;

  List<TransactionEntity> _monthTransactions(TransactionsState state) {
    return switch (state) {
      TransactionsLoaded(:final transactions) => transactions,
      TransactionsActionError(:final transactions) => transactions,
      _ => <TransactionEntity>[],
    };
  }

  List<TransactionEntity> _transactionsForTagList(
    List<TransactionEntity> txs,
    Set<String>? tagKeysFilter,
  ) {
    if (tagKeysFilter == null) return txs;
    return txs.where((t) {
      if (!_includeIgnored && t.ignore) return false;
      final id = t.tagId;
      return id != null && id.isNotEmpty && tagKeysFilter.contains(id);
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
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
        }
      },
      builder: (context, state) {
        final txs = _monthTransactions(state);
        final tagFilter = pruneTagKeysFilter(txs, _includeIgnored, _tagKeysFilter);
        if (!setEquals(tagFilter, _tagKeysFilter)) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            setState(() => _tagKeysFilter = tagFilter);
          });
        }
        final listTxs = _transactionsForTagList(txs, tagFilter);
        final showBar = state is TransactionsLoaded || state is TransactionsActionError;

        double weighted(TransactionEntity t) => t.value * t.percentage / 100.0;
        final totals = transactionMonthTotalsBreakdown(
          txs,
          include: _includeIgnored ? (_) => true : (t) => !t.ignore,
          amount: weighted,
        );

        Future<void> refresh() =>
            context.read<TransactionsCubit>().loadForMonth(monthNotifier.value);

        return ShellScaffold(
          title: l10n.monthlyDashboard,
          appBarBottom: TransactionsMonthAppBarBottom(notifier: monthNotifier),
          bottomNavigationBar: showBar
              ? TransactionsTotalsBar(
                  l10n: l10n,
                  income: totals.income,
                  outcome: totals.outcome,
                  balance: totals.balance,
                )
              : null,
          body: _body(
            context,
            state,
            l10n,
            refresh,
            monthNotifier.value,
            tagFilter,
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
    Future<void> Function() refresh,
    DateTime visibleMonth,
    Set<String>? tagKeysFilter,
    List<TransactionEntity> listTransactions,
  ) {
    if (state is TransactionsLoading || state is TransactionsInitial) {
      return RefreshIndicator(
        onRefresh: refresh,
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
        onRefresh: refresh,
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
                      onPressed: refresh,
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
      onRefresh: refresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        children: [
          SwitchListTile(
            title: Text(l10n.dashboardIncludeIgnoredInTotals),
            value: _includeIgnored,
            onChanged: (v) => setState(() => _includeIgnored = v),
          ),
          if (!_includeIgnored)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text(
                l10n.transactionsTotalsExcludingIgnoredHint,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            ),
          MonthlyTagPieChart(
            l10n: l10n,
            transactions: _monthTransactions(state),
            includeIgnored: _includeIgnored,
            tagKeysFilter: tagKeysFilter,
            onTagKeysFilterChanged: (v) => setState(() => _tagKeysFilter = v),
          ),
          MonthlyCategoryExpensePieChart(
            l10n: l10n,
            transactions: listTransactions,
            includeIgnored: _includeIgnored,
          ),
          DashboardMonthTransactionsList(
            l10n: l10n,
            transactions: listTransactions,
            visibleMonth: visibleMonth,
          ),
        ],
      ),
    );
  }
}
