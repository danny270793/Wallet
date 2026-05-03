import 'dart:async';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import 'package:wallet/l10n/app_localizations.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/di/injection.dart';
import 'core/locale/app_locale_controller.dart';
import 'core/security/app_biometric_unlock_controller.dart';
import 'core/theme/app_theme_controller.dart';
import 'core/logger/app_logger.dart';
import 'core/wallet_actions/wallet_actions_reporter.dart';
import 'router.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  AppLogger.info('initializing Supabase');
  await Supabase.initialize(
    url: const String.fromEnvironment('SUPABASE_URL'),
    anonKey: const String.fromEnvironment('SUPABASE_ANON_KEY'),
  );
  AppLogger.info('Supabase initialized');

  setupDi();
  AppLogger.info('DI setup complete');
  await getIt<AppLocaleController>().load();
  await getIt<AppThemeController>().load();
  await getIt<AppBiometricUnlockController>().load();
  _bindGlobalErrorReporting();

  runApp(const App());
}

void _bindGlobalErrorReporting() {
  final reporter = getIt<WalletActionsReporter>();
  FlutterError.onError = (details) {
    reporter.recordFlutterError(details);
    FlutterError.presentError(details);
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    reporter.recordUncaught(error, stack);
    return true;
  };
}

class App extends StatefulWidget {
  const App({super.key});

  static Locale? _resolveDeviceLocale(
    Locale? deviceLocale,
    Iterable<Locale> supported,
  ) {
    if (deviceLocale == null) return supported.first;
    for (final loc in supported) {
      if (loc.languageCode == deviceLocale.languageCode) return loc;
    }
    return supported.first;
  }

  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> with WidgetsBindingObserver {
  /// True after [AppLifecycleState.paused]; cleared on resume so cold start does not lock.
  bool _shouldUnlockOnNextResume = false;

  /// Full-screen gate: no router navigation visible until cleared.
  bool _biometricLockActive = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _shouldUnlockOnNextResume = true;
    } else if (state == AppLifecycleState.resumed &&
        _shouldUnlockOnNextResume) {
      _shouldUnlockOnNextResume = false;
      unawaited(_activateBiometricLockIfNeeded());
    }
  }

  Future<void> _activateBiometricLockIfNeeded() async {
    if (Supabase.instance.client.auth.currentSession == null) return;
    final bio = getIt<AppBiometricUnlockController>();
    await bio.refreshAuthenticatorAvailability();
    if (!bio.enabled || !bio.authenticatorAvailable) return;
    if (!mounted) return;
    setState(() => _biometricLockActive = true);
  }

  void _clearBiometricLock() {
    if (_biometricLockActive) {
      setState(() => _biometricLockActive = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final appLocale = getIt<AppLocaleController>();
    final appTheme = getIt<AppThemeController>();
    return ListenableBuilder(
      listenable: Listenable.merge([appLocale, appTheme]),
      builder: (context, _) {
        final seed = Colors.deepPurple;
        return MaterialApp.router(
          onGenerateTitle: (context) => AppLocalizations.of(context)!.appTitle,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: appLocale.materialAppLocale,
          localeResolutionCallback: App._resolveDeviceLocale,
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(seedColor: seed),
            useMaterial3: true,
            bottomSheetTheme: const BottomSheetThemeData(
              clipBehavior: Clip.antiAlias,
            ),
          ),
          darkTheme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: seed,
              brightness: Brightness.dark,
            ),
            useMaterial3: true,
            bottomSheetTheme: const BottomSheetThemeData(
              clipBehavior: Clip.antiAlias,
            ),
          ),
          themeMode: appTheme.themeMode,
          routerConfig: router,
          builder: (context, child) {
            if (_biometricLockActive) {
              return PopScope(
                canPop: false,
                child: _BiometricLockScreen(
                  onUnlocked: _clearBiometricLock,
                ),
              );
            }
            return child ?? const SizedBox.shrink();
          },
        );
      },
    );
  }
}

class _BiometricLockScreen extends StatefulWidget {
  const _BiometricLockScreen({required this.onUnlocked});

  final VoidCallback onUnlocked;

  @override
  State<_BiometricLockScreen> createState() => _BiometricLockScreenState();
}

class _BiometricLockScreenState extends State<_BiometricLockScreen> {
  /// True while refresh + system biometric UI may be active — disables the Unlock button.
  bool _busy = false;

  /// Prevents overlapping [_attemptUnlock] runs (e.g. double-tap before first await).
  bool _unlockInFlight = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _attemptUnlock());
  }

  Future<void> _attemptUnlock() async {
    if (!mounted) return;

    if (Supabase.instance.client.auth.currentSession == null) {
      widget.onUnlocked();
      return;
    }

    if (_unlockInFlight) return;
    _unlockInFlight = true;
    setState(() => _busy = true);

    try {
      final bio = getIt<AppBiometricUnlockController>();
      await bio.refreshAuthenticatorAvailability();
      if (!mounted) return;

      if (!bio.enabled || !bio.authenticatorAvailable) {
        widget.onUnlocked();
        return;
      }

      final l10n = AppLocalizations.of(context);
      if (l10n == null) return;

      final ok = await bio.localAuth.authenticate(
        localizedReason: l10n.settingsBiometricResumeReason,
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
        ),
      );
      if (!mounted) return;

      if (ok) {
        widget.onUnlocked();
      }
    } finally {
      _unlockInFlight = false;
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Material(
      color: scheme.surface,
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.lock_outline_rounded,
                  size: 56,
                  color: scheme.primary,
                ),
                const SizedBox(height: 20),
                Text(
                  l10n.biometricLockTitle,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  l10n.biometricLockBody,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: scheme.onSurfaceVariant,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 28),
                FilledButton.icon(
                  onPressed: _busy ? null : _attemptUnlock,
                  icon: _busy
                      ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: scheme.onPrimary,
                          ),
                        )
                      : const Icon(Icons.fingerprint_rounded),
                  label: Text(l10n.biometricLockUnlockButton),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
