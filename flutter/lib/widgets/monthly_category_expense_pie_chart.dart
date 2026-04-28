import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:wallet/l10n/app_localizations.dart';

import '../features/transactions/domain/entities/transaction_entity.dart';

class _CategorySlice {
  _CategorySlice({
    required this.keyId,
    required this.label,
    required this.expenseTotal,
    required this.color,
  });

  final String keyId;
  final String label;
  final double expenseTotal;
  final Color color;
}

List<Color> _palette(ColorScheme scheme, int n) {
  final base = <Color>[
    scheme.primary,
    scheme.secondary,
    scheme.tertiary,
    scheme.error,
    const Color(0xFF00897B),
    const Color(0xFF6D4C41),
    const Color(0xFF5E35B1),
    const Color(0xFFD84315),
  ];
  if (n <= base.length) return base.sublist(0, n);
  final out = List<Color>.from(base);
  for (var i = base.length; i < n; i++) {
    final h = ((i - base.length) * 47) % 360;
    out.add(HSVColor.fromAHSV(1, h.toDouble(), 0.55, 0.85).toColor());
  }
  return out;
}

double _weighted(TransactionEntity t) => t.value * t.percentage / 100.0;

List<_CategorySlice> _aggregateExpenseByCategory(
  List<TransactionEntity> txs,
  bool includeIgnored,
  ColorScheme scheme,
) {
  bool include(TransactionEntity t) => includeIgnored || !t.ignore;

  final sums = <String, double>{};
  final labels = <String, String>{};

  for (final t in txs) {
    if (!include(t)) continue;
    final id = t.categoryId;
    if (id == null || id.isEmpty) continue;
    final w = _weighted(t);
    if (w >= 0) continue;
    final expense = -w;
    sums[id] = (sums[id] ?? 0) + expense;
    if (t.categoryName != null && t.categoryName!.isNotEmpty) {
      labels[id] = t.categoryName!;
    }
  }

  for (final k in sums.keys) {
    labels.putIfAbsent(k, () => '#${k.substring(0, math.min(8, k.length))}');
  }

  final nonZero = sums.entries.where((e) => e.value >= 1e-9).toList();
  if (nonZero.isEmpty) return [];

  final palette = _palette(scheme, nonZero.length);
  nonZero.sort((a, b) => b.value.compareTo(a.value));

  var i = 0;
  return nonZero
      .map(
        (e) => _CategorySlice(
          keyId: e.key,
          label: labels[e.key]!,
          expenseTotal: e.value,
          color: palette[i++],
        ),
      )
      .toList();
}

/// Donut chart of expense totals (negative weighted amounts) per category.
class MonthlyCategoryExpensePieChart extends StatelessWidget {
  const MonthlyCategoryExpensePieChart({
    super.key,
    required this.l10n,
    required this.transactions,
    required this.includeIgnored,
  });

  final AppLocalizations l10n;
  final List<TransactionEntity> transactions;
  final bool includeIgnored;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final slices = _aggregateExpenseByCategory(transactions, includeIgnored, scheme);

    if (slices.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
        child: Text(
          l10n.dashboardCategoryPieNoData,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
        ),
      );
    }

    final sections = <PieChartSectionData>[
      for (final s in slices)
        PieChartSectionData(
          value: s.expenseTotal,
          color: s.color,
          showTitle: false,
          radius: 52,
        ),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.monthlyDashboardCategoryPieTitle,
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 200,
            child: PieChart(
              PieChartData(
                sectionsSpace: 2,
                centerSpaceRadius: 48,
                sections: sections,
              ),
            ),
          ),
          const SizedBox(height: 12),
          for (final s in slices)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(color: s.color, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      s.label,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                  Text(
                    l10n.transactionAmountValue(s.expenseTotal.toStringAsFixed(2)),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
