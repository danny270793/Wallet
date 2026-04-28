import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:wallet/l10n/app_localizations.dart';

/// Drawer destination index aligned with [WalletNavigationDrawer] items.
int walletDrawerSelectedIndex(String matchedLocation) {
  if (matchedLocation.startsWith('/accounts')) return 1;
  if (matchedLocation.startsWith('/cards')) return 2;
  if (matchedLocation.startsWith('/categories')) return 3;
  if (matchedLocation.startsWith('/tags')) return 4;
  if (matchedLocation.startsWith('/transactions')) return 5;
  return 0;
}

/// Shared drawer for main shell destinations.
class WalletNavigationDrawer extends StatelessWidget {
  final int selectedIndex;

  const WalletNavigationDrawer({super.key, required this.selectedIndex});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final router = GoRouter.of(context);

    return NavigationDrawer(
      selectedIndex: selectedIndex,
      onDestinationSelected: (index) {
        Scaffold.of(context).closeDrawer();
        switch (index) {
          case 0:
            router.go('/dashboard');
          case 1:
            router.go('/accounts');
          case 2:
            router.go('/cards');
          case 3:
            router.go('/categories');
          case 4:
            router.go('/tags');
          case 5:
            router.go('/transactions');
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
    );
  }
}

/// [Scaffold] with drawer and app bar used by shell routes.
class ShellScaffold extends StatelessWidget {
  final String title;
  final PreferredSizeWidget? appBarBottom;
  final Widget body;

  const ShellScaffold({
    super.key,
    required this.title,
    this.appBarBottom,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;

    return Scaffold(
      drawer: WalletNavigationDrawer(
        selectedIndex: walletDrawerSelectedIndex(location),
      ),
      appBar: AppBar(
        title: Text(title),
        bottom: appBarBottom,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => context.push('/settings'),
          ),
        ],
      ),
      body: body,
    );
  }
}
