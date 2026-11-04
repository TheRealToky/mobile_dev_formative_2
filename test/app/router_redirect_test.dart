import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_dev_formative_2/app/router_redirect.dart';
import 'package:mobile_dev_formative_2/app/routes.dart';
import 'package:mobile_dev_formative_2/data/models/app_user.dart';
import 'package:mobile_dev_formative_2/providers/auth_providers.dart';

AppUser _user(UserRole role) => AppUser(
  uid: 'u',
  displayName: 'Ada',
  email: 'ada@alustudent.com',
  role: role,
  createdAt: DateTime(2026),
);

void main() {
  final student = SessionReady(_user(UserRole.student));
  final staff = SessionReady(_user(UserRole.staff));

  test('loading and errors wait on the splash screen', () {
    expect(redirectFor(const SessionLoading(), Routes.feed), Routes.splash);
    expect(redirectFor(const SessionLoading(), Routes.splash), isNull);
    expect(redirectFor(SessionError(Exception()), Routes.feed), Routes.splash);
  });

  test('signed-out users can only see login and register', () {
    const s = SessionSignedOut();
    expect(redirectFor(s, Routes.feed), Routes.login);
    expect(redirectFor(s, Routes.staffDashboard), Routes.login);
    expect(redirectFor(s, Routes.login), isNull);
    expect(redirectFor(s, Routes.register), isNull);
  });

  test('unverified users are held on the verify email screen', () {
    const s = SessionUnverified('ada@alustudent.com');
    expect(redirectFor(s, Routes.feed), Routes.verifyEmail);
    expect(redirectFor(s, Routes.login), Routes.verifyEmail);
    expect(redirectFor(s, Routes.verifyEmail), isNull);
  });

  test('ready users leave auth screens for the feed', () {
    for (final route in [
      Routes.login,
      Routes.register,
      Routes.splash,
      Routes.verifyEmail,
    ]) {
      expect(redirectFor(student, route), Routes.feed, reason: route);
    }
    expect(redirectFor(student, Routes.feed), isNull);
    expect(redirectFor(student, Routes.incident('abc')), isNull);
  });

  test('only staff may open staff routes', () {
    expect(redirectFor(student, Routes.staffDashboard), Routes.feed);
    expect(redirectFor(student, '${Routes.staffDashboard}/queue'), Routes.feed);
    expect(redirectFor(staff, Routes.staffDashboard), isNull);
  });
}
