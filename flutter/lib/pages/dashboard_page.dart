import 'package:flutter/material.dart';
import 'package:wallet/l10n/app_localizations.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(child: Text(AppLocalizations.of(context)!.dashboard));
  }
}
