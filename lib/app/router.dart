import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/login_screen.dart';
import '../features/auth/register_screen.dart';
import '../features/auth/splash_screen.dart';
import '../features/auth/verify_email_screen.dart';
import '../features/incidents/edit_incident_screen.dart';
import '../features/incidents/feed_screen.dart';
import '../features/incidents/incident_detail_screen.dart';
import '../features/incidents/report_form_screen.dart';
import '../features/profile/profile_screen.dart';
import '../features/staff/staff_dashboard_screen.dart';
import '../providers/auth_providers.dart';
import 'app_shell.dart';
import 'router_redirect.dart';
import 'routes.dart';

/// The app's [GoRouter].
///
/// It is created once; when [sessionProvider] changes (sign in, verify,
/// sign out, role loaded) the `refreshListenable` re-runs [redirectFor],
/// which moves the user to the right screen. When the role itself changes
/// while signed in (edited in the Firestore console), the user is taken to
/// the new role's home screen.
final routerProvider = Provider<GoRouter>((ref) {
  final refresh = ValueNotifier<int>(0);
  ref.onDispose(refresh.dispose);

  late final GoRouter router;
  ref.listen(sessionProvider, (previous, next) {
    refresh.value++;
    if (previous is SessionReady &&
        next is SessionReady &&
        previous.isStaff != next.isStaff) {
      router.go(homeFor(isStaff: next.isStaff));
    }
  });

  return router = GoRouter(
    initialLocation: Routes.splash,
    refreshListenable: refresh,
    redirect: (context, state) =>
        redirectFor(ref.read(sessionProvider), state.matchedLocation),
    routes: [
      GoRoute(
        path: Routes.splash,
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: Routes.login,
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: Routes.register,
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: Routes.verifyEmail,
        builder: (context, state) => const VerifyEmailScreen(),
      ),
      // Detail and edit open full screen above the tabs.
      GoRoute(
        path: Routes.incidentDetail,
        builder: (context, state) =>
            IncidentDetailScreen(incidentId: state.pathParameters['id']!),
        routes: [
          GoRoute(
            path: 'edit',
            builder: (context, state) =>
                EditIncidentScreen(incidentId: state.pathParameters['id']!),
          ),
        ],
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) => Consumer(
          builder: (context, ref, _) => AppShell(
            navigationShell: navigationShell,
            isStaff: ref.watch(isStaffProvider),
          ),
        ),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.feed,
                builder: (context, state) => const FeedScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.report,
                builder: (context, state) => const ReportFormScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.staffDashboard,
                builder: (context, state) => const StaffDashboardScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.profile,
                builder: (context, state) => const ProfileScreen(),
              ),
            ],
          ),
        ],
      ),
    ],
  );
});
