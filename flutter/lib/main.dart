import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:wallet/l10n/app_localizations.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/di/injection.dart';
import 'core/locale/app_locale_controller.dart';
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

class App extends StatelessWidget {
  const App({super.key});

  static Locale? _resolveDeviceLocale(Locale? deviceLocale, Iterable<Locale> supported) {
    if (deviceLocale == null) return supported.first;
    for (final loc in supported) {
      if (loc.languageCode == deviceLocale.languageCode) return loc;
    }
    return supported.first;
  }

  @override
  Widget build(BuildContext context) {
    final appLocale = getIt<AppLocaleController>();
    return ListenableBuilder(
      listenable: appLocale,
      builder: (context, _) {
        return MaterialApp.router(
          onGenerateTitle: (context) => AppLocalizations.of(context)!.appTitle,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: appLocale.materialAppLocale,
          localeResolutionCallback: _resolveDeviceLocale,
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
          ),
          routerConfig: router,
        );
      },
    );
  }
}
