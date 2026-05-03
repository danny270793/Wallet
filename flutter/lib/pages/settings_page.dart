import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:local_auth/local_auth.dart';
import 'package:wallet/l10n/app_localizations.dart';
import '../core/di/injection.dart';
import '../core/locale/app_locale_controller.dart';
import '../core/security/app_biometric_unlock_controller.dart';
import '../core/theme/app_theme_controller.dart';
import '../features/auth/presentation/cubit/settings_cubit.dart';
import '../features/auth/presentation/cubit/settings_state.dart';
import '../widgets/bottom_sheet_pinned_title.dart';

String _languageOptionLabel(AppLocalizations l10n, AppLanguagePreference p) =>
    switch (p) {
      AppLanguagePreference.system => l10n.settingsLanguageSystem,
      AppLanguagePreference.en => l10n.settingsLanguageEnglish,
      AppLanguagePreference.es => l10n.settingsLanguageSpanish,
    };

String _themeOptionLabel(AppLocalizations l10n, AppThemePreference p) =>
    switch (p) {
      AppThemePreference.system => l10n.settingsThemeSystem,
      AppThemePreference.light => l10n.settingsThemeLight,
      AppThemePreference.dark => l10n.settingsThemeDark,
    };

Future<void> _showLanguagePickerSheet(
  BuildContext context,
  AppLocalizations l10n,
  AppLocaleController ctrl,
) async {
  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: false,
    isScrollControlled: true,
    builder: (sheetContext) => BottomSheetPinnedTitleScrollView(
      padding: EdgeInsets.zero,
      title: l10n.settingsLanguage,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final option in AppLanguagePreference.values)
            ListTile(
              title: Text(_languageOptionLabel(l10n, option)),
              trailing: ctrl.preference == option
                  ? Icon(
                      Icons.check,
                      color: Theme.of(sheetContext).colorScheme.primary,
                    )
                  : null,
              onTap: () async {
                await ctrl.setPreference(option);
                if (sheetContext.mounted) Navigator.of(sheetContext).pop();
              },
            ),
        ],
      ),
    ),
  );
}

Future<void> _showThemePickerSheet(
  BuildContext context,
  AppLocalizations l10n,
  AppThemeController ctrl,
) async {
  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: false,
    isScrollControlled: true,
    builder: (sheetContext) => BottomSheetPinnedTitleScrollView(
      padding: EdgeInsets.zero,
      title: l10n.settingsTheme,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final option in AppThemePreference.values)
            ListTile(
              title: Text(_themeOptionLabel(l10n, option)),
              trailing: ctrl.preference == option
                  ? Icon(
                      Icons.check,
                      color: Theme.of(sheetContext).colorScheme.primary,
                    )
                  : null,
              onTap: () async {
                await ctrl.setPreference(option);
                if (sheetContext.mounted) Navigator.of(sheetContext).pop();
              },
            ),
        ],
      ),
    ),
  );
}

Future<void> _setBiometricUnlockEnabled(
  BuildContext context,
  AppLocalizations l10n,
  AppBiometricUnlockController ctrl,
  bool enabled,
) async {
  if (!enabled) {
    await ctrl.setEnabled(false);
    return;
  }
  await ctrl.refreshAuthenticatorAvailability();
  if (!ctrl.authenticatorAvailable) {
    if (context.mounted) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(content: Text(l10n.settingsBiometricUnavailable)),
      );
    }
    return;
  }
  final ok = await ctrl.localAuth.authenticate(
    localizedReason: l10n.settingsBiometricAuthReason,
    options: const AuthenticationOptions(
      biometricOnly: true,
      stickyAuth: true,
    ),
  );
  if (!context.mounted) {
    return;
  }
  if (ok) {
    await ctrl.setEnabled(true);
  }
}

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(getIt<AppBiometricUnlockController>().refreshAuthenticatorAvailability());
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return BlocProvider(
      create: (_) => getIt<SettingsCubit>(),
      child: BlocListener<SettingsCubit, SettingsState>(
        listener: (context, state) {
          if (state is SettingsSignedOut) {
            context.go('/login');
          }
        },
        child: Scaffold(
          appBar: AppBar(title: Text(l10n.settings)),
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                Text(
                  l10n.settingsAppearance,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                ListenableBuilder(
                  listenable: getIt<AppLocaleController>(),
                  builder: (context, _) {
                    final ctrl = getIt<AppLocaleController>();
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(
                        Icons.language_outlined,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      title: Text(l10n.settingsLanguage),
                      subtitle: Text(
                        _languageOptionLabel(l10n, ctrl.preference),
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () =>
                          _showLanguagePickerSheet(context, l10n, ctrl),
                    );
                  },
                ),
                ListenableBuilder(
                  listenable: getIt<AppThemeController>(),
                  builder: (context, _) {
                    final ctrl = getIt<AppThemeController>();
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(
                        Icons.palette_outlined,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      title: Text(l10n.settingsTheme),
                      subtitle: Text(_themeOptionLabel(l10n, ctrl.preference)),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => _showThemePickerSheet(context, l10n, ctrl),
                    );
                  },
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Divider(height: 1),
                ),
                Text(
                  l10n.settingsSecuritySection,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                ListenableBuilder(
                  listenable: getIt<AppBiometricUnlockController>(),
                  builder: (context, _) {
                    final bio = getIt<AppBiometricUnlockController>();
                    return SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      secondary: Icon(
                        Icons.fingerprint_rounded,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      title: Text(l10n.settingsBiometricUnlockTitle),
                      subtitle: Text(
                        bio.authenticatorAvailable
                            ? l10n.settingsBiometricUnlockSubtitle
                            : l10n.settingsBiometricUnavailable,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          height: 1.35,
                        ),
                      ),
                      value: bio.enabled,
                      onChanged: bio.authenticatorAvailable
                          ? (v) => _setBiometricUnlockEnabled(
                                context,
                                l10n,
                                bio,
                                v,
                              )
                          : null,
                    );
                  },
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Divider(height: 1),
                ),
                Text(
                  l10n.settingsAboutSection,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    Icons.info_outline_rounded,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  title: Text(l10n.settingsAboutApp),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/settings/about'),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    Icons.privacy_tip_outlined,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  title: Text(l10n.settingsPrivacyPolicy),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/settings/privacy'),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    Icons.description_outlined,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  title: Text(l10n.settingsTermsOfUse),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/settings/terms'),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Divider(height: 1),
                ),
                BlocBuilder<SettingsCubit, SettingsState>(
                  builder: (context, state) {
                    final signOutStyle = FilledButton.styleFrom(
                      backgroundColor: theme.colorScheme.error,
                      foregroundColor: theme.colorScheme.onError,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    );
                    return SizedBox(
                      width: double.infinity,
                      child: state is SettingsLoading
                          ? FilledButton(
                              style: signOutStyle,
                              onPressed: null,
                              child: SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: theme.colorScheme.onError,
                                ),
                              ),
                            )
                          : FilledButton.icon(
                              style: signOutStyle,
                              onPressed: () =>
                                  context.read<SettingsCubit>().signOut(),
                              icon: const Icon(Icons.logout_rounded),
                              label: Text(l10n.signOut),
                            ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
