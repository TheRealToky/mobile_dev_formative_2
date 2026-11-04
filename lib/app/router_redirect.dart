import '../providers/auth_providers.dart';
import 'routes.dart';

const _publicRoutes = {Routes.login, Routes.register};

/// Decides where the router should send the user, or `null` to stay.
///
/// A pure function of the [session] and the requested [location], so every
/// guard is unit tested without a widget tree:
/// - loading or profile error -> splash
/// - signed out -> login (register is allowed)
/// - signed in but unverified -> verify email
/// - ready -> leave auth screens for the feed; non-staff cannot open
///   `/staff/*` (this is a usability guard; Security Rules enforce access).
String? redirectFor(SessionState session, String location) {
  bool at(String route) => location == route;

  return switch (session) {
    SessionLoading() ||
    SessionError() => at(Routes.splash) ? null : Routes.splash,
    SessionSignedOut() =>
      _publicRoutes.contains(location) ? null : Routes.login,
    SessionUnverified() => at(Routes.verifyEmail) ? null : Routes.verifyEmail,
    SessionReady(:final isStaff) =>
      _publicRoutes.contains(location) ||
              at(Routes.splash) ||
              at(Routes.verifyEmail)
          ? Routes.feed
          : (!isStaff && location.startsWith(Routes.staffDashboard)
                ? Routes.feed
                : null),
  };
}
