import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:wallet/l10n/app_localizations.dart';

import '../core/credit_ledger_grouping.dart';
import '../core/di/injection.dart';
import '../features/cards/domain/entities/card_entity.dart';
import '../features/cards/presentation/cubit/cards_cubit.dart';
import '../features/cards/presentation/cubit/cards_state.dart';
import '../widgets/card_editor_sheet.dart';
import '../widgets/card_type_icon.dart';
import '../widgets/offline_cached_data_banner.dart';
import '../widgets/remote_load_failure_panel.dart';
import '../widgets/shell_scaffold.dart';
import '../widgets/swipeable_list_tile.dart';
import '../widgets/wallet_dual_balance_trailing.dart';

void _showCardBottomSheet(
  BuildContext context,
  AppLocalizations l10n, {
  CardEntity? card,
  CardCreditTotals? credits,
}) {
  showCardEditorBottomSheet(
    context,
    l10n,
    card: card,
    postedBalance: card == null
        ? null
        : cardPostedBalance(card.balance, credits),
    deferredBalance: card == null ? null : (credits?.pending ?? 0),
    cubit: context.read<CardsCubit>(),
  );
}

class CardsPage extends StatelessWidget {
  const CardsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => getIt<CardsCubit>()..load(),
      child: const _CardsView(),
    );
  }
}

class _CardsView extends StatefulWidget {
  const _CardsView();

  @override
  State<_CardsView> createState() => _CardsViewState();
}

class _CardsViewState extends State<_CardsView> {
  /// Ids picked in multi-select mode (entered by long-pressing a row).
  final Set<String> _selectedIds = {};

  /// Selected rows that still exist; select mode is on while this is non-empty.
  List<CardEntity> _selectedAmong(List<CardEntity> items) =>
      items.where((e) => _selectedIds.contains(e.id)).toList();

  void _toggleSelected(String id, List<CardEntity> items) {
    setState(() {
      // Drop ids of rows that no longer exist before toggling.
      _selectedIds.retainAll(items.map((e) => e.id));
      if (!_selectedIds.remove(id)) _selectedIds.add(id);
    });
  }

  void _clearSelection() => setState(_selectedIds.clear);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return BlocConsumer<CardsCubit, CardsState>(
      listener: (context, state) {
        if (state is CardsActionError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.message ?? l10n.unexpectedError)),
          );
        }
      },
      builder: (context, state) {
        final cards = switch (state) {
          CardsLoaded(:final cards) => cards,
          CardsActionError(:final cards) => cards,
          _ => <CardEntity>[],
        };
        final creditTotals = switch (state) {
          CardsLoaded(:final creditTotals) => creditTotals,
          CardsActionError(:final creditTotals) => creditTotals,
          _ => const <String, CardCreditTotals>{},
        };
        final selected = _selectedAmong(cards);
        final selecting = selected.isNotEmpty;
        final totalsCards = selecting ? selected : cards;
        final showTotalBar = cards.isNotEmpty;
        final totalNonCredits = showTotalBar
            ? totalsCards.fold<double>(
                0,
                (s, c) => s + cardPostedBalance(c.balance, creditTotals[c.id]),
              )
            : 0.0;
        final totalCredits = showTotalBar
            ? totalsCards.fold<double>(
                0,
                (s, c) => s + (creditTotals[c.id]?.pending ?? 0),
              )
            : 0.0;

        return PopScope(
          canPop: !selecting,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) _clearSelection();
          },
          child: ShellScaffold(
            title: selecting
                ? l10n.listSelectedCount(selected.length)
                : l10n.cards,
            appBarActionsBeforeSettings: selecting
                ? [
                    IconButton(
                      icon: const Icon(Icons.close),
                      tooltip: MaterialLocalizations.of(context)
                          .closeButtonTooltip,
                      onPressed: _clearSelection,
                    ),
                  ]
                : null,
            floatingActionButton: FloatingActionButton(
              onPressed: () => _showCardBottomSheet(context, l10n),
              child: const Icon(Icons.add),
            ),
            bottomNavigationBar: showTotalBar
                ? WalletCardTotalsBar(
                    l10n: l10n,
                    nonCredits: totalNonCredits,
                    credits: totalCredits,
                  )
                : null,
            body: _body(context, state, l10n),
          ),
        );
      },
    );
  }

  Widget _body(BuildContext context, CardsState state, AppLocalizations l10n) {
    Future<void> pullRefresh() =>
        context.read<CardsCubit>().load(showLoading: false);

    Future<void> reloadWithOverlay() =>
        context.read<CardsCubit>().load(showLoading: true);

    if (state is CardsLoading || state is CardsInitial) {
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

    if (state is CardsError) {
      return RemoteLoadFailurePanel(
        l10n: l10n,
        failure: state.failure,
        onRetry: reloadWithOverlay,
      );
    }

    final offlineCached = switch (state) {
      CardsLoaded(:final servedFromOfflineCache) => servedFromOfflineCache,
      CardsActionError(:final servedFromOfflineCache) => servedFromOfflineCache,
      _ => false,
    };

    final cards = switch (state) {
      CardsLoaded(:final cards) => cards,
      CardsActionError(:final cards) => cards,
      _ => <CardEntity>[],
    };

    final creditTotals = switch (state) {
      CardsLoaded(:final creditTotals) => creditTotals,
      CardsActionError(:final creditTotals) => creditTotals,
      _ => const <String, CardCreditTotals>{},
    };

    if (cards.isEmpty) {
      return RefreshIndicator(
        onRefresh: pullRefresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(bottom: 88),
          children: [
            OfflineCachedDataBanner(visible: offlineCached),
            SizedBox(
              height: MediaQuery.sizeOf(context).height * 0.3,
              child: Center(child: Text(l10n.noCards)),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: pullRefresh,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 8),
        itemCount: cards.length + (offlineCached ? 1 : 0),
        itemBuilder: (context, index) {
          if (offlineCached && index == 0) {
            return const OfflineCachedDataBanner(visible: true);
          }
          final i = index - (offlineCached ? 1 : 0);
          final card = cards[i];
          return _CardTile(
            card: card,
            credits: creditTotals[card.id],
            selecting: _selectedAmong(cards).isNotEmpty,
            selected: _selectedIds.contains(card.id),
            onToggleSelected: () => _toggleSelected(card.id, cards),
          );
        },
      ),
    );
  }
}

class _CardTile extends StatelessWidget {
  final CardEntity card;
  final CardCreditTotals? credits;

  /// In select mode a tap toggles selection and swipe actions are disabled.
  final bool selecting;
  final bool selected;
  final VoidCallback onToggleSelected;

  const _CardTile({
    required this.card,
    this.credits,
    required this.selecting,
    required this.selected,
    required this.onToggleSelected,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cubit = context.read<CardsCubit>();

    void openEdit() {
      _showCardBottomSheet(context, l10n, card: card, credits: credits);
    }

    Future<void> openTransactions() async {
      await context.push(
        Uri(
          path: '/transactions',
          queryParameters: {'cardId': card.id, 'cardName': card.name},
        ).toString(),
      );
      if (!context.mounted) return;
      await context.read<CardsCubit>().load(showLoading: false);
    }

    return SwipeableListTile(
      itemKey: card.id,
      leading: CardTypeIcon(type: card.type, size: 28),
      title: Text(
        card.nominalInterestRate == null
            ? card.name
            : '${card.name} (${card.nominalInterestRate!.toStringAsFixed(2)} %)',
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            l10n.cardBillingCycleSummary(card.cutDay, card.payDay),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
      trailing: WalletCardBalanceAmounts(
        l10n: l10n,
        balance: cardPostedBalance(card.balance, credits),
        creditBalance: credits?.pending ?? 0,
      ),
      selected: selected,
      swipeEnabled: !selecting,
      onTap: selecting ? onToggleSelected : openTransactions,
      onLongPress: onToggleSelected,
      onEdit: openEdit,
      confirmDelete: () async {
        final ok = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: Text(l10n.deleteCard),
            content: Text(l10n.confirmDeleteCard(card.name)),
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
      onDelete: () => cubit.delete(id: card.id),
    );
  }
}
