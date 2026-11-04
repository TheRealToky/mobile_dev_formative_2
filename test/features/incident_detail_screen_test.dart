import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_dev_formative_2/app/theme.dart';
import 'package:mobile_dev_formative_2/data/models/app_user.dart';
import 'package:mobile_dev_formative_2/data/models/incident.dart';
import 'package:mobile_dev_formative_2/data/models/status_event.dart';
import 'package:mobile_dev_formative_2/features/incidents/incident_detail_screen.dart';
import 'package:mobile_dev_formative_2/providers/auth_providers.dart';
import 'package:mobile_dev_formative_2/providers/incident_providers.dart';
import 'package:mobile_dev_formative_2/providers/retry_policy.dart';
import 'package:mobile_dev_formative_2/widgets/status_timeline.dart';

import '../helpers/builders.dart';

AppUser _user(String uid, {UserRole role = UserRole.student}) => AppUser(
  uid: uid,
  displayName: uid == 'uid1' ? 'Ada' : 'Sam Staff',
  email: '$uid@alustudent.com',
  role: role,
  createdAt: DateTime(2026),
);

final _event = StatusEvent(
  id: 'e1',
  from: IncidentStatus.submitted,
  to: IncidentStatus.underReview,
  changedBy: 'staff1',
  at: DateTime(2026, 11, 2, 10),
  note: 'Plumber booked for Monday.',
);

Future<void> pumpDetail(
  WidgetTester tester, {
  required Stream<Incident?> incident,
  List<StatusEvent> history = const [],
  required AppUser viewer,
}) async {
  final container = ProviderContainer(
    retry: noAutomaticRetry,
    overrides: [
      incidentDocProvider('inc1').overrideWith((ref) => incident),
      statusHistoryProvider('inc1')
          .overrideWith((ref) => Stream.value(history)),
      currentUserProfileProvider.overrideWith((ref) => Stream.value(viewer)),
      reporterProfileProvider('uid1')
          .overrideWith((ref) async => _user('uid1')),
    ],
  );
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: AppTheme.light(useGoogleFont: false),
        home: const IncidentDetailScreen(incidentId: 'inc1'),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('permissionsFor', () {
    final submitted = buildIncident();
    final reviewing = buildIncident(status: IncidentStatus.underReview);

    test('reporter can edit and delete while submitted', () {
      expect(permissionsFor(submitted, uid: 'uid1', isStaff: false), (
        canEdit: true,
        canDelete: true,
      ));
    });
    test('reporter loses both once staff start', () {
      expect(permissionsFor(reviewing, uid: 'uid1', isStaff: false), (
        canEdit: false,
        canDelete: false,
      ));
    });
    test('other students can do neither', () {
      expect(permissionsFor(submitted, uid: 'uid2', isStaff: false), (
        canEdit: false,
        canDelete: false,
      ));
    });
    test('staff can delete but not edit content', () {
      expect(permissionsFor(reviewing, uid: 'staff1', isStaff: true), (
        canEdit: false,
        canDelete: true,
      ));
    });
  });

  test('timeline starts with the submission, then changes oldest first', () {
    final later = StatusEvent(
      id: 'e2',
      from: IncidentStatus.underReview,
      to: IncidentStatus.inProgress,
      changedBy: 'staff1',
      at: DateTime(2026, 11, 3),
    );
    final entries = buildTimeline(DateTime(2026, 11, 1), [_event, later]);
    expect(entries.map((e) => e.status), [
      IncidentStatus.submitted,
      IncidentStatus.underReview,
      IncidentStatus.inProgress,
    ]);
    expect(entries.first.byStaff, isFalse);
  });

  testWidgets('shows details, history note and owner actions', (tester) async {
    await pumpDetail(
      tester,
      incident: Stream.value(buildIncident()),
      history: [_event],
      viewer: _user('uid1'),
    );
    expect(find.text('Leaking tap'), findsOneWidget);
    expect(find.text('Library, 2nd floor'), findsOneWidget);
    expect(find.text('Reported by you'), findsOneWidget);
    expect(find.byType(StatusTimeline), findsOneWidget);
    expect(find.text('Plumber booked for Monday.'), findsOneWidget);
    expect(find.byTooltip('Edit report'), findsOneWidget);
    expect(find.byTooltip('Delete report'), findsOneWidget);
  });

  testWidgets('another student sees no actions and no anonymous name', (
    tester,
  ) async {
    await pumpDetail(
      tester,
      incident: Stream.value(
        buildIncident(isAnonymous: true, reporterName: null),
      ),
      viewer: _user('uid2'),
    );
    expect(find.text('Reported anonymously'), findsOneWidget);
    expect(find.textContaining('Ada'), findsNothing);
    expect(find.byTooltip('Edit report'), findsNothing);
    expect(find.byTooltip('Delete report'), findsNothing);
  });

  testWidgets('staff see who filed an anonymous report and can delete', (
    tester,
  ) async {
    await pumpDetail(
      tester,
      incident: Stream.value(
        buildIncident(
          isAnonymous: true,
          reporterName: null,
          status: IncidentStatus.inProgress,
        ),
      ),
      viewer: _user('staff1', role: UserRole.staff),
    );
    expect(
      find.text('Reported anonymously by Ada (visible to staff only)'),
      findsOneWidget,
    );
    expect(find.byTooltip('Edit report'), findsNothing);
    expect(find.byTooltip('Delete report'), findsOneWidget);
  });

  testWidgets('delete asks for confirmation first', (tester) async {
    await pumpDetail(
      tester,
      incident: Stream.value(buildIncident()),
      viewer: _user('uid1'),
    );
    await tester.tap(find.byTooltip('Delete report'));
    await tester.pumpAndSettle();
    expect(find.text('Delete this report?'), findsOneWidget);
    await tester.tap(find.text('Keep report'));
    await tester.pumpAndSettle();
    expect(find.text('Delete this report?'), findsNothing);
  });

  testWidgets('a deleted report shows an empty state', (tester) async {
    await pumpDetail(
      tester,
      incident: Stream.value(null),
      viewer: _user('uid1'),
    );
    expect(find.text('This report was deleted.'), findsOneWidget);
  });

  testWidgets('a status change appears live', (tester) async {
    final controller = StreamController<Incident?>();
    addTearDown(controller.close);
    controller.add(buildIncident());
    await pumpDetail(
      tester,
      incident: controller.stream,
      viewer: _user('uid2'),
    );
    expect(find.text('Submitted'), findsWidgets);

    controller.add(buildIncident(status: IncidentStatus.resolved));
    await tester.pumpAndSettle();
    expect(find.text('Resolved'), findsWidgets);
  });
}
