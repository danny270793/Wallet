import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:wallet/l10n/app_localizations.dart';

import '../core/di/injection.dart';
import '../core/ui/app_icons.dart';
import '../features/transactions/domain/entities/transaction_entity.dart';
import '../features/transactions/presentation/cubit/yearly_dashboard_cubit.dart';
import '../widgets/dashboard_view_options_bottom_sheet.dart';
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
      child: BlocProvider(
        create: (_) => getIt<YearlyDashboardCubit>(),
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
                  onRetry: () => context
                      .read<YearlyDashboardCubit>()
                      .loadYear(visibleYear),
                ),
                YearlyDashboardLoaded(:final transactions, :final servedFromOfflineCache) => RefreshIndicator(
                  onRefresh: () => context
                      .read<YearlyDashboardCubit>()
                      .loadYear(visibleYear),
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 8,
                    ),
                    children: [
                      OfflineCachedDataBanner(visible: servedFromOfflineCache),
                      YearlyCumulativeNetBarChart(
                        l10n: l10n,
                        year: y,
                        transactions: _filterCredits(transactions),
                      ),
                      YearlyWeightedNetBarChart(
                        l10n: l10n,
                        year: y,
                        transactions: _filterCredits(transactions),
                        includeIgnored: _includeIgnored,
                        useWeightedAmounts: _useWeightedAmounts,
                      ),
                      YearlyWeightedIncomeBarChart(
                        l10n: l10n,
                        year: y,
                        transactions: _filterCredits(transactions),
                        includeIgnored: _includeIgnored,
                        useWeightedAmounts: _useWeightedAmounts,
                      ),
                      YearlyWeightedOutcomeBarChart(
                        l10n: l10n,
                        year: y,
                        transactions: _filterCredits(transactions),
                        includeIgnored: _includeIgnored,
                        useWeightedAmounts: _useWeightedAmounts,
                      ),
                    ],
                  ),
                ),
              },
            );
          },
        );
      },
    );
  }
}
