import '../providers/auth_providers.dart';
import 'routes.dart';

const _publicRoutes = {Routes.login, Routes.register};

/// Each role's landing screen: the dashboard for staff, the feed for
/// students.
String homeFor({required bool isStaff}) =>
    isStaff ? Routes.staffDashboard : Routes.feed;

/// Decides where the router should send the user, or `null` to stay.
///
/// A pure function of the [session] and the requested [location], so every
/// guard is unit tested without a widget tree:
/// - loading or profile error -> splash
/// - signed out -> login (register is allowed)
/// - signed in but unverified -> verify email
/// - ready -> leave auth screens for the role's home ([homeFor]);
///   students cannot open `/staff/*` and staff cannot open the student-only
///   report form (usability guards; Security Rules enforce access).
///
/// The role is `users/{uid}.role`, so editing it in the console switches
/// the screens a user gets.
String? redirectFor(SessionState session, String location) {
  bool at(String route) => location == route;
  bool under(String route) =>
      location == route || location.startsWith('$route/');

  return switch (session) {
    SessionLoading() ||
    SessionError() => at(Routes.splash) ? null : Routes.splash,
    SessionSignedOut() =>
      _publicRoutes.contains(location) ? null : Routes.login,
    SessionUnverified() => at(Routes.verifyEmail) ? null : Routes.verifyEmail,
    SessionReady(:final isStaff)
        when _publicRoutes.contains(location) ||
            at(Routes.splash) ||
            at(Routes.verifyEmail) =>
      homeFor(isStaff: isStaff),
    SessionReady(isStaff: false) when under(Routes.staffDashboard) =>
      Routes.feed,
    SessionReady(isStaff: true) when under(Routes.report) =>
      Routes.staffDashboard,
    SessionReady() => null,
  };
}
