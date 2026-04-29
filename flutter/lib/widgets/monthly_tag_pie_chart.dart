import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:wallet/l10n/app_localizations.dart';

import '../features/transactions/domain/entities/transaction_entity.dart';
import 'bottom_sheet_pinned_title.dart';

class _TagSlice {
  _TagSlice({
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

double _effectiveTxAmount(TransactionEntity t, bool useWeighted) =>
    useWeighted ? t.value * t.percentage / 100.0 : t.value;

/// Tags that appear on at least one expense row in [txs] (same basis as the tag pie).
List<({String key, String label})> distinctExpenseTagOptions(
  List<TransactionEntity> txs,
  bool includeIgnored,
  bool useWeighted,
) {
  bool include(TransactionEntity t) => includeIgnored || !t.ignore;
  final labels = <String, String>{};
  final seen = <String>{};

  for (final t in txs) {
    if (!include(t)) continue;
    final id = t.tagId;
    if (id == null || id.isEmpty) continue;
    if (_effectiveTxAmount(t, useWeighted) >= 0) continue;
    seen.add(id);
    if (t.tagName != null && t.tagName!.isNotEmpty) {
      labels[id] = t.tagName!;
    }
  }

  for (final k in seen) {
    labels.putIfAbsent(k, () => '#${k.substring(0, math.min(8, k.length))}');
  }

  final list = seen.map((k) => (key: k, label: labels[k]!)).toList();
  list.sort((a, b) => a.label.toLowerCase().compareTo(b.label.toLowerCase()));
  return list;
}

/// Drops stale tag ids and normalizes "all selected" to null (matches prior chart behavior).
Set<String>? pruneTagKeysFilter(
  List<TransactionEntity> txs,
  bool includeIgnored,
  Set<String>? current,
  bool useWeighted,
) {
  if (current == null) return null;
  final options = distinctExpenseTagOptions(txs, includeIgnored, useWeighted);
  final valid = options.map((o) => o.key).toSet();
  final pruned = current.intersection(valid);
  if (pruned.isEmpty || pruned.length == valid.length) return null;
  return pruned;
}

List<_TagSlice> _aggregateByTag(
  List<TransactionEntity> txs,
  bool includeIgnored,
  ColorScheme scheme, {
  required bool useWeighted,
  Set<String>? tagKeysFilter,
}) {
  bool include(TransactionEntity t) => includeIgnored || !t.ignore;

  final sums = <String, double>{};
  final labels = <String, String>{};

  for (final t in txs) {
    if (!include(t)) continue;
    final id = t.tagId;
    if (id == null || id.isEmpty) continue;
    if (tagKeysFilter != null && !tagKeysFilter.contains(id)) continue;
    final w = _effectiveTxAmount(t, useWeighted);
    if (w >= 0) continue;
    final expense = -w;
    sums[id] = (sums[id] ?? 0) + expense;
    if (t.tagName != null && t.tagName!.isNotEmpty) {
      labels[id] = t.tagName!;
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
        (e) => _TagSlice(
          keyId: e.key,
          label: labels[e.key]!,
          expenseTotal: e.value,
          color: palette[i++],
        ),
      )
      .toList();
}

class _TagLegendRow extends StatelessWidget {
  const _TagLegendRow({
    required this.label,
    required this.expenseTotal,
    required this.color,
    required this.l10n,
    required this.theme,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final double expenseTotal;
  final Color color;
  final AppLocalizations l10n;
  final ThemeData theme;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: selected
            ? scheme.primaryContainer.withValues(alpha: 0.45)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
            child: Row(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    label,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight:
                          selected ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                ),
                Text(
                  l10n.transactionAmountValue(
                    expenseTotal.toStringAsFixed(2),
                  ),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Donut chart of expense totals (negative weighted amounts) per tag; legend shows expense per tag.
///
/// [tagKeysFilter] is owned by the parent: null = all tags; otherwise restrict to these [TransactionEntity.tagId]s.
///
/// Tapping a legend row applies the same filter as choosing only that tag in the sheet and saving.
class MonthlyTagPieChart extends StatelessWidget {
  const MonthlyTagPieChart({
    super.key,
    required this.l10n,
    required this.transactions,
    required this.includeIgnored,
    required this.useWeightedAmounts,
    required this.tagKeysFilter,
    required this.onTagKeysFilterChanged,
  });

  final AppLocalizations l10n;
  final List<TransactionEntity> transactions;
  final bool includeIgnored;
  /// When true, pies use `value × percentage`; when false, full row [TransactionEntity.value].
  final bool useWeightedAmounts;
  final Set<String>? tagKeysFilter;
  final ValueChanged<Set<String>?> onTagKeysFilterChanged;

  Future<void> _openTagFilter(
    BuildContext context,
    List<({String key, String label})> options,
  ) async {
    final allKeys = options.map((o) => o.key).toSet();
    final draft = Set<String>.from(tagKeysFilter ?? allKeys);

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: false,
      builder: (ctx) {
        return SafeArea(
          child: StatefulBuilder(
            builder: (ctx, setModal) {
              final bottomPad = MediaQuery.paddingOf(ctx).bottom;
              return ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.sizeOf(ctx).height * 0.55,
                ),
                child: CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    SliverAppBar(
                      pinned: true,
                      centerTitle: true,
                      automaticallyImplyLeading: false,
                      elevation: 0,
                      scrolledUnderElevation: 4,
                      backgroundColor: modalBottomSheetSurfaceColor(ctx),
                      shadowColor: Theme.of(ctx).colorScheme.shadow,
                      leading: modalBottomSheetBackButton(ctx),
                      title: Text(
                        l10n.dashboardTagPieFilterTags,
                        style: Theme.of(ctx).textTheme.titleLarge,
                      ),
                    ),
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                      sliver: SliverToBoxAdapter(
                        child: Text(
                          l10n.dashboardTagPieFilterDescription,
                          style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                            color: Theme.of(ctx).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ),
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(8, 0, 8, 0),
                      sliver: SliverToBoxAdapter(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            TextButton(
                              onPressed: () {
                                setModal(() {
                                  draft
                                    ..clear()
                                    ..addAll(allKeys);
                                });
                              },
                              child: Text(l10n.dashboardPieSelectAll),
                            ),
                            TextButton(
                              onPressed: () {
                                setModal(() => draft.clear());
                              },
                              child: Text(l10n.dashboardPieDeselectAll),
                            ),
                          ],
                        ),
                      ),
                    ),
                    SliverList.list(
                      children: [
                        for (final o in options)
                          CheckboxListTile(
                            value: draft.contains(o.key),
                            onChanged: (v) {
                              setModal(() {
                                if (v == true) {
                                  draft.add(o.key);
                                } else {
                                  draft.remove(o.key);
                                }
                              });
                            },
                            title: Text(o.label),
                            controlAffinity: ListTileControlAffinity.leading,
                          ),
                      ],
                    ),
                    SliverPadding(
                      padding: EdgeInsets.fromLTRB(20, 16, 20, 16 + bottomPad),
                      sliver: SliverToBoxAdapter(
                        child: FilledButton(
                          onPressed: () {
                            if (draft.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(l10n.dashboardTagPieNeedOneTag),
                                ),
                              );
                              return;
                            }
                            onTagKeysFilterChanged(
                              draft.length == allKeys.length
                                  ? null
                                  : Set<String>.from(draft),
                            );
                            Navigator.of(ctx).pop();
                          },
                          child: Text(l10n.save),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final options = distinctExpenseTagOptions(
      transactions,
      includeIgnored,
      useWeightedAmounts,
    );
    final slices = _aggregateByTag(
      transactions,
      includeIgnored,
      scheme,
      useWeighted: useWeightedAmounts,
      tagKeysFilter: tagKeysFilter,
    );

    if (options.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
        child: Text(
          l10n.dashboardTagPieNoData,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
      );
    }

    if (slices.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
        child: Text(
          l10n.dashboardTagPieNoData,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
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
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  l10n.monthlyDashboardTagPieTitle,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              IconButton(
                tooltip: l10n.dashboardTagPieFilterTags,
                onPressed: () => _openTagFilter(context, options),
                icon: Badge(
                  isLabelVisible: tagKeysFilter != null,
                  smallSize: 8,
                  child: const Icon(Icons.filter_list_rounded),
                ),
              ),
            ],
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
            _TagLegendRow(
              label: s.label,
              expenseTotal: s.expenseTotal,
              color: s.color,
              l10n: l10n,
              theme: theme,
              selected: tagKeysFilter != null &&
                  tagKeysFilter!.length == 1 &&
                  tagKeysFilter!.contains(s.keyId),
              onTap: () => onTagKeysFilterChanged({s.keyId}),
            ),
        ],
      ),
    );
  }
}
