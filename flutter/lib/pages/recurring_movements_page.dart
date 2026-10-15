import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:wallet/l10n/app_localizations.dart';

import '../core/automatic_recurring_movements.dart';
import '../core/di/injection.dart';
import '../features/recurring_movements/domain/entities/recurring_movement_entity.dart';
import '../features/recurring_movements/presentation/cubit/recurring_movements_cubit.dart';
import '../features/recurring_movements/presentation/cubit/recurring_movements_state.dart';
import '../widgets/card_type_icon.dart';
import '../widgets/offline_cached_data_banner.dart';
import '../widgets/recurring_movement_editor_sheet.dart';
import '../widgets/remote_load_failure_panel.dart';
import '../widgets/shell_scaffold.dart';
import '../widgets/swipeable_list_tile.dart';
import '../widgets/transactions_month_scope.dart';
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

class _RecurringMovementsView extends StatefulWidget {
  const _RecurringMovementsView();

  @override
  State<_RecurringMovementsView> createState() =>
      _RecurringMovementsViewState();
}

class _RecurringMovementsViewState extends State<_RecurringMovementsView> {
  /// Ids picked in multi-select mode (entered by long-pressing a row).
  final Set<String> _selectedIds = {};

  /// Month the automatic rows are computed for; starts on the current one.
  late final ValueNotifier<DateTime> _monthNotifier;

  /// Data for the read-only loan and card rows of any month.
  AutomaticMovementsSource _automaticSource = const AutomaticMovementsSource();
  List<AutomaticRecurringMovement> _automatic = const [];

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _monthNotifier = ValueNotifier(DateTime(now.year, now.month))
      ..addListener(_recomputeAutomatic);
    _loadAutomatic();
  }

  @override
  void dispose() {
    _monthNotifier.dispose();
    super.dispose();
  }

  Future<void> _loadAutomatic() async {
    final source = await loadAutomaticMovementsSource();
    if (!mounted) return;
    _automaticSource = source;
    _recomputeAutomatic();
  }

  void _recomputeAutomatic() {
    setState(() {
      _automatic = _automaticSource.forMonth(_monthNotifier.value);
      // Rows of another month are different rows; keep only user movements.
      _selectedIds.removeWhere((id) => id.contains(':'));
    });
  }

  /// Selected rows that still exist; select mode is on while this is non-empty.
  List<_Row> _selectedAmong(List<_Row> rows) =>
      rows.where((r) => _selectedIds.contains(r.id)).toList();

  List<_Row> _rows(List<RecurringMovementEntity> movements) => _sorted([
    for (final m in movements) _MovementRow(m),
    for (final a in _automatic) _AutomaticRow(a),
  ]);

  void _toggleSelected(String id) {
    setState(() {
      if (!_selectedIds.remove(id)) _selectedIds.add(id);
    });
  }

  void _clearSelection() => setState(_selectedIds.clear);

  /// Highest to lowest monthly amount, with name as the tie-breaker.
  static List<_Row> _sorted(List<_Row> items) {
    return List<_Row>.from(items)..sort((a, b) {
      final byValue = b.monthlyAmount.compareTo(a.monthlyAmount);
      if (byValue != 0) return byValue;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
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
        final rows = movements == null ? null : _rows(movements);
        final selected = _selectedAmong(rows ?? const []);
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
            appBarBottom: TransactionsMonthAppBarBottom(
              notifier: _monthNotifier,
            ),
            appBarActionsBeforeSettings: [
              if (selecting)
                IconButton(
                  icon: const Icon(Icons.close),
                  tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
                  onPressed: _clearSelection,
                ),
            ],
            floatingActionButton: FloatingActionButton(
              onPressed: () => _showRecurringMovementBottomSheet(context, l10n),
              child: const Icon(Icons.add),
            ),
            bottomNavigationBar: rows == null
                ? null
                : _RecurringMovementsTotalsBar(
                    l10n: l10n,
                    rows: selecting ? selected : rows,
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
    Future<void> pullRefresh() => Future.wait([
      context.read<RecurringMovementsCubit>().load(showLoading: false),
      _loadAutomatic(),
    ]);

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

    final rows = _rows(switch (state) {
      RecurringMovementsLoaded(:final movements) => movements,
      RecurringMovementsActionError(:final movements) => movements,
      _ => <RecurringMovementEntity>[],
    });

    if (rows.isEmpty) {
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
        itemCount: rows.length + (offlineCached ? 1 : 0),
        itemBuilder: (context, index) {
          if (offlineCached && index == 0) {
            return const OfflineCachedDataBanner(visible: true);
          }
          final row = rows[index - (offlineCached ? 1 : 0)];
          final selecting = _selectedAmong(rows).isNotEmpty;
          void onToggleSelected() {
            // Drop ids of rows that no longer exist before toggling.
            _selectedIds.retainAll(rows.map((r) => r.id));
            _toggleSelected(row.id);
          }

          return switch (row) {
            _MovementRow(:final movement) => _RecurringMovementTile(
              movement: movement,
              selecting: selecting,
              selected: _selectedIds.contains(row.id),
              onToggleSelected: onToggleSelected,
            ),
            _AutomaticRow(:final automatic) => _AutomaticMovementTile(
              automatic: automatic,
              selecting: selecting,
              selected: _selectedIds.contains(row.id),
              onToggleSelected: onToggleSelected,
            ),
          };
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
    final theme = Theme.of(context);
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
      trailing: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          WalletListBalanceAmount(l10n: l10n, balance: movement.monthlyAmount),
          if (movement.yearlyPayment) ...[
            const SizedBox(height: 2),
            Text(
              l10n.transactionAmountValue(movement.value.toStringAsFixed(2)),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.tertiary,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ],
      ),
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
  const _RecurringMovementsTotalsBar({required this.l10n, required this.rows});

  final AppLocalizations l10n;
  final List<_Row> rows;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    var income = 0.0;
    var outcome = 0.0;
    for (final m in rows) {
      final monthly = m.monthlyAmount;
      if (monthly > 0) {
        income += monthly;
      } else {
        outcome += monthly;
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

/// One list row: a user's recurring movement or a read-only automatic one.
sealed class _Row {
  const _Row();
  String get id;
  String get name;
  double get monthlyAmount;
}

class _MovementRow extends _Row {
  const _MovementRow(this.movement);
  final RecurringMovementEntity movement;
  @override
  String get id => movement.id;
  @override
  String get name => movement.name;
  @override
  double get monthlyAmount => movement.monthlyAmount;
}

class _AutomaticRow extends _Row {
  const _AutomaticRow(this.automatic);
  final AutomaticRecurringMovement automatic;
  @override
  String get id => automatic.id;
  @override
  String get name => automatic.name;
  @override
  double get monthlyAmount => automatic.monthlyAmount;
}

/// Loan installment or card revolving balance: selectable, not editable.
class _AutomaticMovementTile extends StatelessWidget {
  const _AutomaticMovementTile({
    required this.automatic,
    required this.selecting,
    required this.selected,
    required this.onToggleSelected,
  });

  final AutomaticRecurringMovement automatic;

  /// In select mode a tap toggles selection, like the user's own rows.
  final bool selecting;
  final bool selected;
  final VoidCallback onToggleSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final (leading, subtitle) = switch (automatic) {
      LoanRecurringMovement() => (
        Icon(Icons.request_quote_outlined, color: theme.colorScheme.primary),
        l10n.recurringAutomaticLoan,
      ),
      CardInterestRecurringMovement(:final type) => (
        CardTypeIcon(type: type),
        l10n.recurringAutomaticCardInterest,
      ),
      CardDeferredRecurringMovement(:final type) => (
        CardTypeIcon(type: type),
        l10n.recurringAutomaticCardDeferred,
      ),
    };
    return ListTile(
      leading: leading,
      title: Text(automatic.name),
      subtitle: Text(subtitle),
      trailing: WalletListBalanceAmount(
        l10n: l10n,
        balance: automatic.monthlyAmount,
      ),
      selected: selected,
      selectedTileColor: theme.colorScheme.secondaryContainer,
      onLongPress: onToggleSelected,
      onTap: selecting ? onToggleSelected : null,
    );
  }
}
