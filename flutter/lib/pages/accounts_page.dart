import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:wallet/l10n/app_localizations.dart';

import '../core/di/injection.dart';
import '../features/accounts/domain/entities/account_entity.dart';
import '../features/accounts/presentation/cubit/accounts_cubit.dart';
import '../features/accounts/presentation/cubit/accounts_state.dart';
import '../widgets/account_editor_sheet.dart';
import '../widgets/offline_cached_data_banner.dart';
import '../widgets/remote_load_failure_panel.dart';
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

class _AccountsView extends StatefulWidget {
  const _AccountsView();

  @override
  State<_AccountsView> createState() => _AccountsViewState();
}

class _AccountsViewState extends State<_AccountsView> {
  /// Ids picked in multi-select mode (entered by long-pressing a row).
  final Set<String> _selectedIds = {};

  /// Selected rows that still exist; select mode is on while this is non-empty.
  List<AccountEntity> _selectedAmong(List<AccountEntity> items) =>
      items.where((e) => _selectedIds.contains(e.id)).toList();

  void _toggleSelected(String id, List<AccountEntity> items) {
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
        final selected = _selectedAmong(accounts);
        final selecting = selected.isNotEmpty;
        final showTotalBar = accounts.isNotEmpty;
        final totalBalance = showTotalBar
            ? (selecting ? selected : accounts).fold<double>(
                0,
                (s, a) => s + a.balance,
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
                : l10n.accounts,
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
              onPressed: () => showAccountEditorBottomSheet(
                context,
                l10n,
                cubit: context.read<AccountsCubit>(),
              ),
              child: const Icon(Icons.add),
            ),
            bottomNavigationBar: showTotalBar
                ? WalletListBalanceTotalBar(l10n: l10n, total: totalBalance)
                : null,
            body: _body(context, state, l10n),
          ),
        );
      },
    );
  }

  Widget _body(
    BuildContext context,
    AccountsState state,
    AppLocalizations l10n,
  ) {
    Future<void> pullRefresh() =>
        context.read<AccountsCubit>().load(showLoading: false);

    Future<void> reloadWithOverlay() =>
        context.read<AccountsCubit>().load(showLoading: true);

    if (state is AccountsLoading || state is AccountsInitial) {
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

    if (state is AccountsError) {
      return RemoteLoadFailurePanel(
        l10n: l10n,
        failure: state.failure,
        onRetry: reloadWithOverlay,
      );
    }

    final offlineCached = switch (state) {
      AccountsLoaded(:final servedFromOfflineCache) => servedFromOfflineCache,
      AccountsActionError(:final servedFromOfflineCache) =>
        servedFromOfflineCache,
      _ => false,
    };

    final accounts = switch (state) {
      AccountsLoaded(:final accounts) => accounts,
      AccountsActionError(:final accounts) => accounts,
      _ => <AccountEntity>[],
    };

    if (accounts.isEmpty) {
      return RefreshIndicator(
        onRefresh: pullRefresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(bottom: 88),
          children: [
            OfflineCachedDataBanner(visible: offlineCached),
            SizedBox(
              height: MediaQuery.sizeOf(context).height * 0.3,
              child: Center(child: Text(l10n.noAccounts)),
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
        itemCount: accounts.length + (offlineCached ? 1 : 0),
        itemBuilder: (context, index) {
          if (offlineCached && index == 0) {
            return const OfflineCachedDataBanner(visible: true);
          }
          final i = index - (offlineCached ? 1 : 0);
          final account = accounts[i];
          return _AccountTile(
            account: account,
            selecting: _selectedAmong(accounts).isNotEmpty,
            selected: _selectedIds.contains(account.id),
            onToggleSelected: () => _toggleSelected(account.id, accounts),
          );
        },
      ),
    );
  }
}

class _AccountTile extends StatelessWidget {
  final AccountEntity account;

  /// In select mode a tap toggles selection and swipe actions are disabled.
  final bool selecting;
  final bool selected;
  final VoidCallback onToggleSelected;

  const _AccountTile({
    required this.account,
    required this.selecting,
    required this.selected,
    required this.onToggleSelected,
  });

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

    Future<void> openTransactions() async {
      await context.push(
        Uri(
          path: '/transactions',
          queryParameters: {
            'accountId': account.id,
            'accountName': account.name,
          },
        ).toString(),
      );
      if (!context.mounted) return;
      await context.read<AccountsCubit>().load(showLoading: false);
    }

    return SwipeableListTile(
      itemKey: account.id,
      title: Text(account.name),
      trailing: WalletListBalanceAmount(l10n: l10n, balance: account.balance),
      selected: selected,
      swipeEnabled: !selecting,
      onTap: selecting ? onToggleSelected : openTransactions,
      onLongPress: onToggleSelected,
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
      onDelete: () => cubit.delete(id: account.id),
    );
  }
}
