import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:wallet/l10n/app_localizations.dart';
import '../core/di/injection.dart';
import '../features/accounts/domain/entities/account_entity.dart';
import '../features/accounts/presentation/cubit/accounts_cubit.dart';
import '../features/accounts/presentation/cubit/accounts_state.dart';
import '../widgets/account_editor_sheet.dart';
import '../widgets/shell_scaffold.dart';
import '../widgets/swipeable_list_tile.dart';
import '../widgets/wallet_dual_balance_trailing.dart';

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
        final accounts = switch (state) {
          AccountsLoaded(:final accounts) => accounts,
          AccountsActionError(:final accounts) => accounts,
          _ => <AccountEntity>[],
        };
        final showTotalBar = accounts.isNotEmpty;
        final totalBalance =
            showTotalBar ? accounts.fold<double>(0, (s, a) => s + a.balance) : 0.0;

        return ShellScaffold(
          title: l10n.accounts,
          floatingActionButton: FloatingActionButton(
            onPressed: () => showAccountEditorBottomSheet(
              context,
              l10n,
              cubit: context.read<AccountsCubit>(),
            ),
            child: const Icon(Icons.add),
          ),
          bottomNavigationBar: showTotalBar
              ? WalletListBalanceTotalBar(
                  l10n: l10n,
                  total: totalBalance,
                )
              : null,
          body: _body(context, state, l10n),
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
        padding: const EdgeInsets.only(bottom: 8),
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
      showAccountEditorBottomSheet(
        context,
        l10n,
        account: account,
        cubit: context.read<AccountsCubit>(),
      );
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
      trailing: WalletListBalanceAmount(
        l10n: l10n,
        balance: account.balance,
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
