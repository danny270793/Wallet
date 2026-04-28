import 'package:flutter/material.dart';
import 'package:wallet/l10n/app_localizations.dart';

import '../widgets/shell_scaffold.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return ShellScaffold(
      title: l10n.dashboard,
      body: Center(child: Text(l10n.dashboard)),
    );
  }
}
