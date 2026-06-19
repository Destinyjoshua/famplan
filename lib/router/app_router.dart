import 'package:famplan/features/auth/presentation/login_screen.dart';
import 'package:famplan/features/auth/presentation/signup_screen.dart';
import 'package:famplan/features/onboarding/presentation/onboarding_screen.dart';
import 'package:famplan/providers/auth_provider.dart';
import 'package:famplan/providers/family_provider.dart';
import 'package:famplan/shared/widgets/family_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();
final _shellNavigatorDashboardKey = GlobalKey<NavigatorState>(debugLabel: 'dashboard');
final _shellNavigatorCalendarKey = GlobalKey<NavigatorState>(debugLabel: 'calendar');
final _shellNavigatorTasksKey = GlobalKey<NavigatorState>(debugLabel: 'tasks');
final _shellNavigatorMealsKey = GlobalKey<NavigatorState>(debugLabel: 'meals');
final _shellNavigatorAnnouncementsKey = GlobalKey<NavigatorState>(debugLabel: 'announcements');

final routerProvider = Provider<GoRouter>((ref) {
  final authListenable = ValueNotifier<int>(0);

  ref.listen(authStateProvider, (_, __) {
    authListenable.value++;
  });
  ref.listen(currentFamilyProvider, (_, __) {
    authListenable.value++;
  });
  ref.listen(familyControllerProvider, (_, __) {
    authListenable.value++;
  });

  ref.onDispose(authListenable.dispose);

  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/',
    refreshListenable: authListenable,
    errorBuilder: (context, state) => Scaffold(
      appBar: AppBar(title: const Text('FamPlan')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            state.error?.toString() ?? 'Something went wrong',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    ),
    redirect: (context, state) {
      final authState = ref.read(authStateProvider);
      final isAuthLoading = authState.isLoading;
      final isLoggedIn = authState.value?.session != null;

      final location = state.matchedLocation;
      final isLoginRoute = location == '/login';
      final isSignUpRoute = location == '/signup';
      final isOnboardingRoute = location == '/onboarding';
      final isAuthRoute = isLoginRoute || isSignUpRoute;

      if (isAuthLoading) return null;

      if (!isLoggedIn) {
        return isAuthRoute ? null : '/login';
      }

      final familyAsync = ref.read(currentFamilyProvider);
      if (familyAsync.isLoading) return null;

      final hasFamily = familyAsync.value != null;

      if (!hasFamily) {
        return isOnboardingRoute ? null : '/onboarding';
      }

      if (isAuthRoute || isOnboardingRoute) {
        return '/';
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/signup',
        builder: (context, state) => const SignUpScreen(),
      ),
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return FamilyShell(navigationShell: navigationShell);
        },
        branches: [
          StatefulShellBranch(
            navigatorKey: _shellNavigatorDashboardKey,
            routes: [
              GoRoute(
                path: '/',
                builder: (context, state) => const DashboardBranch(),
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: _shellNavigatorCalendarKey,
            routes: [
              GoRoute(
                path: '/calendar',
                builder: (context, state) => const CalendarBranch(),
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: _shellNavigatorTasksKey,
            routes: [
              GoRoute(
                path: '/tasks',
                builder: (context, state) => const TasksBranch(),
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: _shellNavigatorMealsKey,
            routes: [
              GoRoute(
                path: '/meals',
                builder: (context, state) => const MealsBranch(),
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: _shellNavigatorAnnouncementsKey,
            routes: [
              GoRoute(
                path: '/announcements',
                builder: (context, state) => const AnnouncementsBranch(),
              ),
            ],
          ),
        ],
      ),
    ],
  );
});
