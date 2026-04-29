import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:wallet/l10n/app_localizations.dart';

/// Drawer destination index aligned with [WalletNavigationDrawer] items.
int walletDrawerSelectedIndex(String matchedLocation) {
  if (matchedLocation.startsWith('/transactions')) return 0;
  if (matchedLocation.startsWith('/accounts')) return 1;
  if (matchedLocation.startsWith('/cards')) return 2;
  if (matchedLocation.startsWith('/categories')) return 3;
  if (matchedLocation.startsWith('/tags')) return 4;
  if (matchedLocation.startsWith('/assets')) return 5;
  if (matchedLocation.startsWith('/dashboard/yearly')) return 7;
  if (matchedLocation.startsWith('/dashboard/monthly')) return 6;
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
            router.go('/transactions');
            break;
          case 1:
            router.go('/accounts');
            break;
          case 2:
            router.go('/cards');
            break;
          case 3:
            router.go('/categories');
            break;
          case 4:
            router.go('/tags');
            break;
          case 5:
            router.go('/assets');
            break;
          case 6:
            router.go('/dashboard/monthly');
            break;
          case 7:
            router.go('/dashboard/yearly');
            break;
        }
      },
      children: [
        NavigationDrawerDestination(
          icon: const Icon(Icons.receipt_long_outlined),
          selectedIcon: const Icon(Icons.receipt_long),
          label: Text(l10n.transactions),
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
          icon: const Icon(Icons.inventory_2_outlined),
          selectedIcon: const Icon(Icons.inventory_2),
          label: Text(l10n.assets),
        ),
        NavigationDrawerDestination(
          icon: const Icon(Icons.calendar_month_outlined),
          selectedIcon: const Icon(Icons.calendar_month),
          label: Text(l10n.monthlyDashboard),
        ),
        NavigationDrawerDestination(
          icon: const Icon(Icons.date_range_outlined),
          selectedIcon: const Icon(Icons.date_range),
          label: Text(l10n.yearlyDashboard),
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

  /// When false, no navigation drawer is shown and the app bar uses a back control if the route can pop.
  final bool useDrawer;
  final Widget? bottomNavigationBar;
  final Widget? floatingActionButton;
  final FloatingActionButtonLocation? floatingActionButtonLocation;

  /// Shown before the settings action (e.g. search on transactions).
  final List<Widget>? appBarActionsBeforeSettings;

  const ShellScaffold({
    super.key,
    required this.title,
    this.appBarBottom,
    required this.body,
    this.useDrawer = true,
    this.bottomNavigationBar,
    this.floatingActionButton,
    this.floatingActionButtonLocation,
    this.appBarActionsBeforeSettings,
  });

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;

    return Scaffold(
      drawer: useDrawer
          ? WalletNavigationDrawer(
              selectedIndex: walletDrawerSelectedIndex(location),
            )
          : null,
      appBar: AppBar(
        title: Text(title),
        bottom: appBarBottom,
        actions: [
          ...?appBarActionsBeforeSettings,
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => context.push('/settings'),
          ),
        ],
      ),
      body: body,
      bottomNavigationBar: bottomNavigationBar,
      floatingActionButton: floatingActionButton,
      floatingActionButtonLocation: floatingActionButtonLocation,
    );
  }
}
