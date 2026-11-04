import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_dev_formative_2/data/models/incident.dart';
import 'package:mobile_dev_formative_2/data/repositories/incident_repository.dart';

import '../../helpers/builders.dart';

void main() {
  late FakeFirebaseFirestore db;
  late FirestoreIncidentRepository repo;

  setUp(() {
    db = FakeFirebaseFirestore();
    repo = FirestoreIncidentRepository(db);
  });

  Future<void> seed(Incident incident, {DateTime? at}) =>
      db.doc('incidents/${incident.id}').set({
        ...incident.toMap(),
        'createdAt': at ?? incident.createdAt,
        'updatedAt': at ?? incident.createdAt,
      });

  test('createIncident forces submitted and uses the given id', () async {
    await repo.createIncident(
      buildIncident(id: 'abc', status: IncidentStatus.resolved),
    );
    final stored = (await db.doc('incidents/abc').get()).data()!;
    expect(stored['status'], 'submitted');
    expect(stored['createdAt'], isNotNull);
    expect(stored['updatedAt'], isNotNull);
  });

  test('newIncidentId returns unique ids', () {
    expect(repo.newIncidentId(), isNot(repo.newIncidentId()));
  });

  group('watchIncidents', () {
    setUp(() async {
      await seed(
        buildIncident(id: 'old', category: IncidentCategory.water),
        at: DateTime(2026, 1, 1),
      );
      await seed(
        buildIncident(
          id: 'new',
          category: IncidentCategory.electricity,
          status: IncidentStatus.inProgress,
        ),
        at: DateTime(2026, 6, 1),
      );
      await seed(
        buildIncident(
          id: 'mid',
          category: IncidentCategory.water,
          status: IncidentStatus.inProgress,
        ),
        at: DateTime(2026, 3, 1),
      );
    });

    List<String> ids(List<Incident> list) => list.map((i) => i.id).toList();

    test('returns newest first', () async {
      expect(ids(await repo.watchIncidents().first), ['new', 'mid', 'old']);
    });

    test('filters by category and status, alone and combined', () async {
      expect(
        ids(await repo.watchIncidents(category: IncidentCategory.water).first),
        ['mid', 'old'],
      );
      expect(
        ids(await repo.watchIncidents(status: IncidentStatus.inProgress).first),
        ['new', 'mid'],
      );
      expect(
        ids(
          await repo
              .watchIncidents(
                category: IncidentCategory.water,
                status: IncidentStatus.inProgress,
              )
              .first,
        ),
        ['mid'],
      );
    });
    test('watchMyIncidents returns only the caller reports', () async {
      await seed(
        buildIncident(id: 'other', reporterId: 'uid2'),
        at: DateTime(2026, 7, 1),
      );
      await seed(
        buildIncident(id: 'anon', isAnonymous: true, reporterName: null),
        at: DateTime(2026, 8, 1),
      );
      expect(ids(await repo.watchMyIncidents('uid1').first), [
        'anon',
        'new',
        'mid',
        'old',
      ]);
      expect(ids(await repo.watchMyIncidents('uid2').first), ['other']);
    });
  });

  test('updateIncident only writes reporter-editable fields', () async {
    await seed(buildIncident());
    await repo.updateIncident(
      buildIncident(
        title: 'Leaking tap, worse now',
        status: IncidentStatus.resolved,
        reporterId: 'attacker',
      ),
    );
    final stored = (await db.doc('incidents/inc1').get()).data()!;
    expect(stored['title'], 'Leaking tap, worse now');
    expect(stored['status'], 'submitted');
    expect(stored['reporterId'], 'uid1');
  });

  test('updateStatus changes status and appends history together', () async {
    await seed(buildIncident());
    await repo.updateStatus(
      incidentId: 'inc1',
      from: IncidentStatus.submitted,
      to: IncidentStatus.underReview,
      changedBy: 'staff1',
      note: '  Checking with maintenance  ',
    );

    expect(
      (await repo.watchIncident('inc1').first)?.status,
      IncidentStatus.underReview,
    );
    final history = await repo.watchHistory('inc1').first;
    expect(history, hasLength(1));
    expect(history.single.from, IncidentStatus.submitted);
    expect(history.single.to, IncidentStatus.underReview);
    expect(history.single.changedBy, 'staff1');
    expect(history.single.note, 'Checking with maintenance');
  });

  test('deleteIncident removes the incident and its history', () async {
    await seed(buildIncident());
    await repo.updateStatus(
      incidentId: 'inc1',
      from: IncidentStatus.submitted,
      to: IncidentStatus.underReview,
      changedBy: 'staff1',
    );
    await repo.deleteIncident('inc1');

    expect(await repo.watchIncident('inc1').first, isNull);
    expect(
      (await db.collection('incidents/inc1/statusHistory').get()).docs,
      isEmpty,
    );
  });
}
