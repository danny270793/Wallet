import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:wallet/l10n/app_localizations.dart';
import '../core/di/injection.dart';
import '../features/accounts/domain/entities/account_entity.dart';
import '../features/accounts/presentation/cubit/accounts_cubit.dart';
import '../features/accounts/presentation/cubit/accounts_state.dart';
import '../widgets/shell_scaffold.dart';
import '../widgets/swipeable_list_tile.dart';
import '../widgets/wallet_dual_balance_trailing.dart';

void _showAccountBottomSheet(
  BuildContext context,
  AppLocalizations l10n, {
  AccountEntity? account,
}) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (sheetContext) => Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(sheetContext).bottom,
      ),
      child: _AccountEditor(
        cubit: context.read<AccountsCubit>(),
        l10n: l10n,
        account: account,
      ),
    ),
  );
}

class AccountsPage extends StatelessWidget {
  const AccountsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => getIt<AccountsCubit>()..load(),
      child: const _AccountsView(),
    );
  }
}

class _AccountsView extends StatelessWidget {
  const _AccountsView();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return BlocConsumer<AccountsCubit, AccountsState>(
      listener: (context, state) {
        if (state is AccountsActionError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.message ?? l10n.unexpectedError)),
          );
        }
      },
      builder: (context, state) {
        return ShellScaffold(
          title: l10n.accounts,
          body: Stack(
            children: [
              _body(context, state, l10n),
              Positioned(
                right: 16,
                bottom: 16,
                child: FloatingActionButton(
                  onPressed: () => _showAccountBottomSheet(context, l10n),
                  child: const Icon(Icons.add),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _body(BuildContext context, AccountsState state, AppLocalizations l10n) {
    Future<void> refresh() => context.read<AccountsCubit>().load();

    if (state is AccountsLoading || state is AccountsInitial) {
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

    if (state is AccountsError) {
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

    final accounts = switch (state) {
      AccountsLoaded(:final accounts) => accounts,
      AccountsActionError(:final accounts) => accounts,
      _ => <AccountEntity>[],
    };

    if (accounts.isEmpty) {
      return RefreshIndicator(
        onRefresh: refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(bottom: 88),
          children: [
            SizedBox(
              height: MediaQuery.sizeOf(context).height * 0.35,
              child: Center(child: Text(l10n.noAccounts)),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: refresh,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 88),
        itemCount: accounts.length,
        itemBuilder: (context, index) => _AccountTile(account: accounts[index]),
      ),
    );
  }

}

class _AccountTile extends StatelessWidget {
  final AccountEntity account;
  const _AccountTile({required this.account});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cubit = context.read<AccountsCubit>();

    void openEdit() {
      _showAccountBottomSheet(context, l10n, account: account);
    }

    void openTransactions() {
      context.push(
        Uri(
          path: '/transactions',
          queryParameters: {
            'accountId': account.id,
            'accountName': account.name,
          },
        ).toString(),
      );
    }

    return SwipeableListTile(
      itemKey: account.id,
      title: Text(account.name),
      subtitle: account.description != null
          ? Text(account.description!, maxLines: 2, overflow: TextOverflow.ellipsis)
          : null,
      trailing: WalletDualBalanceTrailing(
        l10n: l10n,
        balanceWeighted: account.balanceWeighted,
        balanceCounted: account.balanceCounted,
      ),
      onTap: openTransactions,
      onEdit: openEdit,
      confirmDelete: () async {
        final ok = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: Text(l10n.deleteAccount),
            content: Text(l10n.confirmDeleteAccount(account.name)),
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
      onDeleted: () => cubit.delete(id: account.id),
    );
  }
}

class _AccountEditor extends StatefulWidget {
  final AccountsCubit cubit;
  final AppLocalizations l10n;
  final AccountEntity? account;

  const _AccountEditor({
    required this.cubit,
    required this.l10n,
    this.account,
  });

  @override
  State<_AccountEditor> createState() => _AccountEditorState();
}

class _AccountEditorState extends State<_AccountEditor> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  TextEditingController? _balanceController;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.account?.name ?? '');
    _descriptionController = TextEditingController(text: widget.account?.description ?? '');
    if (widget.account != null) {
      _balanceController = TextEditingController(
        text: widget.account!.balance.toStringAsFixed(2),
      );
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _balanceController?.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    final name = _nameController.text.trim();
    final description = _descriptionController.text.trim().isEmpty ? null : _descriptionController.text.trim();
    try {
      if (widget.account == null) {
        await widget.cubit.create(name: name, description: description);
      } else {
        final targetBalance = double.tryParse(_balanceController!.text.trim());
        if (targetBalance == null) return;
        await widget.cubit.update(
          id: widget.account!.id,
          name: name,
          description: description,
          previousBalance: widget.account!.balance,
          targetBalance: targetBalance,
        );
      }
    } finally {
      if (mounted) Navigator.of(context).pop();
    }
  }

  Widget _formFields(AppLocalizations l10n) {
    return Form(
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
          if (_balanceController != null) ...[
            TextFormField(
              controller: _balanceController,
              decoration: InputDecoration(labelText: l10n.accountBalance),
              keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return l10n.fieldRequired;
                if (double.tryParse(v.trim()) == null) return l10n.fieldRequired;
                return null;
              },
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 8),
          ],
          TextFormField(
            controller: _descriptionController,
            decoration: InputDecoration(labelText: l10n.accountDescription),
            maxLines: 3,
          ),
        ],
      ),
    );
  }

  Widget _submitPrimaryButton(AppLocalizations l10n) {
    final theme = Theme.of(context);
    final label = widget.account == null ? l10n.accountSubmitCreate : l10n.save;
    return SizedBox(
      width: double.infinity,
      child: FilledButton(
        onPressed: _loading ? null : _submit,
        style: FilledButton.styleFrom(
          minimumSize: const Size(double.infinity, 48),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: _loading
            ? SizedBox(
                height: 22,
                width: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: theme.colorScheme.onPrimary,
                ),
              )
            : Text(label),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = widget.l10n;
    final theme = Theme.of(context);
    final title = widget.account == null ? l10n.newAccount : l10n.editAccount;

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              title,
              style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),
            _formFields(l10n),
            const SizedBox(height: 24),
            _submitPrimaryButton(l10n),
          ],
        ),
      ),
    );
  }
}
