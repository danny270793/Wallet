import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:wallet/l10n/app_localizations.dart';

import 'transactions_month_scope.dart';

class AppShell extends StatelessWidget {
  final Widget child;

  const AppShell({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final location = GoRouterState.of(context).matchedLocation;

    final transactionsMonthNotifier = TransactionsMonthScope.maybeOf(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(_title(location, l10n)),
        bottom: transactionsMonthNotifier != null
            ? TransactionsMonthAppBarBottom(notifier: transactionsMonthNotifier)
            : null,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => context.push('/settings'),
          ),
        ],
      ),
      drawer: Builder(
        builder: (drawerContext) => NavigationDrawer(
          selectedIndex: _selectedIndex(location),
          onDestinationSelected: (index) {
            Scaffold.of(drawerContext).closeDrawer();
            switch (index) {
              case 0:
                drawerContext.go('/dashboard');
              case 1:
                drawerContext.go('/accounts');
              case 2:
                drawerContext.go('/cards');
              case 3:
                drawerContext.go('/categories');
              case 4:
                drawerContext.go('/tags');
              case 5:
                drawerContext.go('/transactions');
            }
          },
          children: [
            NavigationDrawerDestination(
              icon: const Icon(Icons.dashboard_outlined),
              selectedIcon: const Icon(Icons.dashboard),
              label: Text(l10n.dashboard),
            ),
            NavigationDrawerDestination(
              icon: const Icon(Icons.account_balance_wallet_outlined),
              selectedIcon: const Icon(Icons.account_balance_wallet),
              label: Text(l10n.accounts),
            ),
            NavigationDrawerDestination(
              icon: const Icon(Icons.credit_card_outlined),
              selectedIcon: const Icon(Icons.credit_card),
              label: Text(l10n.cards),
            ),
            NavigationDrawerDestination(
              icon: const Icon(Icons.category_outlined),
              selectedIcon: const Icon(Icons.category),
              label: Text(l10n.categories),
            ),
            NavigationDrawerDestination(
              icon: const Icon(Icons.label_outline),
              selectedIcon: const Icon(Icons.label),
              label: Text(l10n.tags),
            ),
            NavigationDrawerDestination(
              icon: const Icon(Icons.receipt_long_outlined),
              selectedIcon: const Icon(Icons.receipt_long),
              label: Text(l10n.transactions),
            ),
          ],
        ),
      ),
      body: child,
    );
  }

  int _selectedIndex(String location) {
    if (location.startsWith('/accounts')) return 1;
    if (location.startsWith('/cards')) return 2;
    if (location.startsWith('/categories')) return 3;
    if (location.startsWith('/tags')) return 4;
    if (location.startsWith('/transactions')) return 5;
    return 0;
  }

  String _title(String location, AppLocalizations l10n) {
    if (location.startsWith('/accounts')) return l10n.accounts;
    if (location.startsWith('/cards')) return l10n.cards;
    if (location.startsWith('/categories')) return l10n.categories;
    if (location.startsWith('/tags')) return l10n.tags;
    if (location.startsWith('/transactions')) return l10n.transactions;
    return l10n.dashboard;
  }
}
