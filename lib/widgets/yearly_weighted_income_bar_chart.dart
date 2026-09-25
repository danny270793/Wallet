import 'dart:math' as math;

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

/// Latest month in [year] (1–12) with at least one transaction that has an [TransactionEntity.accountId]
/// (same scope as `/accounts` balances), or 0 if none.
int lastMonthWithAccountTransactionsForYear(
  List<TransactionEntity> txs,
  int year,
) {
  var last = 0;
  for (final t in txs) {
    if (t.accountId == null || t.accountId!.isEmpty) continue;
    final local = t.transactedAt.toLocal();
    if (local.year != year) continue;
    final m = local.month;
    if (m > last) last = m;
  }
  return last;
}

/// Cumulative **accounts total** at end of each month in [year]: for month *m*,
/// sums every non-deleted row in [txs] with a non-null [TransactionEntity.accountId]
/// and `transactedAt` strictly before the first day of month *m*+1, **including
/// years before [year]**.
///
/// Matches `wallet_accounts_with_balance` aggregated across all accounts (footer
/// total on `/accounts`) when [txs] includes full history through the end of [year].
List<double> accountsTotalCumulativeByMonthForYear(
  List<TransactionEntity> txs,
  int year,
) {
  final out = List<double>.filled(12, 0);
  for (var m = 0; m < 12; m++) {
    final cutoffExclusive = DateTime(year, m + 2, 1);
    var sum = 0.0;
    for (final t in txs) {
      if (t.accountId == null || t.accountId!.isEmpty) continue;
      final local = t.transactedAt.toLocal();
      if (!local.isBefore(cutoffExclusive)) continue;
      sum += t.value;
    }
    out[m] = sum;
  }
  return out;
}

/// First month index (0–11) of [year] that is estimated: months after the current
/// one. 12 for past years (nothing estimated), 0 for future years.
int _firstEstimatedMonthIndex(int year, DateTime today) {
  if (year < today.year) return 12;
  if (year > today.year) return 0;
  return today.month;
}

/// Month-end accounts totals for [year], with a flag for where estimates begin.
///
/// Every month uses the real running balance from
/// [accountsTotalCumulativeByMonthForYear], which already includes transactions
/// scheduled in the future (e.g. credit installments). Months after the current one
/// additionally add [recurringMonthlyNet] once per month elapsed since the current
/// month, as an estimate of the regular money flow.
///
/// [projectedFromIndex] is the first estimated month index (0–11), or 12 when none.
({List<double> monthly, int projectedFromIndex})
cumulativeAccountsBalanceWithProjection(
  List<TransactionEntity> txs,
  int year, {
  required double recurringMonthlyNet,
  DateTime? now,
}) {
  final today = now ?? DateTime.now();
  final from = _firstEstimatedMonthIndex(year, today);
  final real = accountsTotalCumulativeByMonthForYear(txs, year);
  // Recurring months already elapsed before Jan of [year] (future years only).
  final monthsBeforeYear = year > today.year
      ? (year - today.year) * 12 - today.month
      : 0;
  return (
    monthly: List<double>.generate(
      12,
      (i) => i < from
          ? real[i]
          : real[i] + recurringMonthlyNet * (monthsBeforeYear + i - from + 1),
    ),
    projectedFromIndex: from,
  );
}

/// Adds [estimate] (a recurring-movements total) to each month after the current
/// one, on top of the transactions already scheduled in that month. The current
/// month and earlier stay as the real [monthly] values.
///
/// [projectedFromIndex] is the first estimated month index (0–11), or 12 when none.
({List<double> monthly, int projectedFromIndex}) monthlyWithRecurringEstimate(
  List<double> monthly,
  int year, {
  required double estimate,
  DateTime? now,
}) {
  final from = _firstEstimatedMonthIndex(year, now ?? DateTime.now());
  return (
    monthly: List<double>.generate(
      12,
      (i) => i < from ? monthly[i] : monthly[i] + estimate,
    ),
    projectedFromIndex: from,
  );
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
    required this.recurringMonthlyIncome,
  });

  final AppLocalizations l10n;
  final int year;
  final List<TransactionEntity> transactions;
  final bool includeIgnored;
  final bool useWeightedAmounts;

  /// Estimated income for each month after the current one (sum of positive recurring movements).
  final double recurringMonthlyIncome;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final real = weightedIncomeByMonthForYear(
      transactions,
      year,
      includeIgnored: includeIgnored,
      useWeightedAmounts: useWeightedAmounts,
    );
    final result = monthlyWithRecurringEstimate(
      real,
      year,
      estimate: recurringMonthlyIncome,
    );
    return _YearlyMonthlyBarChartCore(
      l10n: l10n,
      year: year,
      monthly: result.monthly,
      projectedFromIndex: result.projectedFromIndex,
      footnote: result.projectedFromIndex < 12
          ? l10n.yearlyDashboardMonthlyProjectionHint
          : null,
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
    required this.recurringMonthlyOutcome,
  });

  final AppLocalizations l10n;
  final int year;
  final List<TransactionEntity> transactions;
  final bool includeIgnored;
  final bool useWeightedAmounts;

  /// Estimated outcome (positive) for each month after the current one.
  final double recurringMonthlyOutcome;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final real = weightedOutcomeByMonthForYear(
      transactions,
      year,
      includeIgnored: includeIgnored,
      useWeightedAmounts: useWeightedAmounts,
    );
    final result = monthlyWithRecurringEstimate(
      real,
      year,
      estimate: recurringMonthlyOutcome,
    );
    return _YearlyMonthlyBarChartCore(
      l10n: l10n,
      year: year,
      monthly: result.monthly,
      projectedFromIndex: result.projectedFromIndex,
      footnote: result.projectedFromIndex < 12
          ? l10n.yearlyDashboardMonthlyProjectionHint
          : null,
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
    required this.recurringMonthlyNet,
  });

  final AppLocalizations l10n;
  final int year;
  final List<TransactionEntity> transactions;
  final bool includeIgnored;
  final bool useWeightedAmounts;

  /// Estimated net (income − outcome) for each month after the current one.
  final double recurringMonthlyNet;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final real = weightedNetByMonthForYear(
      transactions,
      year,
      includeIgnored: includeIgnored,
      useWeightedAmounts: useWeightedAmounts,
    );
    final result = monthlyWithRecurringEstimate(
      real,
      year,
      estimate: recurringMonthlyNet,
    );
    return _YearlyMonthlyBarChartCore(
      l10n: l10n,
      year: year,
      monthly: result.monthly,
      projectedFromIndex: result.projectedFromIndex,
      footnote: result.projectedFromIndex < 12
          ? l10n.yearlyDashboardMonthlyProjectionHint
          : null,
      title: l10n.yearlyDashboardNetByMonthTitle,
      barColor: scheme.primary,
      kind: _YearlyBarKind.net,
    );
  }
}

/// Bar chart: cumulative **accounts** balance (same basis as `/accounts` total) at end of each month.
class YearlyCumulativeNetBarChart extends StatelessWidget {
  const YearlyCumulativeNetBarChart({
    super.key,
    required this.l10n,
    required this.year,
    required this.transactions,
    required this.recurringMonthlyNet,
  });

  final AppLocalizations l10n;
  final int year;
  final List<TransactionEntity> transactions;

  /// Net of all recurring movements, added once per month after the current one.
  final double recurringMonthlyNet;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final result = cumulativeAccountsBalanceWithProjection(
      transactions,
      year,
      recurringMonthlyNet: recurringMonthlyNet,
    );
    return _YearlyMonthlyBarChartCore(
      l10n: l10n,
      year: year,
      monthly: result.monthly,
      title: l10n.yearlyDashboardCumulativeByMonthTitle,
      barColor: scheme.primary,
      kind: _YearlyBarKind.net,
      projectedFromIndex: result.projectedFromIndex,
      footnote: result.projectedFromIndex < 12
          ? l10n.yearlyDashboardCumulativeProjectionHint
          : null,
    );
  }
}

enum _YearlyBarKind { income, outcome, net }

/// Plot area of the bar charts (the [SizedBox] height minus the month axis),
/// used to turn a label size in pixels into headroom in chart units.
const double _plotHeight = 212;

/// Vertical gap between a bar tip and its value label.
const double _rodLabelGap = 6;

/// Step of `1 / 2 / 2.5 / 5 × 10^k` that splits [span] into at most [maxTicks]
/// lines, so axis labels land on round numbers instead of raw data values.
double _niceAxisInterval(double span, {int maxTicks = 5}) {
  if (!span.isFinite || span <= 0) return 0.25;
  final rough = span / maxTicks;
  final magnitude = math
      .pow(10, (math.log(rough) / math.ln10).floor())
      .toDouble();
  for (final m in const [1.0, 2.0, 2.5, 5.0]) {
    if (m * magnitude >= rough) return m * magnitude;
  }
  return 10 * magnitude;
}

/// Axis bounds snapped to whole [interval] steps, with [padFraction] of extra
/// room on the side(s) the bars grow towards so the value labels stay inside.
({double minY, double maxY, double interval}) _axisBounds({
  required double rawMin,
  required double rawMax,
  required double padFraction,
}) {
  final paddedMin = rawMin < 0 ? rawMin * (1 + padFraction) : 0.0;
  final paddedMax = rawMax > 0 ? rawMax * (1 + padFraction) : 0.0;
  final interval = _niceAxisInterval(paddedMax - paddedMin);
  return (
    minY: (paddedMin / interval).floorToDouble() * interval,
    maxY: (paddedMax / interval).ceilToDouble() * interval,
    interval: interval,
  );
}

/// Size of [text] in logical pixels, honoring the ambient text scaler.
Size _textSize(BuildContext context, String text, TextStyle? style) {
  final painter = TextPainter(
    text: TextSpan(text: text, style: style),
    textDirection: Directionality.of(context),
    textScaler: MediaQuery.textScalerOf(context),
  )..layout();
  return painter.size;
}

class _YearlyMonthlyBarChartCore extends StatelessWidget {
  const _YearlyMonthlyBarChartCore({
    required this.l10n,
    required this.year,
    required this.monthly,
    required this.title,
    required this.barColor,
    required this.kind,
    this.projectedFromIndex = 12,
    this.footnote,
  });

  final AppLocalizations l10n;
  final int year;
  final List<double> monthly;
  final String title;
  final Color barColor;
  final _YearlyBarKind kind;

  /// Bars at this month index and later are estimates and drawn faded.
  final int projectedFromIndex;

  /// Optional note shown under the chart (e.g. what the faded bars mean).
  final String? footnote;

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

    final compactFormat = NumberFormat.compact(locale: locale);

    // Twelve bars never leave room for a horizontal amount, so the value labels
    // are drawn sideways and abbreviated; the tooltip keeps the exact figure.
    // Their text width becomes the headroom the axis needs.
    final rodLabelStyle = theme.textTheme.labelSmall?.copyWith(
      color: scheme.onSurface,
      fontWeight: FontWeight.w600,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    final labelSizes = <String, Size>{};
    Size labelSize(String text) => labelSizes.putIfAbsent(
      text,
      () => _textSize(context, text, rodLabelStyle),
    );
    String labelText(double v) =>
        l10n.transactionAmountValue(compactFormat.format(v));

    var maxLabelWidth = 0.0;
    for (final v in rodToY) {
      if (v.abs() < 1e-9) continue;
      final w = labelSize(labelText(v)).width;
      if (w > maxLabelWidth) maxLabelWidth = w;
    }

    var maxPos = 0.0;
    var minNeg = 0.0;
    for (final v in rodToY) {
      if (v > maxPos) maxPos = v;
      if (v < minNeg) minNeg = v;
    }

    late final double minY;
    late final double maxY;
    late final double gridInterval;

    if (maxPos == 0 && minNeg == 0) {
      minY = kind == _YearlyBarKind.outcome ? -1.0 : 0.0;
      maxY = kind == _YearlyBarKind.outcome ? 0.0 : 1.0;
      gridInterval = 0.25;
    } else {
      final bounds = _axisBounds(
        rawMin: minNeg,
        rawMax: maxPos,
        padFraction: ((maxLabelWidth + _rodLabelGap * 2) / _plotHeight).clamp(
          0.1,
          0.45,
        ),
      );
      minY = bounds.minY;
      maxY = bounds.maxY;
      gridInterval = bounds.interval;
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
      final base = switch (kind) {
        _YearlyBarKind.net => rodToY[i] < 0 ? scheme.error : scheme.primary,
        _ => barColor,
      };
      return i >= projectedFromIndex ? base.withValues(alpha: 0.4) : base;
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
                        return Text(
                          compactFormat.format(value),
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
                barGroups: List.generate(monthCount, (i) {
                  final text = labelText(rodToY[i]);
                  final size = labelSize(text);
                  return BarChartGroupData(
                    x: i,
                    barRods: [
                      BarChartRodData(
                        toY: rodToY[i],
                        color: barColorForIndex(i),
                        width: 14,
                        borderRadius: barRadiusForIndex(i),
                        label: BarChartRodLabel(
                          show: rodToY[i].abs() >= 1e-9,
                          text: text,
                          style: rodLabelStyle,
                          // Sideways, reading bottom to top. fl_chart rotates
                          // around the label centre, so the offset has to cover
                          // half the difference between the two sides plus the
                          // gap to keep it clear of the bar tip.
                          angle: -90,
                          offset: Offset(
                            0,
                            (size.width - size.height) / 2 + _rodLabelGap,
                          ),
                        ),
                      ),
                    ],
                  );
                }),
              ),
            ),
          ),
          if (footnote != null) ...[
            const SizedBox(height: 8),
            Text(
              footnote!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
