import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_dev_formative_2/core/errors.dart';
import 'package:mobile_dev_formative_2/data/models/app_user.dart';
import 'package:mobile_dev_formative_2/data/models/incident.dart';
import 'package:mobile_dev_formative_2/data/repositories/incident_repository.dart';
import 'package:mobile_dev_formative_2/providers/auth_providers.dart';
import 'package:mobile_dev_formative_2/providers/incident_providers.dart';
import 'package:mobile_dev_formative_2/providers/report_controller.dart';
import 'package:mobile_dev_formative_2/providers/retry_policy.dart';
import 'package:mobile_dev_formative_2/providers/status_controller.dart';
import 'package:mocktail/mocktail.dart';

import '../helpers/builders.dart';

class MockIncidentRepository extends Mock implements IncidentRepository {}

AppUser _profile(UserRole role) => AppUser(
  uid: role == UserRole.staff ? 'staff1' : 'uid1',
  displayName: 'Someone',
  email: 'someone@alueducation.com',
  role: role,
  createdAt: DateTime(2026),
);

void main() {
  late MockIncidentRepository repo;

  setUpAll(() => registerFallbackValue(IncidentStatus.submitted));

  setUp(() => repo = MockIncidentRepository());

  void stubUpdate(Future<void> Function() answer) => when(
    () => repo.updateStatus(
      incidentId: any(named: 'incidentId'),
      from: any(named: 'from'),
      to: any(named: 'to'),
      changedBy: any(named: 'changedBy'),
      note: any(named: 'note'),
    ),
  ).thenAnswer((_) => answer());

  Future<ProviderContainer> makeContainer(
    UserRole role, {
    Duration timeout = const Duration(seconds: 5),
  }) async {
    final c = ProviderContainer.test(
      retry: noAutomaticRetry,
      overrides: [
        incidentRepositoryProvider.overrideWithValue(repo),
        reportWriteTimeoutProvider.overrideWithValue(timeout),
        currentUserProfileProvider.overrideWith(
          (ref) => Stream.value(_profile(role)),
        ),
      ],
    );
    c.listen(currentUserProfileProvider, (_, _) {});
    c.listen(statusControllerProvider, (_, _) {});
    await c.read(currentUserProfileProvider.future);
    return c;
  }

  test('staff move a report along the lifecycle with a note', () async {
    stubUpdate(() async {});
    final c = await makeContainer(UserRole.staff);

    final result = await c
        .read(statusControllerProvider.notifier)
        .updateStatus(
          buildIncident(),
          IncidentStatus.underReview,
          note: 'Looking into it',
        );

    expect(result?.status, IncidentStatus.underReview);
    expect(result?.queuedOffline, isFalse);
    verify(
      () => repo.updateStatus(
        incidentId: 'inc1',
        from: IncidentStatus.submitted,
        to: IncidentStatus.underReview,
        changedBy: 'staff1',
        note: 'Looking into it',
      ),
    ).called(1);
    expect(c.read(statusControllerProvider).hasError, isFalse);
  });

  test('students are refused before anything is written', () async {
    final c = await makeContainer(UserRole.student);
    final result = await c
        .read(statusControllerProvider.notifier)
        .updateStatus(buildIncident(), IncidentStatus.underReview);
    expect(result, isNull);
    expect(c.read(statusControllerProvider).error, isA<UserFacingException>());
    verifyZeroInteractions(repo);
  });

  test('moving to the same status is refused', () async {
    final c = await makeContainer(UserRole.staff);
    final result = await c
        .read(statusControllerProvider.notifier)
        .updateStatus(buildIncident(), IncidentStatus.submitted);
    expect(result, isNull);
    expect(
      friendlyError(c.read(statusControllerProvider).error!),
      contains('already submitted'),
    );
    verifyZeroInteractions(repo);
  });

  test('a repository error ends in the error state', () async {
    stubUpdate(
      () async =>
          throw const UserFacingException('You do not have permission.'),
    );
    final c = await makeContainer(UserRole.staff);
    final result = await c
        .read(statusControllerProvider.notifier)
        .updateStatus(buildIncident(), IncidentStatus.underReview);
    expect(result, isNull);
    expect(c.read(statusControllerProvider).hasError, isTrue);
  });

  test('an unconfirmed write is reported as queued offline', () async {
    stubUpdate(() => Completer<void>().future);
    final c = await makeContainer(
      UserRole.staff,
      timeout: const Duration(milliseconds: 50),
    );
    final result = await c
        .read(statusControllerProvider.notifier)
        .updateStatus(buildIncident(), IncidentStatus.underReview);
    expect(result?.queuedOffline, isTrue);
  });
}
