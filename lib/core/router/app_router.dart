import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/user_profile_provider.dart';
import '../../features/onboarding/onboarding_screen.dart';
import '../../features/onboarding/api_key_screen.dart';
import '../../features/dashboard/dashboard_screen.dart';
import '../../features/transactions/transactions_screen.dart';
import '../../features/transactions/add_transaction_sheet.dart';
import '../../features/goals/goals_screen.dart';
import '../../features/goals/create_goal_sheet.dart';
import '../../features/ai_buddy/ai_buddy_screen.dart';
import '../../features/insights/insights_screen.dart';
import '../../features/settings/settings_screen.dart';
import '../../features/sms_import/sms_import_screen.dart';
import '../../shared/widgets/app_scaffold.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();
final _shellNavigatorKey = GlobalKey<NavigatorState>();

final routerProvider = Provider<GoRouter>((ref) {
  final profileAsync = ref.watch(userProfileProvider);

  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/dashboard',
    redirect: (context, state) {
      if (profileAsync.isLoading) return null;
      final profile = profileAsync.valueOrNull;
      final onboarded = profile?.onboardingComplete ?? false;

      final onOnboarding = state.matchedLocation.startsWith('/onboarding') ||
          state.matchedLocation.startsWith('/api-key');

      if (!onboarded && !onOnboarding) return '/onboarding';
      if (onboarded && onOnboarding) return '/dashboard';
      return null;
    },
    routes: [
      // Onboarding (outside shell)
      GoRoute(
        path: '/onboarding',
        builder: (_, __) => const OnboardingScreen(),
      ),
      GoRoute(
        path: '/api-key',
        builder: (_, __) => const ApiKeyScreen(),
      ),

      // Settings (outside shell — full screen)
      GoRoute(
        path: '/settings',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (_, __) => const SettingsScreen(),
      ),

      // SMS Import (outside shell — full screen)
      GoRoute(
        path: '/sms-import',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (_, __) => const SmsImportScreen(),
      ),

      // Shell route — persistent bottom nav
      ShellRoute(
        navigatorKey: _shellNavigatorKey,
        builder: (context, state, child) => AppScaffold(child: child),
        routes: [
          GoRoute(
            path: '/dashboard',
            builder: (_, __) => const DashboardScreen(),
          ),
          GoRoute(
            path: '/transactions',
            builder: (_, __) => const TransactionsScreen(),
            routes: [
              GoRoute(
                path: 'add',
                parentNavigatorKey: _rootNavigatorKey,
                pageBuilder: (_, __) => const MaterialPage(
                  fullscreenDialog: true,
                  child: AddTransactionSheet(),
                ),
              ),
            ],
          ),
          GoRoute(
            path: '/goals',
            builder: (_, __) => const GoalsScreen(),
            routes: [
              GoRoute(
                path: 'create',
                parentNavigatorKey: _rootNavigatorKey,
                pageBuilder: (_, __) => const MaterialPage(
                  fullscreenDialog: true,
                  child: CreateGoalSheet(),
                ),
              ),
            ],
          ),
          GoRoute(
            path: '/ai-buddy',
            builder: (_, __) => const AiBuddyScreen(),
          ),
          GoRoute(
            path: '/insights',
            builder: (_, __) => const InsightsScreen(),
          ),
        ],
      ),
    ],
  );
});
