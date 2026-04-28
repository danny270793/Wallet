import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
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

    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        child: switch (kind) {
          LegalInfoKind.about => _AboutBody(l10n: l10n),
          LegalInfoKind.privacy => _PrivacyBody(l10n: l10n),
          LegalInfoKind.terms => _TermsBody(l10n: l10n),
        },
      ),
    );
  }
}

class _AboutBody extends StatelessWidget {
  const _AboutBody({required this.l10n});

  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: CircleAvatar(
              radius: 40,
              backgroundColor: scheme.primaryContainer,
              child: Icon(
                Icons.account_balance_wallet_rounded,
                size: 40,
                color: scheme.onPrimaryContainer,
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            l10n.appTitle,
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.settingsAboutTagline,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: scheme.onSurfaceVariant,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 20),
          FutureBuilder<PackageInfo>(
            future: PackageInfo.fromPlatform(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: scheme.primary,
                      ),
                    ),
                  ),
                );
              }
              final info = snapshot.data!;
              final label = l10n.settingsAboutVersionLabel;
              final v = info.version;
              final b = info.buildNumber;
              final line = b.isNotEmpty ? '$label $v ($b)' : '$label $v';
              return Text(
                line,
                textAlign: TextAlign.center,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: scheme.onSurfaceVariant,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              );
            },
          ),
          const SizedBox(height: 28),
          Text(
            l10n.settingsAboutFeaturesHeading,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 14),
          _AboutBullet(
            icon: Icons.account_balance_wallet_outlined,
            text: l10n.settingsAboutBulletAccounts,
          ),
          _AboutBullet(
            icon: Icons.receipt_long_outlined,
            text: l10n.settingsAboutBulletLedger,
          ),
          _AboutBullet(
            icon: Icons.calendar_month_outlined,
            text: l10n.settingsAboutBulletMonth,
          ),
          const SizedBox(height: 28),
          Text(
            l10n.settingsAboutDataHeading,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          SelectableText(
            l10n.settingsAboutDataBody,
            style: theme.textTheme.bodyLarge?.copyWith(
              height: 1.45,
              color: scheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}

class _PrivacyBody extends StatelessWidget {
  const _PrivacyBody({required this.l10n});

  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: CircleAvatar(
              radius: 36,
              backgroundColor: scheme.tertiaryContainer,
              child: Icon(
                Icons.privacy_tip_outlined,
                size: 36,
                color: scheme.onTertiaryContainer,
              ),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            l10n.settingsPrivacyPolicy,
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.settingsPrivacyTagline,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: scheme.onSurfaceVariant,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 28),
          _PolicySection(
            title: l10n.settingsPrivacyDataTitle,
            body: l10n.settingsPrivacyDataBody,
          ),
          _PolicySection(
            title: l10n.settingsPrivacyInfraTitle,
            body: l10n.settingsPrivacyInfraBody,
          ),
          _PolicyCallout(
            title: l10n.settingsPrivacySharingTitle,
            body: l10n.settingsPrivacySharingBody,
          ),
          _PolicySection(
            title: l10n.settingsPrivacyNoticeTitle,
            body: l10n.settingsPrivacyNoticeBody,
          ),
        ],
      ),
    );
  }
}

class _TermsBody extends StatelessWidget {
  const _TermsBody({required this.l10n});

  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: CircleAvatar(
              radius: 36,
              backgroundColor: scheme.secondaryContainer,
              child: Icon(
                Icons.article_outlined,
                size: 36,
                color: scheme.onSecondaryContainer,
              ),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            l10n.settingsTermsOfUse,
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.settingsTermsTagline,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: scheme.onSurfaceVariant,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 28),
          _PolicySection(
            title: l10n.settingsTermsAcceptanceTitle,
            body: l10n.settingsTermsAcceptanceBody,
          ),
          _PolicyCallout(
            title: l10n.settingsTermsDisclaimerTitle,
            body: l10n.settingsTermsDisclaimerBody,
            icon: Icons.info_outline,
          ),
          _PolicySection(
            title: l10n.settingsTermsLiabilityTitle,
            body: l10n.settingsTermsLiabilityBody,
          ),
          _PolicySection(
            title: l10n.settingsTermsResponsibilitiesTitle,
            body: l10n.settingsTermsResponsibilitiesBody,
          ),
          _PolicySection(
            title: l10n.settingsTermsNoticeTitle,
            body: l10n.settingsTermsNoticeBody,
          ),
        ],
      ),
    );
  }
}

class _PolicySection extends StatelessWidget {
  const _PolicySection({
    required this.title,
    required this.body,
  });

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          SelectableText(
            body,
            style: theme.textTheme.bodyLarge?.copyWith(
              height: 1.45,
              color: theme.colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}

class _PolicyCallout extends StatelessWidget {
  const _PolicyCallout({
    required this.title,
    required this.body,
    this.icon = Icons.shield_outlined,
  });

  final String title;
  final String body;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          DecoratedBox(
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.5)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    icon,
                    size: 24,
                    color: scheme.primary,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: SelectableText(
                      body,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        height: 1.45,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AboutBullet extends StatelessWidget {
  const _AboutBullet({
    required this.icon,
    required this.text,
  });

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 22, color: scheme.primary),
          const SizedBox(width: 14),
          Expanded(
            child: SelectableText(
              text,
              style: theme.textTheme.bodyLarge?.copyWith(height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}
