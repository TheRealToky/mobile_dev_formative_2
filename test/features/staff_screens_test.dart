import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_dev_formative_2/app/theme.dart';
import 'package:mobile_dev_formative_2/data/models/app_user.dart';
import 'package:mobile_dev_formative_2/data/models/incident.dart';
import 'package:mobile_dev_formative_2/features/incidents/incident_detail_screen.dart';
import 'package:mobile_dev_formative_2/features/staff/staff_dashboard_screen.dart';
import 'package:mobile_dev_formative_2/features/staff/status_update_sheet.dart';
import 'package:mobile_dev_formative_2/providers/auth_providers.dart';
import 'package:mobile_dev_formative_2/providers/dashboard_providers.dart';
import 'package:mobile_dev_formative_2/providers/incident_providers.dart';
import 'package:mobile_dev_formative_2/providers/retry_policy.dart';
import 'package:mobile_dev_formative_2/widgets/incident_card.dart';

import '../helpers/builders.dart';

AppUser _viewer(UserRole role) => AppUser(
  uid: role == UserRole.staff ? 'staff1' : 'uid2',
  displayName: 'Viewer',
  email: 'viewer@alueducation.com',
  role: role,
  createdAt: DateTime(2026),
);

final _incidents = [
  buildIncident(id: 'new', title: 'New one', createdAt: DateTime(2026, 11, 3)),
  buildIncident(
    id: 'old',
    title: 'Old one',
    status: IncidentStatus.inProgress,
    createdAt: DateTime(2026, 10, 1),
  ),
  buildIncident(
    id: 'mid',
    title: 'Middle one',
    status: IncidentStatus.underReview,
    createdAt: DateTime(2026, 10, 15),
  ),
  buildIncident(
    id: 'done',
    title: 'Done one',
    status: IncidentStatus.resolved,
    createdAt: DateTime(2026, 9, 1),
  ),
];

Future<void> pumpApp(
  WidgetTester tester,
  Widget home, {
  required UserRole role,
  List<Override> overrides = const [],
}) async {
  final container = ProviderContainer(
    retry: noAutomaticRetry,
    overrides: [
      currentUserProfileProvider.overrideWith(
        (ref) => Stream.value(_viewer(role)),
      ),
      ...overrides,
    ],
  );
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: AppTheme.light(useGoogleFont: false),
        home: home,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('DashboardStats', () {
    test('counts every status and queues open reports oldest first', () {
      final stats = DashboardStats.from(_incidents);
      expect(stats.total, 4);
      expect(stats.counts[IncidentStatus.submitted], 1);
      expect(stats.counts[IncidentStatus.resolved], 1);
      expect(stats.counts[IncidentStatus.rejected], 0);
      expect(stats.openQueue.map((i) => i.id), ['old', 'mid', 'new']);
    });
  });

  group('dashboard screen', () {
    final overrides = [
      allIncidentsStreamProvider.overrideWith(
        (ref) => Stream.value(_incidents),
      ),
    ];

    testWidgets('shows counts and the oldest open report first', (
      tester,
    ) async {
      await pumpApp(
        tester,
        const StaffDashboardScreen(),
        role: UserRole.staff,
        overrides: overrides,
      );
      expect(find.text('3 open of 4 reports'), findsOneWidget);
      final titles = tester
          .widgetList<IncidentCard>(find.byType(IncidentCard))
          .map((c) => c.incident.id);
      expect(titles, ['old', 'mid', 'new']);
    });

    testWidgets('tapping a count filters the queue; tapping again clears', (
      tester,
    ) async {
      await pumpApp(
        tester,
        const StaffDashboardScreen(),
        role: UserRole.staff,
        overrides: overrides,
      );
      final tile = find.bySemanticsLabel(RegExp('^In progress: 1'));
      await tester.tap(tile);
      await tester.pumpAndSettle();
      expect(find.byType(IncidentCard), findsOneWidget);
      expect(find.text('Old one'), findsOneWidget);

      await tester.tap(tile);
      await tester.pumpAndSettle();
      expect(find.byType(IncidentCard), findsNWidgets(3));
    });
  });

  group('status update sheet', () {
    testWidgets('offers every other status, with the next step selected', (
      tester,
    ) async {
      await pumpApp(
        tester,
        Scaffold(
          body: StatusUpdateSheet(
            incident: buildIncident(status: IncidentStatus.underReview),
          ),
        ),
        role: UserRole.staff,
      );
      for (final label in [
        'Submitted',
        'In progress',
        'Resolved',
        'Rejected',
      ]) {
        expect(find.widgetWithText(ChoiceChip, label), findsOneWidget);
      }
      expect(find.widgetWithText(ChoiceChip, 'Under review'), findsNothing);
      expect(find.text('Move to in progress'), findsOneWidget);

      // Going back a step is allowed and flagged.
      await tester.tap(find.widgetWithText(ChoiceChip, 'Submitted'));
      await tester.pumpAndSettle();
      expect(find.text('This moves the report back a step.'), findsOneWidget);
      expect(find.text('Move to submitted'), findsOneWidget);
    });

    testWidgets('a resolved report can be reopened as submitted', (
      tester,
    ) async {
      await pumpApp(
        tester,
        Scaffold(
          body: StatusUpdateSheet(
            incident: buildIncident(status: IncidentStatus.resolved),
          ),
        ),
        role: UserRole.staff,
      );
      expect(find.text('Reopen as submitted'), findsOneWidget);
      expect(
        find.text(
          'This reopens the report and puts it back in the open queue.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('rejecting requires a reason', (tester) async {
      await pumpApp(
        tester,
        Scaffold(
          body: StatusUpdateSheet(
            incident: buildIncident(status: IncidentStatus.underReview),
          ),
        ),
        role: UserRole.staff,
      );
      await tester.tap(find.widgetWithText(ChoiceChip, 'Rejected'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Move to rejected'));
      await tester.pumpAndSettle();
      expect(find.text('Say why the report is rejected.'), findsOneWidget);
    });
  });

  group('detail screen staff button', () {
    List<Override> detail(IncidentStatus status) => [
      incidentDocProvider('inc1')
          .overrideWith((ref) => Stream.value(buildIncident(status: status))),
      statusHistoryProvider('inc1').overrideWith((ref) => Stream.value([])),
    ];

    testWidgets('staff see "Update status" on an open report', (tester) async {
      await pumpApp(
        tester,
        const IncidentDetailScreen(incidentId: 'inc1'),
        role: UserRole.staff,
        overrides: [
          ...detail(IncidentStatus.submitted),
          reporterProfileProvider('uid1').overrideWith((ref) async => null),
        ],
      );
      expect(find.text('Update status'), findsOneWidget);

      await tester.tap(find.text('Update status'));
      await tester.pumpAndSettle();
      expect(find.byType(StatusUpdateSheet), findsOneWidget);
    });

    testWidgets('students never see it', (tester) async {
      await pumpApp(
        tester,
        const IncidentDetailScreen(incidentId: 'inc1'),
        role: UserRole.student,
        overrides: detail(IncidentStatus.submitted),
      );
      expect(find.text('Update status'), findsNothing);
    });

    testWidgets('still shown once resolved, so staff can reopen it', (
      tester,
    ) async {
      await pumpApp(
        tester,
        const IncidentDetailScreen(incidentId: 'inc1'),
        role: UserRole.staff,
        overrides: [
          ...detail(IncidentStatus.resolved),
          reporterProfileProvider('uid1').overrideWith((ref) async => null),
        ],
      );
      expect(find.text('Update status'), findsOneWidget);
    });
  });
}
