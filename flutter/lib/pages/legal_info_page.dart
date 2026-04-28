import 'package:flutter/material.dart';
import 'package:wallet/l10n/app_localizations.dart';

/// Static information screens linked from Settings → About.
enum LegalInfoKind {
  about,
  privacy,
  terms,
}

class LegalInfoPage extends StatelessWidget {
  const LegalInfoPage({super.key, required this.kind});

  final LegalInfoKind kind;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    final (String title, String body) = switch (kind) {
      LegalInfoKind.about => (l10n.settingsAboutApp, l10n.settingsAboutBody),
      LegalInfoKind.privacy => (l10n.settingsPrivacyPolicy, l10n.settingsPrivacyBody),
      LegalInfoKind.terms => (l10n.settingsTermsOfUse, l10n.settingsTermsBody),
    };

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
          child: SelectableText(
            body,
            style: theme.textTheme.bodyLarge?.copyWith(
              height: 1.45,
              color: theme.colorScheme.onSurface,
            ),
          ),
        ),
      ),
    );
  }
}
