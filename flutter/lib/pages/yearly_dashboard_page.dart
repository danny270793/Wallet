import 'package:flutter/material.dart';
import 'package:wallet/l10n/app_localizations.dart';

import '../widgets/shell_scaffold.dart';
import '../widgets/yearly_dashboard_scope.dart';

class YearlyDashboardPage extends StatelessWidget {
  const YearlyDashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return YearlyDashboardHost(
      child: Builder(
        builder: (context) {
          final l10n = AppLocalizations.of(context)!;
          final yearNotifier = YearlyDashboardScope.of(context);
          return ShellScaffold(
            title: l10n.yearlyDashboard,
            appBarBottom: YearlyDashboardAppBarBottom(notifier: yearNotifier),
            body: Center(child: Text(l10n.yearlyDashboard)),
          );
        },
      ),
    );
  }
}
