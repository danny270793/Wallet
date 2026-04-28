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
import 'widgets/app_shell.dart';

final router = GoRouter(
  initialLocation: '/',
  redirect: (context, state) {
    final session = Supabase.instance.client.auth.currentSession;
    final loc = state.matchedLocation;

    if (loc == '/') {
      return session != null ? '/dashboard' : '/login';
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
      builder: (context, state, child) => AppShell(child: child),
      routes: [
        GoRoute(path: '/dashboard', builder: (context, state) => const DashboardPage()),
        GoRoute(path: '/accounts', builder: (context, state) => const AccountsPage()),
        GoRoute(path: '/cards', builder: (context, state) => const CardsPage()),
        GoRoute(path: '/categories', builder: (context, state) => const CategoriesPage()),
        GoRoute(path: '/tags', builder: (context, state) => const TagsPage()),
        GoRoute(path: '/transactions', builder: (context, state) => const TransactionsPage()),
      ],
    ),
  ],
);
