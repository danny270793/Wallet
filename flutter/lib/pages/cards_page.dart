import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:wallet/l10n/app_localizations.dart';
import '../core/di/injection.dart';
import '../features/cards/domain/entities/card_entity.dart';
import '../features/cards/presentation/cubit/cards_cubit.dart';
import '../features/cards/presentation/cubit/cards_state.dart';
import '../widgets/card_editor_sheet.dart';
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
    Future<void> refresh() => context.read<CardsCubit>().load();

    if (state is CardsLoading || state is CardsInitial) {
      return RefreshIndicator(
        onRefresh: refresh,
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
      return RefreshIndicator(
        onRefresh: refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            SizedBox(
              height: MediaQuery.sizeOf(context).height * 0.35,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(l10n.unexpectedError),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: refresh,
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    final cards = switch (state) {
      CardsLoaded(:final cards) => cards,
      CardsActionError(:final cards) => cards,
      _ => <CardEntity>[],
    };

    if (cards.isEmpty) {
      return RefreshIndicator(
        onRefresh: refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(bottom: 88),
          children: [
            SizedBox(
              height: MediaQuery.sizeOf(context).height * 0.35,
              child: Center(child: Text(l10n.noCards)),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: refresh,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 8),
        itemCount: cards.length,
        itemBuilder: (context, index) => _CardTile(card: cards[index]),
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

    void openTransactions() {
      context.push(
        Uri(
          path: '/transactions',
          queryParameters: {'cardId': card.id, 'cardName': card.name},
        ).toString(),
      );
    }

    return SwipeableListTile(
      itemKey: card.id,
      title: Text(card.name),
      subtitle: card.description != null
          ? Text(
              card.description!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            )
          : null,
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
