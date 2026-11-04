import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_dev_formative_2/app/theme.dart';
import 'package:mobile_dev_formative_2/data/models/app_user.dart';
import 'package:mobile_dev_formative_2/data/models/incident.dart';
import 'package:mobile_dev_formative_2/data/models/status_event.dart';
import 'package:mobile_dev_formative_2/features/incidents/feed_screen.dart';
import 'package:mobile_dev_formative_2/features/incidents/incident_detail_screen.dart';
import 'package:mobile_dev_formative_2/features/profile/profile_screen.dart';
import 'package:mobile_dev_formative_2/features/staff/staff_dashboard_screen.dart';
import 'package:mobile_dev_formative_2/providers/auth_providers.dart';
import 'package:mobile_dev_formative_2/providers/dashboard_providers.dart';
import 'package:mobile_dev_formative_2/providers/incident_providers.dart';
import 'package:mobile_dev_formative_2/providers/retry_policy.dart';

import '../helpers/builders.dart';

final _staff = AppUser(
  uid: 'staff1',
  displayName: 'Sam Staff',
  email: 'sam@alueducation.com',
  role: UserRole.staff,
  createdAt: DateTime(2026),
);

final _incidents = [
  for (final s in IncidentStatus.values)
    buildIncident(
      id: s.value,
      status: s,
      title: 'A fairly long report title for ${s.label} to test wrapping',
    ),
];

/// Every main screen, rendered in the dark theme on a small phone
/// (320 x 640, large text), must build without exceptions or overflow.
void main() {
  final overrides = <Override>[
    currentUserProfileProvider.overrideWith((ref) => Stream.value(_staff)),
    incidentsStreamProvider.overrideWith((ref) => Stream.value(_incidents)),
    allIncidentsStreamProvider.overrideWith((ref) => Stream.value(_incidents)),
    myIncidentsProvider.overrideWith((ref) => Stream.value(_incidents)),
    incidentDocProvider('in_progress')
        .overrideWith((ref) => Stream.value(_incidents[2])),
    statusHistoryProvider('in_progress').overrideWith(
      (ref) => Stream.value([
        StatusEvent(
          id: 'e',
          from: IncidentStatus.underReview,
          to: IncidentStatus.inProgress,
          changedBy: 'staff1',
          at: DateTime(2026, 11, 2),
          note: 'Technician assigned.',
        ),
      ]),
    ),
    reporterProfileProvider('uid1').overrideWith((ref) async => null),
  ];

  final screens = <String, Widget>{
    'feed': const FeedScreen(),
    'detail': const IncidentDetailScreen(incidentId: 'in_progress'),
    'dashboard': const StaffDashboardScreen(),
    'profile': const ProfileScreen(),
  };

  screens.forEach((name, screen) {
    testWidgets('$name renders in dark mode on a small phone', (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final container = ProviderContainer(
        retry: noAutomaticRetry,
        overrides: overrides,
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MediaQuery(
            data: const MediaQueryData(
              size: Size(320, 640),
              textScaler: TextScaler.linear(1.3),
            ),
            child: MaterialApp(
              theme: AppTheme.light(useGoogleFont: false),
              darkTheme: AppTheme.dark(useGoogleFont: false),
              themeMode: ThemeMode.dark,
              home: screen,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(
        Theme.of(tester.element(find.byWidget(screen))).brightness,
        Brightness.dark,
      );
    });
  });
}
