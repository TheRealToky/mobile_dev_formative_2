// End-to-end flows through the real app: router, guards, screens,
// providers and repositories. Only the Firebase SDKs are swapped for
// in-memory fakes (firebase_auth_mocks, fake_cloud_firestore), so the test
// is repeatable and never touches the real project.
//
// Run on a connected Android phone or emulator:
//   flutter test integration_test/app_flow_test.dart
// or with the driver:
//   flutter drive --driver=test_driver/integration_test.dart \
//     --target=integration_test/app_flow_test.dart
//
// Security Rules are not exercised here (fakes do not enforce them); they
// are covered by the emulator suite in firebase/test/rules.test.js.

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mobile_dev_formative_2/app/app.dart';
import 'package:mobile_dev_formative_2/data/repositories/storage_repository.dart';
import 'package:mobile_dev_formative_2/features/staff/status_update_sheet.dart';
import 'package:mobile_dev_formative_2/providers/firebase_providers.dart';
import 'package:mobile_dev_formative_2/providers/report_controller.dart';
import 'package:mobile_dev_formative_2/providers/retry_policy.dart';
import 'package:mobile_dev_formative_2/widgets/incident_card.dart';

/// Photo-free flows never upload; this only satisfies the provider.
class _NoStorage implements StorageRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnsupportedError('Storage is not used in these flows');
}

const _studentUid = 'student1';
const _staffUid = 'staff1';

Future<FakeFirebaseFirestore> _pumpApp(
  WidgetTester tester, {
  required String uid,
  required String email,
  required String name,
  FakeFirebaseFirestore? db,
}) async {
  final firestore = db ?? FakeFirebaseFirestore();
  final auth = MockFirebaseAuth(
    signedIn: true,
    mockUser: MockUser(
      uid: uid,
      email: email,
      displayName: name,
      isEmailVerified: true,
    ),
  );
  await tester.pumpWidget(
    ProviderScope(
      retry: noAutomaticRetry,
      overrides: [
        firebaseAuthProvider.overrideWithValue(auth),
        firestoreProvider.overrideWithValue(firestore),
        storageRepositoryProvider.overrideWithValue(_NoStorage()),
      ],
      child: const CampusApp(useGoogleFont: false),
    ),
  );
  await tester.pumpAndSettle();
  return firestore;
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('student files a report, sees it in the feed and detail; '
      'no staff dashboard', (tester) async {
    final db = await _pumpApp(
      tester,
      uid: _studentUid,
      email: 'ada@alustudent.com',
      name: 'Ada Student',
    );

    // Verified student lands on the empty feed; profile doc was created.
    expect(find.text('Reports'), findsOneWidget);
    expect(
      find.text('No reports yet. Spotted a problem on campus?'),
      findsOneWidget,
    );
    final profile = await db.doc('users/$_studentUid').get();
    expect(profile.data()?['role'], 'student');

    // Students have no Dashboard tab.
    expect(find.text('Dashboard'), findsNothing);

    // Report tab -> fill the form.
    await tester.tap(find.text('Report'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Water'));
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Title'),
      'Leaking tap in library',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'What happened?'),
      'The tap on the 2nd floor has been leaking since Monday.',
    );
    // The form is a lazy ListView: scroll fields into existence first.
    final formList = find.byType(Scrollable).first;
    final building = find.text('Building');
    await tester.scrollUntilVisible(building, 200, scrollable: formList);
    await tester.tap(building);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Library').last);
    await tester.pumpAndSettle();

    final submit = find.text('Submit report');
    await tester.scrollUntilVisible(submit, 200, scrollable: formList);
    await tester.tap(submit);
    await tester.pumpAndSettle();

    // Lands on the new report's detail screen.
    expect(find.text('Leaking tap in library'), findsOneWidget);
    expect(find.text('Reported by you'), findsOneWidget);
    expect(find.byTooltip('Edit report'), findsOneWidget);
    expect(find.text('Update status'), findsNothing);

    // Back to the feed: the report is listed, and search finds it.
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Feed'));
    await tester.pumpAndSettle();
    expect(find.byType(IncidentCard), findsOneWidget);
    await tester.enterText(find.byType(SearchBar), 'library');
    await tester.pumpAndSettle();
    expect(find.text('1 report'), findsOneWidget);

    final saved = await db.collection('incidents').get();
    expect(saved.docs.single.data()['status'], 'submitted');
    expect(saved.docs.single.data()['reporterId'], _studentUid);
  });

  testWidgets('staff move a report to under review; history and dashboard '
      'update', (tester) async {
    final db = FakeFirebaseFirestore();
    await db.doc('users/$_staffUid').set({
      'displayName': 'Sam Staff',
      'email': 'sam@alueducation.com',
      'role': 'staff',
      'createdAt': DateTime(2026),
    });
    await db.doc('incidents/inc1').set({
      'title': 'Broken chair in cafeteria',
      'description': 'One of the chairs near the window has a cracked leg.',
      'category': 'furniture',
      'status': 'submitted',
      'location': {'building': 'Cafeteria', 'detail': ''},
      'photoUrls': <String>[],
      'reporterId': _studentUid,
      'reporterName': 'Ada Student',
      'isAnonymous': false,
      'createdAt': DateTime(2026, 11, 1),
      'updatedAt': DateTime(2026, 11, 1),
    });

    await _pumpApp(
      tester,
      uid: _staffUid,
      email: 'sam@alueducation.com',
      name: 'Sam Staff',
      db: db,
    );

    // Staff land on the Dashboard with one open report, and have no
    // Report tab.
    expect(find.text('1 open of 1 reports'), findsOneWidget);
    expect(find.text('Report'), findsNothing);

    // Open it and update the status with a note.
    await tester.tap(find.text('Broken chair in cafeteria'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Update status'));
    await tester.pumpAndSettle();
    expect(find.byType(StatusUpdateSheet), findsOneWidget);
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Note (optional)'),
      'Facilities team informed.',
    );
    await tester.tap(find.text('Move to under review'));
    await tester.pumpAndSettle();

    // Detail updates live: new status, note in the timeline.
    expect(find.text('Moved to under review'), findsOneWidget);
    expect(find.text('Facilities team informed.'), findsOneWidget);

    final doc = await db.doc('incidents/inc1').get();
    expect(doc.data()?['status'], 'under_review');
    final history = await db.collection('incidents/inc1/statusHistory').get();
    expect(history.docs.single.data()['changedBy'], _staffUid);
  });
}
