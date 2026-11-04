import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'app_shell.dart';
import 'routes.dart';

/// The app's [GoRouter], exposed as a provider so redirect guards can read
/// auth and role providers (added in step 3).
final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: Routes.feed,
    routes: [
      GoRoute(
        path: Routes.login,
        builder: (context, state) => const _PlaceholderScreen('Log in'),
      ),
      GoRoute(
        path: Routes.register,
        builder: (context, state) => const _PlaceholderScreen('Create account'),
      ),
      GoRoute(
        path: Routes.verifyEmail,
        builder: (context, state) => const _PlaceholderScreen('Verify email'),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            AppShell(navigationShell: navigationShell, showStaffTab: false),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.feed,
                builder: (context, state) =>
                    const _PlaceholderScreen('Reports'),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.report,
                builder: (context, state) =>
                    const _PlaceholderScreen('Report an issue'),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.staffDashboard,
                builder: (context, state) =>
                    const _PlaceholderScreen('Dashboard'),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.profile,
                builder: (context, state) =>
                    const _PlaceholderScreen('Profile'),
              ),
            ],
          ),
        ],
      ),
    ],
  );
});

/// Temporary screen used until each feature screen is built.
class _PlaceholderScreen extends StatelessWidget {
  const _PlaceholderScreen(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(child: Text(title)),
    );
  }
}
