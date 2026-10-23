import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:wallet/core/demo/demo_mode.dart';
import 'package:wallet/core/di/injection.dart';
import 'package:wallet/l10n/app_localizations.dart';
import 'package:wallet/router.dart';

/// Boots the real router with demo data and visits every route, so a screen
/// that cannot render (or reaches for Supabase) fails here.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('dev.fluttercommunity.plus/connectivity'),
          (call) async => ['wifi'],
        );
    await Supabase.initialize(
      url: 'http://localhost:54321',
      anonKey: 'test',
      authOptions: FlutterAuthClientOptions(
        localStorage: const EmptyLocalStorage(),
        pkceAsyncStorage: _MemoryAsyncStorage(),
      ),
    );
    setupDi();
  });

  tearDown(() => DemoMode.instance.exit());

  const routes = [
    '/transactions',
    '/credits',
    '/accounts',
    '/cards',
    '/loans',
    '/recurring-movements',
    '/categories',
    '/tags',
    '/assets',
    '/dashboard/monthly',
    '/dashboard/yearly',
    '/settings',
    '/settings/cache',
  ];

  Future<void> pumpApp(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1000, 2400);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp.router(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        routerConfig: router,
      ),
    );
    await tester.pumpAndSettle(const Duration(milliseconds: 100));
  }

  testWidgets('without a session the router sends you to login', (
    tester,
  ) async {
    await pumpApp(tester);
    expect(find.text('Try demo'), findsOneWidget);
  });

  testWidgets('Try demo opens the app, every route renders, exit returns', (
    tester,
  ) async {
    await pumpApp(tester);

    await tester.tap(find.text('Try demo'));
    await tester.pumpAndSettle(const Duration(milliseconds: 100));
    expect(DemoMode.instance.isActive, isTrue);
    expect(find.text('Try demo'), findsNothing);
    expect(tester.takeException(), isNull);

    for (final path in routes) {
      router.go(path);
      await tester.pumpAndSettle(const Duration(milliseconds: 100));
      expect(tester.takeException(), isNull, reason: 'route $path threw');
      expect(find.byType(Scaffold), findsWidgets, reason: 'route $path');
      expect(find.text('Try demo'), findsNothing, reason: 'route $path');
    }

    router.go('/accounts');
    await tester.pumpAndSettle(const Duration(milliseconds: 100));
    expect(find.text('Checking'), findsOneWidget);
    expect(find.text('Savings'), findsOneWidget);

    router.go('/cards');
    await tester.pumpAndSettle(const Duration(milliseconds: 100));
    expect(find.textContaining('Visa Platinum'), findsOneWidget);

    router.go('/loans');
    await tester.pumpAndSettle(const Duration(milliseconds: 100));
    expect(find.textContaining('Car loan'), findsOneWidget);
    expect(find.textContaining('Home improvement'), findsOneWidget);

    router.go('/categories');
    await tester.pumpAndSettle(const Duration(milliseconds: 100));
    expect(find.text('Groceries'), findsOneWidget);

    router.go('/transactions');
    await tester.pumpAndSettle(const Duration(milliseconds: 100));
    // The list is newest first and lazily built: the latest row must be on screen.
    final latest = DemoMode.instance.store
        .transactionsForMonth(DateTime.now())
        .first;
    expect(find.textContaining(latest.description!), findsWidgets);

    router.go('/settings');
    await tester.pumpAndSettle(const Duration(milliseconds: 100));
    expect(find.text('demo@wallet.app'), findsOneWidget);
    expect(find.text('Demo mode'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Exit demo'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Exit demo'));
    await tester.pumpAndSettle(const Duration(milliseconds: 100));
    expect(DemoMode.instance.isActive, isFalse);
    expect(find.text('Try demo'), findsOneWidget);
  });
}

class _MemoryAsyncStorage extends GotrueAsyncStorage {
  final _data = <String, String>{};

  @override
  Future<String?> getItem({required String key}) async => _data[key];

  @override
  Future<void> removeItem({required String key}) async => _data.remove(key);

  @override
  Future<void> setItem({required String key, required String value}) async =>
      _data[key] = value;
}
