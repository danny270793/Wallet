import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:wallet/l10n/app_localizations.dart';

import '../core/di/injection.dart';
import '../features/transactions/presentation/cubit/yearly_dashboard_cubit.dart';
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

  /// When true, ignored rows count toward monthly income bars (matches monthly dashboard switch).
  bool _includeIgnored = true;

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
              body: switch (state) {
                YearlyDashboardInitial() || YearlyDashboardLoading() => const Center(
                    child: CircularProgressIndicator(),
                  ),
                YearlyDashboardError(:final message) => Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(message ?? l10n.unexpectedError, textAlign: TextAlign.center),
                          const SizedBox(height: 16),
                          FilledButton(
                            onPressed: () =>
                                context.read<YearlyDashboardCubit>().loadYear(visibleYear),
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    ),
                  ),
                YearlyDashboardLoaded(:final transactions) => RefreshIndicator(
                    onRefresh: () => context.read<YearlyDashboardCubit>().loadYear(visibleYear),
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
                        YearlyWeightedIncomeBarChart(
                          l10n: l10n,
                          year: y,
                          transactions: transactions,
                          includeIgnored: _includeIgnored,
                        ),
                        YearlyWeightedOutcomeBarChart(
                          l10n: l10n,
                          year: y,
                          transactions: transactions,
                          includeIgnored: _includeIgnored,
                        ),
                        YearlyWeightedNetBarChart(
                          l10n: l10n,
                          year: y,
                          transactions: transactions,
                          includeIgnored: _includeIgnored,
                        ),
                        YearlyCumulativeNetBarChart(
                          l10n: l10n,
                          year: y,
                          transactions: transactions,
                          includeIgnored: _includeIgnored,
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
