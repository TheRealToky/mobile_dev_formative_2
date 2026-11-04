import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_dev_formative_2/data/models/incident.dart';
import 'package:mobile_dev_formative_2/providers/auth_providers.dart';
import 'package:mobile_dev_formative_2/providers/filter_providers.dart';
import 'package:mobile_dev_formative_2/providers/firebase_providers.dart';
import 'package:mobile_dev_formative_2/providers/incident_providers.dart';

import '../helpers/builders.dart';
import '../helpers/fakes.dart';

void main() {
  late FakeFirebaseFirestore db;

  setUp(() async {
    db = FakeFirebaseFirestore();
    final incidents = [
      buildIncident(
        id: 'tap',
        title: 'Leaking tap',
        category: IncidentCategory.water,
        createdAt: DateTime(2026, 1, 3),
      ),
      buildIncident(
        id: 'power',
        title: 'Power cut in hall A',
        description: 'No electricity on the whole floor.',
        category: IncidentCategory.electricity,
        status: IncidentStatus.inProgress,
        building: 'Residence hall A',
        createdAt: DateTime(2026, 1, 2),
      ),
      buildIncident(
        id: 'pipe',
        title: 'Burst pipe',
        category: IncidentCategory.water,
        status: IncidentStatus.inProgress,
        building: 'Cafeteria',
        createdAt: DateTime(2026, 1, 1),
      ),
    ];
    for (final i in incidents) {
      await db.doc('incidents/${i.id}').set({
        ...i.toMap(),
        'createdAt': i.createdAt,
        'updatedAt': i.createdAt,
      });
    }
  });

  ProviderContainer makeContainer({bool signedIn = true}) {
    final container = ProviderContainer.test(
      overrides: [
        firestoreProvider.overrideWithValue(db),
        authStateProvider.overrideWith(
          (ref) => Stream.value(signedIn ? mockUser() : null),
        ),
      ],
    );
    container.listen(filteredIncidentsProvider, (_, _) {});
    return container;
  }

  /// Waits for the stream and returns the ids the feed would show.
  Future<List<String>> feedIds(ProviderContainer c) async {
    await c.read(incidentsStreamProvider.future);
    await Future<void>.delayed(Duration.zero);
    return c
        .read(filteredIncidentsProvider)
        .requireValue
        .map((i) => i.id)
        .toList();
  }

  test('no filters: everything, newest first', () async {
    final c = makeContainer();
    expect(await feedIds(c), ['tap', 'power', 'pipe']);
  });

  test('category filter is applied server-side', () async {
    final c = makeContainer();
    c.read(categoryFilterProvider.notifier).toggle(IncidentCategory.water);
    expect(await feedIds(c), ['tap', 'pipe']);
  });

  test('category and status combine', () async {
    final c = makeContainer();
    c.read(categoryFilterProvider.notifier).toggle(IncidentCategory.water);
    c.read(statusFilterProvider.notifier).toggle(IncidentStatus.inProgress);
    expect(await feedIds(c), ['pipe']);
  });

  test('search combines with filters and matches building', () async {
    final c = makeContainer();
    c.read(statusFilterProvider.notifier).toggle(IncidentStatus.inProgress);
    c.read(searchQueryProvider.notifier).set('cafeteria');
    expect(await feedIds(c), ['pipe']);
  });

  test('toggling the same chip twice clears the filter', () async {
    final c = makeContainer();
    final notifier = c.read(categoryFilterProvider.notifier);
    notifier.toggle(IncidentCategory.water);
    notifier.toggle(IncidentCategory.water);
    expect(c.read(categoryFilterProvider), isNull);
    expect(await feedIds(c), hasLength(3));
  });

  test('hasActiveFilters and clear', () {
    final c = makeContainer();
    expect(c.read(hasActiveFiltersProvider), isFalse);
    c.read(searchQueryProvider.notifier).set('tap');
    expect(c.read(hasActiveFiltersProvider), isTrue);
    c.read(searchQueryProvider.notifier).clear();
    expect(c.read(hasActiveFiltersProvider), isFalse);
  });

  test('signed out: empty list, no Firestore query', () async {
    final c = makeContainer(signedIn: false);
    expect(await feedIds(c), isEmpty);
  });

  group('incidentByIdProvider', () {
    test('combines the incident with its history, oldest first', () async {
      await db.doc('incidents/tap/statusHistory/b').set({
        'from': 'under_review',
        'to': 'in_progress',
        'note': '',
        'changedBy': 'staff1',
        'at': DateTime(2026, 1, 5),
      });
      await db.doc('incidents/tap/statusHistory/a').set({
        'from': 'submitted',
        'to': 'under_review',
        'note': 'Seen',
        'changedBy': 'staff1',
        'at': DateTime(2026, 1, 4),
      });
      final c = makeContainer();
      c.listen(incidentByIdProvider('tap'), (_, _) {});
      await c.read(incidentDocProvider('tap').future);
      await c.read(statusHistoryProvider('tap').future);

      final detail = c.read(incidentByIdProvider('tap')).requireValue;
      expect(detail.incident?.title, 'Leaking tap');
      expect(detail.history.map((e) => e.note), ['Seen', '']);
    });

    test('a missing document gives null, not an error', () async {
      final c = makeContainer();
      c.listen(incidentByIdProvider('gone'), (_, _) {});
      await c.read(incidentDocProvider('gone').future);
      await c.read(statusHistoryProvider('gone').future);

      final value = c.read(incidentByIdProvider('gone'));
      expect(value.hasError, isFalse);
      expect(value.requireValue.incident, isNull);
    });
  });
}
