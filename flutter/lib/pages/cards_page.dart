import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:wallet/l10n/app_localizations.dart';
import '../core/di/injection.dart';
import '../features/cards/domain/entities/card_entity.dart';
import '../features/cards/presentation/cubit/cards_cubit.dart';
import '../features/cards/presentation/cubit/cards_state.dart';
import '../widgets/card_editor_sheet.dart';
import '../widgets/offline_cached_data_banner.dart';
import '../widgets/remote_load_failure_panel.dart';
import '../widgets/shell_scaffold.dart';
import '../widgets/swipeable_list_tile.dart';
import '../widgets/wallet_dual_balance_trailing.dart';

void _showCardBottomSheet(
  BuildContext context,
  AppLocalizations l10n, {
  CardEntity? card,
}) {
  showCardEditorBottomSheet(
    context,
    l10n,
    card: card,
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

class _CardsView extends StatelessWidget {
  const _CardsView();

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
        final showTotalBar = cards.isNotEmpty;
        final totalBalance = showTotalBar
            ? cards.fold<double>(0, (s, c) => s + c.balance)
            : 0.0;

        return ShellScaffold(
          title: l10n.cards,
          floatingActionButton: FloatingActionButton(
            onPressed: () => _showCardBottomSheet(context, l10n),
            child: const Icon(Icons.add),
          ),
          bottomNavigationBar: showTotalBar
              ? WalletListBalanceTotalBar(l10n: l10n, total: totalBalance)
              : null,
          body: _body(context, state, l10n),
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
          return _CardTile(card: cards[i]);
        },
      ),
    );
  }
}

class _CardTile extends StatelessWidget {
  final CardEntity card;
  const _CardTile({required this.card});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cubit = context.read<CardsCubit>();

    void openEdit() {
      _showCardBottomSheet(context, l10n, card: card);
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
      title: Text(card.name),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (card.description != null && card.description!.isNotEmpty)
            Text(
              card.description!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          Text(
            l10n.cardBillingCycleSummary(card.cutDay, card.payDay),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
      trailing: WalletListBalanceAmount(l10n: l10n, balance: card.balance),
      onTap: openTransactions,
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
