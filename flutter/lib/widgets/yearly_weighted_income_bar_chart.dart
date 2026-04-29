import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:wallet/l10n/app_localizations.dart';

import '../features/transactions/domain/entities/transaction_entity.dart';

double _weighted(TransactionEntity t) => t.value * t.percentage / 100.0;

double _effectiveAmount(TransactionEntity t, bool useWeightedAmounts) =>
    useWeightedAmounts ? _weighted(t) : t.value;

/// Latest calendar month in [year] (1–12) that has at least one counted transaction,
/// or 0 if none. Uses local dates; respects [includeIgnored] the same as other yearly charts.
int lastMonthWithTransactionsForYear(
  List<TransactionEntity> txs,
  int year, {
  required bool includeIgnored,
}) {
  var last = 0;
  for (final t in txs) {
    if (t.isAccountTransferLeg) continue;
    if (!includeIgnored && t.ignore) continue;
    final local = t.transactedAt.toLocal();
    if (local.year != year) continue;
    final m = local.month;
    if (m > last) last = m;
  }
  return last;
}

/// Per calendar month (local), sum of positive effective amounts.
/// When [useWeightedAmounts] is true, amounts are `value × percentage`; otherwise raw [TransactionEntity.value].
List<double> weightedIncomeByMonthForYear(
  List<TransactionEntity> txs,
  int year, {
  required bool includeIgnored,
  required bool useWeightedAmounts,
}) {
  final sums = List<double>.filled(12, 0);
  for (final t in txs) {
    if (t.isAccountTransferLeg) continue;
    if (!includeIgnored && t.ignore) continue;
    final local = t.transactedAt.toLocal();
    if (local.year != year) continue;
    final w = _effectiveAmount(t, useWeightedAmounts);
    if (w > 0) sums[local.month - 1] += w;
  }
  return sums;
}

/// Per calendar month (local), sum of absolute negative effective amounts (outcome / outflow).
List<double> weightedOutcomeByMonthForYear(
  List<TransactionEntity> txs,
  int year, {
  required bool includeIgnored,
  required bool useWeightedAmounts,
}) {
  final sums = List<double>.filled(12, 0);
  for (final t in txs) {
    if (t.isAccountTransferLeg) continue;
    if (!includeIgnored && t.ignore) continue;
    final local = t.transactedAt.toLocal();
    if (local.year != year) continue;
    final w = _effectiveAmount(t, useWeightedAmounts);
    if (w < 0) sums[local.month - 1] += -w;
  }
  return sums;
}

/// Per calendar month (local), net effective amount (sum of signed values).
List<double> weightedNetByMonthForYear(
  List<TransactionEntity> txs,
  int year, {
  required bool includeIgnored,
  required bool useWeightedAmounts,
}) {
  final sums = List<double>.filled(12, 0);
  for (final t in txs) {
    if (t.isAccountTransferLeg) continue;
    if (!includeIgnored && t.ignore) continue;
    final local = t.transactedAt.toLocal();
    if (local.year != year) continue;
    sums[local.month - 1] += _effectiveAmount(t, useWeightedAmounts);
  }
  return sums;
}

/// Running sum of [weightedNetByMonthForYear] from January through each month (YTD net in year).
List<double> weightedCumulativeNetByMonthForYear(
  List<TransactionEntity> txs,
  int year, {
  required bool includeIgnored,
  required bool useWeightedAmounts,
}) {
  final monthly = weightedNetByMonthForYear(
    txs,
    year,
    includeIgnored: includeIgnored,
    useWeightedAmounts: useWeightedAmounts,
  );
  final out = List<double>.filled(12, 0);
  var sum = 0.0;
  for (var i = 0; i < 12; i++) {
    sum += monthly[i];
    out[i] = sum;
  }
  return out;
}

/// Cumulative YTD values for Jan through [lastMonthWithTransactionsForYear], then zeros so the
/// chart keeps 12 month slots like the net chart but shows no bar after the last month with data.
List<double> _cumulativeNetMonthlyBarsWithTrailingZeros(
  List<TransactionEntity> txs,
  int year, {
  required bool includeIgnored,
  required bool useWeightedAmounts,
}) {
  final full = weightedCumulativeNetByMonthForYear(
    txs,
    year,
    includeIgnored: includeIgnored,
    useWeightedAmounts: useWeightedAmounts,
  );
  final last = lastMonthWithTransactionsForYear(
    txs,
    year,
    includeIgnored: includeIgnored,
  );
  if (last == 0) return full;
  return List<double>.generate(12, (i) => i < last ? full[i] : 0.0);
}

/// Bar chart: monthly weighted income for [year] from [transactions].
class YearlyWeightedIncomeBarChart extends StatelessWidget {
  const YearlyWeightedIncomeBarChart({
    super.key,
    required this.l10n,
    required this.year,
    required this.transactions,
    required this.includeIgnored,
    required this.useWeightedAmounts,
  });

  final AppLocalizations l10n;
  final int year;
  final List<TransactionEntity> transactions;
  final bool includeIgnored;
  final bool useWeightedAmounts;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final monthly = weightedIncomeByMonthForYear(
      transactions,
      year,
      includeIgnored: includeIgnored,
      useWeightedAmounts: useWeightedAmounts,
    );
    return _YearlyMonthlyBarChartCore(
      l10n: l10n,
      year: year,
      monthly: monthly,
      title: l10n.yearlyDashboardIncomeByMonthTitle,
      barColor: scheme.primary,
      kind: _YearlyBarKind.income,
    );
  }
}

/// Bar chart: monthly weighted outcome (expenses) for [year] from [transactions].
class YearlyWeightedOutcomeBarChart extends StatelessWidget {
  const YearlyWeightedOutcomeBarChart({
    super.key,
    required this.l10n,
    required this.year,
    required this.transactions,
    required this.includeIgnored,
    required this.useWeightedAmounts,
  });

  final AppLocalizations l10n;
  final int year;
  final List<TransactionEntity> transactions;
  final bool includeIgnored;
  final bool useWeightedAmounts;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final monthly = weightedOutcomeByMonthForYear(
      transactions,
      year,
      includeIgnored: includeIgnored,
      useWeightedAmounts: useWeightedAmounts,
    );
    return _YearlyMonthlyBarChartCore(
      l10n: l10n,
      year: year,
      monthly: monthly,
      title: l10n.yearlyDashboardOutcomeByMonthTitle,
      barColor: scheme.error,
      kind: _YearlyBarKind.outcome,
    );
  }
}

/// Bar chart: monthly net (income − outcome) for [year] from [transactions].
class YearlyWeightedNetBarChart extends StatelessWidget {
  const YearlyWeightedNetBarChart({
    super.key,
    required this.l10n,
    required this.year,
    required this.transactions,
    required this.includeIgnored,
    required this.useWeightedAmounts,
  });

  final AppLocalizations l10n;
  final int year;
  final List<TransactionEntity> transactions;
  final bool includeIgnored;
  final bool useWeightedAmounts;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final monthly = weightedNetByMonthForYear(
      transactions,
      year,
      includeIgnored: includeIgnored,
      useWeightedAmounts: useWeightedAmounts,
    );
    return _YearlyMonthlyBarChartCore(
      l10n: l10n,
      year: year,
      monthly: monthly,
      title: l10n.yearlyDashboardNetByMonthTitle,
      barColor: scheme.primary,
      kind: _YearlyBarKind.net,
    );
  }
}

/// Bar chart: cumulative net (signed weighted sum YTD) at end of each month.
class YearlyCumulativeNetBarChart extends StatelessWidget {
  const YearlyCumulativeNetBarChart({
    super.key,
    required this.l10n,
    required this.year,
    required this.transactions,
    required this.includeIgnored,
    required this.useWeightedAmounts,
  });

  final AppLocalizations l10n;
  final int year;
  final List<TransactionEntity> transactions;
  final bool includeIgnored;
  final bool useWeightedAmounts;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final monthly = _cumulativeNetMonthlyBarsWithTrailingZeros(
      transactions,
      year,
      includeIgnored: includeIgnored,
      useWeightedAmounts: useWeightedAmounts,
    );
    return _YearlyMonthlyBarChartCore(
      l10n: l10n,
      year: year,
      monthly: monthly,
      title: l10n.yearlyDashboardCumulativeByMonthTitle,
      barColor: scheme.primary,
      kind: _YearlyBarKind.net,
    );
  }
}

enum _YearlyBarKind { income, outcome, net }

class _YearlyMonthlyBarChartCore extends StatelessWidget {
  const _YearlyMonthlyBarChartCore({
    required this.l10n,
    required this.year,
    required this.monthly,
    required this.title,
    required this.barColor,
    required this.kind,
  });

  final AppLocalizations l10n;
  final int year;
  final List<double> monthly;
  final String title;
  final Color barColor;
  final _YearlyBarKind kind;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final locale = Localizations.localeOf(context).toString();
    final monthCount = monthly.length;

    final rodToY = switch (kind) {
      _YearlyBarKind.income => List<double>.from(monthly),
      _YearlyBarKind.outcome => monthly.map((m) => m == 0 ? 0.0 : -m).toList(),
      _YearlyBarKind.net => List<double>.from(monthly),
    };

    late final double minY;
    late final double maxY;
    late final double gridInterval;

    if (kind == _YearlyBarKind.income) {
      minY = 0;
      final maxVal = rodToY.reduce((a, b) => a > b ? a : b);
      maxY = maxVal <= 0 ? 1.0 : maxVal * 1.15;
      gridInterval = maxY > 0 ? (maxY / 4).clamp(0.25, double.infinity) : 0.25;
    } else if (kind == _YearlyBarKind.outcome) {
      final minVal = rodToY.reduce((a, b) => a < b ? a : b);
      if (minVal == 0 && rodToY.every((v) => v == 0)) {
        minY = -1.0;
        maxY = 0.25;
        gridInterval = 0.25;
      } else {
        maxY = 0;
        minY = minVal * 1.15;
        final span = maxY - minY;
        gridInterval = span > 0
            ? (span / 4).clamp(0.25, double.infinity)
            : 0.25;
      }
    } else {
      var maxPos = 0.0;
      var minNeg = 0.0;
      for (final v in rodToY) {
        if (v > maxPos) maxPos = v;
        if (v < minNeg) minNeg = v;
      }
      if (maxPos == 0 && minNeg == 0) {
        minY = -1.0;
        maxY = 1.0;
        gridInterval = 0.5;
      } else {
        var top = maxPos > 0 ? maxPos * 1.15 : 0.0;
        var bottom = minNeg < 0 ? minNeg * 1.15 : 0.0;
        if (top > 0 && bottom == 0) bottom = -top * 0.05;
        if (bottom < 0 && top == 0) top = -bottom * 0.05;
        maxY = top;
        minY = bottom;
        final span = maxY - minY;
        gridInterval = span > 0
            ? (span / 4).clamp(0.25, double.infinity)
            : 0.25;
      }
    }

    final monthLabels = List.generate(
      monthCount,
      (i) => DateFormat.MMM(locale).format(DateTime(year, i + 1, 1)),
    );

    BorderRadius barRadiusForIndex(int i) {
      if (kind == _YearlyBarKind.net) {
        final v = rodToY[i];
        if (v > 0) return const BorderRadius.vertical(top: Radius.circular(4));
        if (v < 0)
          return const BorderRadius.vertical(bottom: Radius.circular(4));
        return BorderRadius.circular(2);
      }
      return kind == _YearlyBarKind.income
          ? const BorderRadius.vertical(top: Radius.circular(4))
          : const BorderRadius.vertical(bottom: Radius.circular(4));
    }

    Color barColorForIndex(int i) {
      if (kind == _YearlyBarKind.net) {
        final v = rodToY[i];
        if (v < 0) return scheme.error;
        return scheme.primary;
      }
      return barColor;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 248,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                minY: minY,
                maxY: maxY,
                barTouchData: BarTouchData(
                  enabled: true,
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      final v = rod.toY;
                      return BarTooltipItem(
                        '${monthLabels[group.x.toInt()]}\n${l10n.transactionAmountValue(v.toStringAsFixed(2))}',
                        theme.textTheme.bodySmall!.copyWith(
                          color: scheme.onInverseSurface,
                          fontWeight: FontWeight.w600,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      );
                    },
                  ),
                ),
                titlesData: FlTitlesData(
                  show: true,
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 28,
                      getTitlesWidget: (value, meta) {
                        final i = value.toInt();
                        if (i < 0 || i >= monthCount)
                          return const SizedBox.shrink();
                        return Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            monthLabels[i],
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                              fontFeatures: const [
                                FontFeature.tabularFigures(),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 44,
                      interval: gridInterval,
                      getTitlesWidget: (value, meta) {
                        if (value < minY * 1.001 - 1e-9 ||
                            value > maxY * 1.001 + 1e-9) {
                          return const SizedBox.shrink();
                        }
                        final label = value == value.roundToDouble()
                            ? value.toInt().toString()
                            : value.toStringAsFixed(1);
                        return Text(
                          label,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        );
                      },
                    ),
                  ),
                ),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: gridInterval,
                  getDrawingHorizontalLine: (value) => FlLine(
                    color: scheme.outlineVariant.withValues(alpha: 0.5),
                    strokeWidth: 1,
                  ),
                ),
                borderData: FlBorderData(show: false),
                barGroups: List.generate(
                  monthCount,
                  (i) => BarChartGroupData(
                    x: i,
                    barRods: [
                      BarChartRodData(
                        toY: rodToY[i],
                        color: barColorForIndex(i),
                        width: 14,
                        borderRadius: barRadiusForIndex(i),
                        label: BarChartRodLabel(
                          show: rodToY[i].abs() >= 1e-9,
                          text: l10n.transactionAmountValue(
                            rodToY[i].toStringAsFixed(2),
                          ),
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: scheme.onSurface,
                            fontWeight: FontWeight.w600,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
