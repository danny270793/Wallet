import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:wallet/l10n/app_localizations.dart';
import '../core/di/injection.dart';
import '../features/accounts/domain/entities/account_entity.dart';
import '../features/accounts/presentation/cubit/accounts_cubit.dart';
import '../features/accounts/presentation/cubit/accounts_state.dart';

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
        return Stack(
          children: [
            _body(context, state, l10n),
            Positioned(
              right: 16,
              bottom: 16,
              child: FloatingActionButton(
                onPressed: () => _showAccountDialog(context, l10n),
                child: const Icon(Icons.add),
              ),
            ),
          ],
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

  void _showAccountDialog(BuildContext context, AppLocalizations l10n, [AccountEntity? account]) {
    showDialog<void>(
      context: context,
      builder: (_) => _AccountDialog(
        cubit: context.read<AccountsCubit>(),
        l10n: l10n,
        account: account,
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

    return ListTile(
      title: Text(account.name),
      subtitle: account.description != null ? Text(account.description!, maxLines: 2, overflow: TextOverflow.ellipsis) : null,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => showDialog<void>(
              context: context,
              builder: (_) => _AccountDialog(
                cubit: context.read<AccountsCubit>(),
                l10n: l10n,
                account: account,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outlined),
            onPressed: () => _confirmDelete(context, l10n),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, AppLocalizations l10n) async {
    final cubit = context.read<AccountsCubit>();
    final confirmed = await showDialog<bool>(
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
    if (confirmed == true) {
      cubit.delete(id: account.id);
    }
  }
}

class _AccountDialog extends StatefulWidget {
  final AccountsCubit cubit;
  final AppLocalizations l10n;
  final AccountEntity? account;

  const _AccountDialog({required this.cubit, required this.l10n, this.account});

  @override
  State<_AccountDialog> createState() => _AccountDialogState();
}

class _AccountDialogState extends State<_AccountDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.account?.name ?? '');
    _descriptionController = TextEditingController(text: widget.account?.description ?? '');
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
      if (widget.account == null) {
        await widget.cubit.create(name: name, description: description);
      } else {
        await widget.cubit.update(id: widget.account!.id, name: name, description: description);
      }
    } finally {
      if (mounted) Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = widget.l10n;
    final isEdit = widget.account != null;

    return AlertDialog(
      title: Text(isEdit ? l10n.editAccount : l10n.newAccount),
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
