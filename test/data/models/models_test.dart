import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_dev_formative_2/data/models/app_user.dart';
import 'package:mobile_dev_formative_2/data/models/incident.dart';
import 'package:mobile_dev_formative_2/data/models/status_event.dart';

void main() {
  // Local times: Timestamp.toDate() returns local DateTimes, and DateTime ==
  // also compares the isUtc flag.
  final created = DateTime(2026, 11, 1, 9);
  final updated = DateTime(2026, 11, 2, 14);

  Incident sample({bool anonymous = false}) => Incident(
    id: 'inc1',
    title: 'Leaking tap',
    description: 'The tap in the 2nd floor bathroom leaks all night.',
    category: IncidentCategory.water,
    status: IncidentStatus.underReview,
    location: const IncidentLocation(building: 'Library', detail: '2nd floor'),
    photoUrls: const ['https://example.com/a.jpg'],
    reporterId: 'uid1',
    reporterName: 'Ada',
    isAnonymous: anonymous,
    createdAt: created,
    updatedAt: updated,
  );

  group('Incident', () {
    test('toMap writes stored values, not enum names', () {
      final map = sample().toMap();
      expect(map['category'], 'water');
      expect(map['status'], 'under_review');
      expect(map['location'], {'building': 'Library', 'detail': '2nd floor'});
      expect(
        map.containsKey('createdAt'),
        isFalse,
        reason: 'timestamps are added by the repository',
      );
    });

    test('round-trips through a Firestore map with Timestamps', () {
      final map = {
        ...sample().toMap(),
        'createdAt': Timestamp.fromDate(created),
        'updatedAt': Timestamp.fromDate(updated),
      };
      final parsed = Incident.fromMap('inc1', map);
      expect(parsed, sample());
      expect(parsed.createdAt.isAtSameMomentAs(created), isTrue);
    });

    test('anonymous reports never write the reporter name', () {
      final map = sample(anonymous: true).toMap();
      expect(map['reporterName'], isNull);
      expect(map['reporterId'], 'uid1', reason: 'kept for staff follow-up');
    });

    test('tolerates pending server timestamps and missing fields', () {
      final parsed = Incident.fromMap('x', {
        'title': 'Broken chair',
        'createdAt': null,
      });
      expect(parsed.title, 'Broken chair');
      expect(parsed.category, IncidentCategory.other);
      expect(parsed.status, IncidentStatus.submitted);
      expect(parsed.photoUrls, isEmpty);
      expect(parsed.location.building, 'Unknown');
      expect(parsed.updatedAt, parsed.createdAt);
    });

    test('is editable by the reporter only while submitted', () {
      expect(sample().isEditableByReporter, isFalse);
      expect(
        sample()
            .copyWith(status: IncidentStatus.submitted)
            .isEditableByReporter,
        isTrue,
      );
    });

    test('location display joins building and detail', () {
      expect(sample().location.display, 'Library, 2nd floor');
      expect(
        const IncidentLocation(building: 'Cafeteria').display,
        'Cafeteria',
      );
    });
  });

  group('AppUser', () {
    test('round-trips and defaults unknown roles to student', () {
      final user = AppUser.fromMap('uid1', {
        'displayName': 'Ada',
        'email': 'ada@alustudent.com',
        'role': 'staff',
        'createdAt': Timestamp.fromDate(created),
      });
      expect(user.isStaff, isTrue);
      expect(user.toMap(), {
        'displayName': 'Ada',
        'email': 'ada@alustudent.com',
        'role': 'staff',
      });
      expect(AppUser.fromMap('u', {'role': 'admin'}).role, UserRole.student);
      expect(AppUser.fromMap('u', {}).role, UserRole.student);
    });
  });

  group('StatusEvent', () {
    test('round-trips through a Firestore map', () {
      final event = StatusEvent(
        id: 'e1',
        from: IncidentStatus.underReview,
        to: IncidentStatus.inProgress,
        note: 'Plumber booked',
        changedBy: 'staff1',
        at: created,
      );
      final map = {...event.toMap(), 'at': Timestamp.fromDate(created)};
      expect(map['to'], 'in_progress');
      expect(StatusEvent.fromMap('e1', map), event);
    });
  });
}
