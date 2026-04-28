import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:wallet/l10n/app_localizations.dart';

class AppShell extends StatelessWidget {
  final Widget child;

  const AppShell({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final location = GoRouterState.of(context).matchedLocation;

    return Scaffold(
      appBar: AppBar(
        title: Text(_title(location, l10n)),
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
          ],
        ),
      ),
      body: child,
    );
  }

  int _selectedIndex(String location) {
    if (location.startsWith('/accounts')) return 1;
    return 0;
  }

  String _title(String location, AppLocalizations l10n) {
    if (location.startsWith('/accounts')) return l10n.accounts;
    return l10n.dashboard;
  }
}
