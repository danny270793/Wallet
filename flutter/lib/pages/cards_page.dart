import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:wallet/l10n/app_localizations.dart';
import '../core/di/injection.dart';
import '../features/cards/domain/entities/card_entity.dart';
import '../features/cards/presentation/cubit/cards_cubit.dart';
import '../features/cards/presentation/cubit/cards_state.dart';
import '../widgets/shell_scaffold.dart';
import '../widgets/swipeable_list_tile.dart';
import '../widgets/wallet_dual_balance_trailing.dart';

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
        return ShellScaffold(
          title: l10n.cards,
          body: Stack(
            children: [
              _body(context, state, l10n),
              Positioned(
                right: 16,
                bottom: 16,
                child: FloatingActionButton(
                  onPressed: () => _showCardDialog(context, l10n),
                  child: const Icon(Icons.add),
                ),
              ),
            ],
          ),
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

    final totalWeighted = cards.fold<double>(0, (s, c) => s + c.balanceWeighted);
    final totalCounted = cards.fold<double>(0, (s, c) => s + c.balanceCounted);

    return RefreshIndicator(
      onRefresh: refresh,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 88),
        itemCount: cards.length + 1,
        itemBuilder: (context, index) {
          if (index == cards.length) {
            return WalletDualBalanceListFooter(
              l10n: l10n,
              totalWeighted: totalWeighted,
              totalCounted: totalCounted,
            );
          }
          return _CardTile(card: cards[index]);
        },
      ),
    );
  }

  void _showCardDialog(BuildContext context, AppLocalizations l10n, [CardEntity? card]) {
    showDialog<void>(
      context: context,
      builder: (_) => _CardDialog(
        cubit: context.read<CardsCubit>(),
        l10n: l10n,
        card: card,
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
      showDialog<void>(
        context: context,
        builder: (_) => _CardDialog(cubit: cubit, l10n: l10n, card: card),
      );
    }

    void openTransactions() {
      context.push(
        Uri(
          path: '/transactions',
          queryParameters: {
            'cardId': card.id,
            'cardName': card.name,
          },
        ).toString(),
      );
    }

    return SwipeableListTile(
      itemKey: card.id,
      title: Text(card.name),
      subtitle: card.description != null
          ? Text(card.description!, maxLines: 2, overflow: TextOverflow.ellipsis)
          : null,
      trailing: WalletDualBalanceTrailing(
        l10n: l10n,
        balanceWeighted: card.balanceWeighted,
        balanceCounted: card.balanceCounted,
      ),
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
                child: Text(l10n.delete, style: const TextStyle(color: Colors.white)),
              ),
            ],
          ),
        );
        return ok ?? false;
      },
      onDeleted: () => cubit.delete(id: card.id),
    );
  }
}

class _CardDialog extends StatefulWidget {
  final CardsCubit cubit;
  final AppLocalizations l10n;
  final CardEntity? card;

  const _CardDialog({required this.cubit, required this.l10n, this.card});

  @override
  State<_CardDialog> createState() => _CardDialogState();
}

class _CardDialogState extends State<_CardDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.card?.name ?? '');
    _descriptionController = TextEditingController(text: widget.card?.description ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    final name = _nameController.text.trim();
    final description = _descriptionController.text.trim().isEmpty ? null : _descriptionController.text.trim();
    try {
      if (widget.card == null) {
        await widget.cubit.create(name: name, description: description);
      } else {
        await widget.cubit.update(id: widget.card!.id, name: name, description: description);
      }
    } finally {
      if (mounted) Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = widget.l10n;
    final isEdit = widget.card != null;

    return AlertDialog(
      title: Text(isEdit ? l10n.editCard : l10n.newCard),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _nameController,
              decoration: InputDecoration(labelText: l10n.accountName),
              validator: (v) => (v == null || v.trim().isEmpty) ? l10n.fieldRequired : null,
              autofocus: true,
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _descriptionController,
              decoration: InputDecoration(labelText: l10n.accountDescription),
              maxLines: 3,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _loading ? null : () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        ElevatedButton(
          onPressed: _loading ? null : _submit,
          child: _loading
              ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
              : Text(l10n.save),
        ),
      ],
    );
  }
}
