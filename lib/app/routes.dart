/// Route paths in one place so screens never hard-code strings.
abstract final class Routes {
  static const splash = '/splash';
  static const login = '/login';
  static const register = '/register';
  static const verifyEmail = '/verify-email';

  static const feed = '/feed';
  static const report = '/report';
  static const staffDashboard = '/staff';
  static const profile = '/profile';

  /// Detail of one incident: `/incidents/:id`.
  static const incidentDetail = '/incidents/:id';
  static String incident(String id) => '/incidents/$id';

  /// Edit form for one incident: `/incidents/:id/edit`.
  static String editIncident(String id) => '/incidents/$id/edit';
}
