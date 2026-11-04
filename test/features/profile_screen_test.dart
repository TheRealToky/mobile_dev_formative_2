import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_dev_formative_2/app/theme.dart';
import 'package:mobile_dev_formative_2/data/models/app_user.dart';
import 'package:mobile_dev_formative_2/data/models/incident.dart';
import 'package:mobile_dev_formative_2/features/profile/profile_screen.dart';
import 'package:mobile_dev_formative_2/providers/auth_providers.dart';
import 'package:mobile_dev_formative_2/providers/incident_providers.dart';
import 'package:mobile_dev_formative_2/providers/retry_policy.dart';
import 'package:mobile_dev_formative_2/providers/theme_providers.dart';
import 'package:mobile_dev_formative_2/widgets/incident_card.dart';
import 'package:mocktail/mocktail.dart';

import '../helpers/builders.dart';
import '../helpers/fakes.dart';

AppUser _user(UserRole role) => AppUser(
  uid: 'uid1',
  displayName: 'Ada Lovelace',
  email: 'ada@alustudent.com',
  role: role,
  createdAt: DateTime(2026),
);

void main() {
  late MockAuthRepository auth;

  setUp(() {
    auth = MockAuthRepository();
    when(() => auth.signOut()).thenAnswer((_) async {});
  });

  Future<ProviderContainer> pumpProfile(
    WidgetTester tester, {
    UserRole role = UserRole.student,
    List<Incident> mine = const [],
  }) async {
    // Tall phone so the whole profile, including Log out, is on screen.
    tester.view.physicalSize = const Size(420, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final container = ProviderContainer(
      retry: noAutomaticRetry,
      overrides: [
        authRepositoryProvider.overrideWithValue(auth),
        currentUserProfileProvider.overrideWith(
          (ref) => Stream.value(_user(role)),
        ),
        myIncidentsProvider.overrideWith((ref) => Stream.value(mine)),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.light(useGoogleFont: false),
          home: const ProfileScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return container;
  }

  testWidgets('shows name, email, initials and the student badge', (
    tester,
  ) async {
    await pumpProfile(tester);
    expect(find.text('Ada Lovelace'), findsOneWidget);
    expect(find.text('ada@alustudent.com'), findsOneWidget);
    expect(find.text('AL'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(RoleBadge),
        matching: find.text('Student'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('staff get the staff badge', (tester) async {
    await pumpProfile(tester, role: UserRole.staff);
    expect(
      find.descendant(of: find.byType(RoleBadge), matching: find.text('Staff')),
      findsOneWidget,
    );
  });

  testWidgets('lists my reports with an open count', (tester) async {
    await pumpProfile(
      tester,
      mine: [
        buildIncident(id: 'a'),
        buildIncident(id: 'b', status: IncidentStatus.resolved),
      ],
    );
    expect(find.text('2 reports, 1 still open'), findsOneWidget);
    expect(find.byType(IncidentCard), findsNWidgets(2));
  });

  testWidgets('no reports yet invites the user to report', (tester) async {
    await pumpProfile(tester);
    expect(find.text('You have not reported anything yet.'), findsOneWidget);
    expect(find.text('Report an issue'), findsOneWidget);
  });

  testWidgets('theme picker switches to dark', (tester) async {
    final c = await pumpProfile(tester);
    await tester.tap(find.text('Dark'));
    await tester.pumpAndSettle();
    expect(c.read(themeModeProvider), ThemeMode.dark);
  });

  testWidgets('log out asks first, then signs out', (tester) async {
    await pumpProfile(tester);
    final button = find.widgetWithText(OutlinedButton, 'Log out');
    await tester.tap(button);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Stay signed in'));
    await tester.pumpAndSettle();
    verifyNever(() => auth.signOut());

    await tester.tap(button);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Log out'));
    await tester.pumpAndSettle();
    verify(() => auth.signOut()).called(1);
  });
}
