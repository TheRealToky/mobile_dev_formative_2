// Role-based routing through the real app (router, shell, screens) with the
// Firebase SDKs swapped for in-memory fakes.
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_dev_formative_2/app/app.dart';
import 'package:mobile_dev_formative_2/features/incidents/feed_screen.dart';
import 'package:mobile_dev_formative_2/features/staff/staff_dashboard_screen.dart';
import 'package:mobile_dev_formative_2/providers/firebase_providers.dart';
import 'package:mobile_dev_formative_2/providers/retry_policy.dart';

Future<FakeFirebaseFirestore> _pumpApp(
  WidgetTester tester, {
  required String email,
  FakeFirebaseFirestore? db,
}) async {
  final firestore = db ?? FakeFirebaseFirestore();
  final auth = MockFirebaseAuth(
    signedIn: true,
    mockUser: MockUser(
      uid: 'u1',
      email: email,
      displayName: 'Test User',
      isEmailVerified: true,
    ),
  );
  await tester.pumpWidget(
    ProviderScope(
      retry: noAutomaticRetry,
      overrides: [
        firebaseAuthProvider.overrideWithValue(auth),
        firestoreProvider.overrideWithValue(firestore),
      ],
      child: const CampusApp(useGoogleFont: false),
    ),
  );
  await tester.pumpAndSettle();
  return firestore;
}

/// Labels of the bottom navigation bar, in order.
List<String> _tabs(WidgetTester tester) => [
  for (final d in tester.widgetList<NavigationDestination>(
    find.byType(NavigationDestination),
  ))
    d.label,
];

void main() {
  testWidgets('@alustudent.com accounts become students and land on the '
      'feed', (tester) async {
    final db = await _pumpApp(tester, email: 'ada@alustudent.com');

    expect((await db.doc('users/u1').get()).data()?['role'], 'student');
    expect(find.byType(FeedScreen), findsOneWidget);
    expect(_tabs(tester), ['Feed', 'Report', 'Profile']);
  });

  testWidgets('@alueducation.com accounts become staff and land on the '
      'dashboard', (tester) async {
    final db = await _pumpApp(tester, email: 'sam@alueducation.com');

    expect((await db.doc('users/u1').get()).data()?['role'], 'staff');
    expect(find.byType(StaffDashboardScreen), findsOneWidget);
    expect(_tabs(tester), ['Dashboard', 'Feed', 'Profile']);
  });

  testWidgets('the stored role wins over the email domain', (tester) async {
    final db = FakeFirebaseFirestore();
    await db.doc('users/u1').set({
      'displayName': 'Sam',
      'email': 'sam@alueducation.com',
      'role': 'student',
      'createdAt': DateTime(2026),
    });
    await _pumpApp(tester, email: 'sam@alueducation.com', db: db);

    expect(find.byType(FeedScreen), findsOneWidget);
    expect(_tabs(tester), ['Feed', 'Report', 'Profile']);
  });

  testWidgets('editing the role in the database switches screens live', (
    tester,
  ) async {
    final db = await _pumpApp(tester, email: 'ada@alustudent.com');
    expect(find.byType(FeedScreen), findsOneWidget);

    await db.doc('users/u1').update({'role': 'staff'});
    await tester.pumpAndSettle();
    expect(find.byType(StaffDashboardScreen), findsOneWidget);
    expect(_tabs(tester), ['Dashboard', 'Feed', 'Profile']);

    await db.doc('users/u1').update({'role': 'student'});
    await tester.pumpAndSettle();
    expect(find.byType(FeedScreen), findsOneWidget);
    expect(_tabs(tester), ['Feed', 'Report', 'Profile']);
  });
}
