import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_dev_formative_2/data/models/app_user.dart';
import 'package:mobile_dev_formative_2/data/repositories/user_repository.dart';

void main() {
  late FakeFirebaseFirestore db;
  late FirestoreUserRepository repo;

  setUp(() {
    db = FakeFirebaseFirestore();
    repo = FirestoreUserRepository(db);
  });

  test('creates a student profile on first login, then streams it', () async {
    final emitted = await repo
        .watchOrCreateProfile(
          uid: 'uid1',
          email: 'ada@alustudent.com',
          displayName: 'Ada',
        )
        .take(2)
        .toList();

    expect(emitted.first, isNull, reason: 'document did not exist yet');
    expect(emitted.last?.role, UserRole.student);
    expect(emitted.last?.displayName, 'Ada');

    final stored = (await db.doc('users/uid1').get()).data()!;
    expect(stored['role'], 'student');
    expect(stored['createdAt'], isNotNull);
  });

  test('never overwrites an existing profile (keeps staff role)', () async {
    await db.doc('users/uid1').set({
      'displayName': 'Grace',
      'email': 'grace@alueducation.com',
      'role': 'staff',
    });

    final first = await repo
        .watchOrCreateProfile(
          uid: 'uid1',
          email: 'grace@alueducation.com',
          displayName: 'Grace',
        )
        .first;

    expect(first?.isStaff, isTrue);
    expect((await db.doc('users/uid1').get()).data()!['role'], 'staff');
  });

  test('getUser returns null for unknown uids', () async {
    expect(await repo.getUser('nobody'), isNull);
  });
}
