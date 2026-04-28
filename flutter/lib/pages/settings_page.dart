import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:wallet/l10n/app_localizations.dart';
import '../core/di/injection.dart';
import '../core/locale/app_locale_controller.dart';
import '../features/auth/presentation/cubit/settings_cubit.dart';
import '../features/auth/presentation/cubit/settings_state.dart';

String _languageOptionLabel(AppLocalizations l10n, AppLanguagePreference p) =>
    switch (p) {
      AppLanguagePreference.system => l10n.settingsLanguageSystem,
      AppLanguagePreference.en => l10n.settingsLanguageEnglish,
      AppLanguagePreference.es => l10n.settingsLanguageSpanish,
    };

Future<void> _showLanguagePickerSheet(
  BuildContext context,
  AppLocalizations l10n,
  AppLocaleController ctrl,
) async {
  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) {
      final theme = Theme.of(sheetContext);
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
              child: Text(
                l10n.settingsLanguage,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            ...AppLanguagePreference.values.map((option) {
              final selected = ctrl.preference == option;
              return ListTile(
                title: Text(_languageOptionLabel(l10n, option)),
                trailing: selected
                    ? Icon(Icons.check, color: theme.colorScheme.primary)
                    : null,
                onTap: () async {
                  await ctrl.setPreference(option);
                  if (sheetContext.mounted) Navigator.of(sheetContext).pop();
                },
              );
            }),
            const SizedBox(height: 8),
          ],
        ),
      );
    },
  );
}

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

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
                    return Card(
                      clipBehavior: Clip.antiAlias,
                      child: ListTile(
                        title: Text(l10n.settingsLanguage),
                        subtitle: Text(
                          _languageOptionLabel(l10n, ctrl.preference),
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => _showLanguagePickerSheet(context, l10n, ctrl),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 24),
                BlocBuilder<SettingsCubit, SettingsState>(
                  builder: (context, state) {
                    return SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: theme.colorScheme.error,
                          foregroundColor: theme.colorScheme.onError,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        onPressed: state is SettingsLoading
                            ? null
                            : () => context.read<SettingsCubit>().signOut(),
                        child: state is SettingsLoading
                            ? SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: theme.colorScheme.onError,
                                ),
                              )
                            : Text(l10n.signOut),
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
