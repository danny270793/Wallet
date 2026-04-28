import 'package:flutter/material.dart';
import 'package:wallet/l10n/app_localizations.dart';

import '../widgets/shell_scaffold.dart';
import '../widgets/transactions_month_scope.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return TransactionsMonthHost(
      child: Builder(
        builder: (context) {
          final l10n = AppLocalizations.of(context)!;
          final monthNotifier = TransactionsMonthScope.of(context);
          return ShellScaffold(
            title: l10n.monthlyDashboard,
            appBarBottom: TransactionsMonthAppBarBottom(notifier: monthNotifier),
            body: Center(child: Text(l10n.monthlyDashboard)),
          );
        },
      ),
    );
  }
}
