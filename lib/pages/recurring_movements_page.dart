import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:wallet/l10n/app_localizations.dart';
import '../core/di/injection.dart';
import '../features/recurring_movements/domain/entities/recurring_movement_entity.dart';
import '../features/recurring_movements/presentation/cubit/recurring_movements_cubit.dart';
import '../features/recurring_movements/presentation/cubit/recurring_movements_state.dart';
import '../widgets/bottom_sheet_pinned_title.dart';
import '../widgets/offline_cached_data_banner.dart';
import '../widgets/recurring_movement_editor_sheet.dart';
import '../widgets/remote_load_failure_panel.dart';
import '../widgets/shell_scaffold.dart';
import '../widgets/swipeable_list_tile.dart';
import '../widgets/wallet_bottom_bar_insets.dart';
import '../widgets/wallet_dual_balance_trailing.dart';

void _showRecurringMovementBottomSheet(
  BuildContext context,
  AppLocalizations l10n, {
  RecurringMovementEntity? movement,
}) {
  showRecurringMovementEditorBottomSheet(
    context,
    l10n,
    movement: movement,
    cubit: context.read<RecurringMovementsCubit>(),
  );
}

class RecurringMovementsPage extends StatelessWidget {
  const RecurringMovementsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => getIt<RecurringMovementsCubit>()..load(),
      child: const _RecurringMovementsView(),
    );
  }
}

enum _RecurringMovementsSortBy { name, value }

String _sortLabel(AppLocalizations l10n, _RecurringMovementsSortBy by) =>
    switch (by) {
      _RecurringMovementsSortBy.name => l10n.settingsCacheSortByName,
      _RecurringMovementsSortBy.value => l10n.recurringMovementsSortByValue,
    };

class _RecurringMovementsView extends StatefulWidget {
  const _RecurringMovementsView();

  @override
  State<_RecurringMovementsView> createState() =>
      _RecurringMovementsViewState();
}

class _RecurringMovementsViewState extends State<_RecurringMovementsView> {
  _RecurringMovementsSortBy _sortBy = _RecurringMovementsSortBy.name;

  /// Ids picked in multi-select mode (entered by long-pressing a row).
  final Set<String> _selectedIds = {};

  /// Selected rows that still exist; select mode is on while this is non-empty.
  List<RecurringMovementEntity> _selectedAmong(
    List<RecurringMovementEntity> movements,
  ) => movements.where((m) => _selectedIds.contains(m.id)).toList();

  void _toggleSelected(String id) {
    setState(() {
      if (!_selectedIds.remove(id)) _selectedIds.add(id);
    });
  }

  void _clearSelection() => setState(_selectedIds.clear);

  /// The cubit already sorts by name; value sort is highest to lowest,
  /// with name as the tie-breaker.
  List<RecurringMovementEntity> _sorted(List<RecurringMovementEntity> items) {
    if (_sortBy == _RecurringMovementsSortBy.name) return items;
    return List<RecurringMovementEntity>.from(items)..sort((a, b) {
      final byValue = b.value.compareTo(a.value);
      if (byValue != 0) return byValue;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
  }

  Future<void> _showSortSheet(
    BuildContext context,
    AppLocalizations l10n,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: false,
      isScrollControlled: true,
      builder: (sheetContext) => BottomSheetPinnedTitleScrollView(
        padding: EdgeInsets.zero,
        title: l10n.settingsCacheSortSheetTitle,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final option in _RecurringMovementsSortBy.values)
              ListTile(
                title: Text(_sortLabel(l10n, option)),
                trailing: _sortBy == option
                    ? Icon(
                        Icons.check,
                        color: Theme.of(sheetContext).colorScheme.primary,
                      )
                    : null,
                onTap: () {
                  setState(() => _sortBy = option);
                  Navigator.of(sheetContext).pop();
                },
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return BlocConsumer<RecurringMovementsCubit, RecurringMovementsState>(
      listener: (context, state) {
        if (state is RecurringMovementsActionError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.message ?? l10n.unexpectedError)),
          );
        }
      },
      builder: (context, state) {
        final movements = switch (state) {
          RecurringMovementsLoaded(:final movements) => movements,
          RecurringMovementsActionError(:final movements) => movements,
          _ => null,
        };
        final selected = _selectedAmong(movements ?? const []);
        final selecting = selected.isNotEmpty;
        return PopScope(
          canPop: !selecting,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) _clearSelection();
          },
          child: ShellScaffold(
            title: selecting
                ? l10n.recurringMovementsSelectedCount(selected.length)
                : l10n.recurringMovements,
            appBarActionsBeforeSettings: [
              if (selecting)
                IconButton(
                  icon: const Icon(Icons.close),
                  tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
                  onPressed: _clearSelection,
                )
              else
                IconButton(
                  icon: const Icon(Icons.swap_vert_rounded),
                  tooltip: l10n.settingsCacheSortTooltip,
                  onPressed: () => _showSortSheet(context, l10n),
                ),
            ],
            floatingActionButton: FloatingActionButton(
              onPressed: () => _showRecurringMovementBottomSheet(context, l10n),
              child: const Icon(Icons.add),
            ),
            bottomNavigationBar: movements == null
                ? null
                : _RecurringMovementsTotalsBar(
                    l10n: l10n,
                    movements: selecting ? selected : movements,
                  ),
            body: _body(context, state, l10n),
          ),
        );
      },
    );
  }

  Widget _body(
    BuildContext context,
    RecurringMovementsState state,
    AppLocalizations l10n,
  ) {
    Future<void> pullRefresh() =>
        context.read<RecurringMovementsCubit>().load(showLoading: false);

    Future<void> reloadWithOverlay() =>
        context.read<RecurringMovementsCubit>().load(showLoading: true);

    if (state is RecurringMovementsLoading ||
        state is RecurringMovementsInitial) {
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

    if (state is RecurringMovementsError) {
      return RemoteLoadFailurePanel(
        l10n: l10n,
        failure: state.failure,
        onRetry: reloadWithOverlay,
      );
    }

    final offlineCached = switch (state) {
      RecurringMovementsLoaded(:final servedFromOfflineCache) =>
        servedFromOfflineCache,
      RecurringMovementsActionError(:final servedFromOfflineCache) =>
        servedFromOfflineCache,
      _ => false,
    };

    final movements = _sorted(switch (state) {
      RecurringMovementsLoaded(:final movements) => movements,
      RecurringMovementsActionError(:final movements) => movements,
      _ => <RecurringMovementEntity>[],
    });

    if (movements.isEmpty) {
      return RefreshIndicator(
        onRefresh: pullRefresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(bottom: 88),
          children: [
            OfflineCachedDataBanner(visible: offlineCached),
            SizedBox(
              height: MediaQuery.sizeOf(context).height * 0.3,
              child: Center(child: Text(l10n.noRecurringMovements)),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: pullRefresh,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 88),
        itemCount: movements.length + (offlineCached ? 1 : 0),
        itemBuilder: (context, index) {
          if (offlineCached && index == 0) {
            return const OfflineCachedDataBanner(visible: true);
          }
          final i = index - (offlineCached ? 1 : 0);
          final movement = movements[i];
          final selecting = _selectedAmong(movements).isNotEmpty;
          return _RecurringMovementTile(
            movement: movement,
            selecting: selecting,
            selected: _selectedIds.contains(movement.id),
            onToggleSelected: () {
              // Drop ids of rows that no longer exist before toggling.
              _selectedIds.retainAll(movements.map((m) => m.id));
              _toggleSelected(movement.id);
            },
          );
        },
      ),
    );
  }
}

class _RecurringMovementTile extends StatelessWidget {
  final RecurringMovementEntity movement;

  /// In select mode a tap toggles selection and swipe actions are disabled.
  final bool selecting;
  final bool selected;
  final VoidCallback onToggleSelected;

  const _RecurringMovementTile({
    required this.movement,
    required this.selecting,
    required this.selected,
    required this.onToggleSelected,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cubit = context.read<RecurringMovementsCubit>();

    final relationNames = [
      movement.categoryName,
      movement.tagName,
    ].whereType<String>().where((n) => n.isNotEmpty).toList();
    final description = movement.description;
    final subtitleLines = [
      if (relationNames.isNotEmpty)
        Text(
          relationNames.join(' · '),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      if (description != null)
        Text(description, maxLines: 2, overflow: TextOverflow.ellipsis),
    ];

    return SwipeableListTile(
      itemKey: movement.id,
      title: Text(movement.name),
      subtitle: subtitleLines.isEmpty
          ? null
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: subtitleLines,
            ),
      trailing: WalletListBalanceAmount(l10n: l10n, balance: movement.value),
      selected: selected,
      swipeEnabled: !selecting,
      onTap: selecting ? onToggleSelected : null,
      onLongPress: onToggleSelected,
      onEdit: () =>
          _showRecurringMovementBottomSheet(context, l10n, movement: movement),
      confirmDelete: () async {
        final ok = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: Text(l10n.deleteRecurringMovement),
            content: Text(l10n.confirmDeleteRecurringMovement(movement.name)),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: Text(l10n.cancel),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: Text(
                  l10n.delete,
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
        );
        return ok ?? false;
      },
      onDelete: () => cubit.delete(id: movement.id),
    );
  }
}

/// Bottom summary: income (sum of positive values) and outcome (sum of negative values)
/// over [movements] (all rows, or only the selected ones in select mode).
class _RecurringMovementsTotalsBar extends StatelessWidget {
  const _RecurringMovementsTotalsBar({
    required this.l10n,
    required this.movements,
  });

  final AppLocalizations l10n;
  final List<RecurringMovementEntity> movements;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    var income = 0.0;
    var outcome = 0.0;
    for (final m in movements) {
      if (m.value > 0) {
        income += m.value;
      } else {
        outcome += m.value;
      }
    }

    final amountStyle = theme.textTheme.titleMedium?.copyWith(
      fontWeight: FontWeight.w700,
      height: 1.2,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    final labelStyle = theme.textTheme.labelMedium?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
      fontWeight: FontWeight.w500,
    );

    Widget column(double amount, String label, Color amountColor) {
      return Expanded(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              l10n.transactionAmountValue(amount.toStringAsFixed(2)),
              textAlign: TextAlign.center,
              style: amountStyle?.copyWith(color: amountColor),
            ),
            const SizedBox(height: 2),
            Text(label, textAlign: TextAlign.center, style: labelStyle),
          ],
        ),
      );
    }

    return Material(
      color: theme.colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: EdgeInsets.only(
          bottom: walletBottomBarExtraBottomInset(context),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 10, 8, 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              column(
                income,
                l10n.transactionsTotalIncome,
                walletListBalanceColor(theme, income),
              ),
              column(
                outcome,
                l10n.transactionsTotalOutcome,
                walletListBalanceColor(theme, outcome),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
