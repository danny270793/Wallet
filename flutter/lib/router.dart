import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'pages/splash_page.dart';
import 'features/auth/presentation/pages/login_page.dart';
import 'pages/dashboard_page.dart';
import 'pages/accounts_page.dart';
import 'pages/cards_page.dart';
import 'pages/categories_page.dart';
import 'pages/tags_page.dart';
import 'pages/transactions_page.dart';
import 'pages/settings_page.dart';

final router = GoRouter(
  initialLocation: '/',
  redirect: (context, state) {
    final session = Supabase.instance.client.auth.currentSession;
    final loc = state.matchedLocation;

    if (loc == '/') {
      return session != null ? '/transactions' : '/login';
    }

    if (session == null && loc != '/login') {
      return '/login';
    }

    return null;
  },
  routes: [
    GoRoute(path: '/', builder: (context, state) => const SplashPage()),
    GoRoute(path: '/login', builder: (context, state) => const LoginPage()),
    GoRoute(path: '/settings', builder: (context, state) => const SettingsPage()),
    ShellRoute(
      builder: (context, state, child) => child,
      routes: [
        GoRoute(path: '/dashboard', builder: (context, state) => const DashboardPage()),
        GoRoute(path: '/accounts', builder: (context, state) => const AccountsPage()),
        GoRoute(path: '/cards', builder: (context, state) => const CardsPage()),
        GoRoute(path: '/categories', builder: (context, state) => const CategoriesPage()),
        GoRoute(path: '/tags', builder: (context, state) => const TagsPage()),
        GoRoute(
          path: '/transactions',
          builder: (context, state) {
            final accountId = state.uri.queryParameters['accountId'];
            final accountName = state.uri.queryParameters['accountName'];
            final cardId = state.uri.queryParameters['cardId'];
            final cardName = state.uri.queryParameters['cardName'];
            final categoryId = state.uri.queryParameters['categoryId'];
            final categoryName = state.uri.queryParameters['categoryName'];
            final tagId = state.uri.queryParameters['tagId'];
            final tagName = state.uri.queryParameters['tagName'];
            return TransactionsPage(
              accountIdFilter: (accountId == null || accountId.isEmpty) ? null : accountId,
              accountNameFilter: (accountName == null || accountName.isEmpty) ? null : accountName,
              cardIdFilter: (cardId == null || cardId.isEmpty) ? null : cardId,
              cardNameFilter: (cardName == null || cardName.isEmpty) ? null : cardName,
              categoryIdFilter: (categoryId == null || categoryId.isEmpty) ? null : categoryId,
              categoryNameFilter: (categoryName == null || categoryName.isEmpty) ? null : categoryName,
              tagIdFilter: (tagId == null || tagId.isEmpty) ? null : tagId,
              tagNameFilter: (tagName == null || tagName.isEmpty) ? null : tagName,
            );
          },
        ),
      ],
    ),
  ],
);
