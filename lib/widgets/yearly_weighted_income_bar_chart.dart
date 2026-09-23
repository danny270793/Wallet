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

/// Lifetime accounts-total at month-end for Jan through the last month that should
/// be visible: all 12 months for past years, through the current month for this year.
/// Later months stay 0 so the chart keeps 12 slots with no future bars.
List<double> _cumulativeAccountsBalanceMonthlyBarsWithTrailingZeros(
  List<TransactionEntity> txs,
  int year,
) {
  final full = accountsTotalCumulativeByMonthForYear(txs, year);
  final now = DateTime.now();
  final lastVisible = year < now.year
      ? 12
      : year > now.year
      ? 0
      : now.month;
  if (lastVisible <= 0) return List<double>.filled(12, 0);
  if (lastVisible >= 12) return full;
  return List<double>.generate(12, (i) => i < lastVisible ? full[i] : 0.0);
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

/// Bar chart: cumulative **accounts** balance (same basis as `/accounts` total) at end of each month.
class YearlyCumulativeNetBarChart extends StatelessWidget {
  const YearlyCumulativeNetBarChart({
    super.key,
    required this.l10n,
    required this.year,
    required this.transactions,
  });

  final AppLocalizations l10n;
  final int year;
  final List<TransactionEntity> transactions;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final monthly = _cumulativeAccountsBalanceMonthlyBarsWithTrailingZeros(
      transactions,
      year,
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
  final magnitude = math.pow(10, (math.log(rough) / math.ln10).floor())
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
        ],
      ),
    );
  }
}
