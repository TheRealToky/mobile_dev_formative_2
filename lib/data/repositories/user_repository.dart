import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/constants.dart';
import '../models/app_user.dart';

/// Access to `users/{uid}` profile documents.
abstract interface class UserRepository {
  /// Streams the profile for [uid]. If the document does not exist yet (first
  /// login after verifying the email), it is created once with the role
  /// for the email domain ([UserRole.forEmail]), and the stream emits `null`
  /// until the write lands. An existing document is never changed, so a role
  /// edited in the console wins.
  Stream<AppUser?> watchOrCreateProfile({
    required String uid,
    required String email,
    required String displayName,
  });

  /// One-off read, used by staff to see who filed an anonymous report.
  Future<AppUser?> getUser(String uid);
}

/// [UserRepository] backed by Cloud Firestore.
class FirestoreUserRepository implements UserRepository {
  FirestoreUserRepository(this._db);

  final FirebaseFirestore _db;

  DocumentReference<Map<String, dynamic>> _doc(String uid) =>
      _db.collection(Paths.users).doc(uid);

  @override
  Stream<AppUser?> watchOrCreateProfile({
    required String uid,
    required String email,
    required String displayName,
  }) async* {
    var createRequested = false;
    await for (final snap in _doc(uid).snapshots()) {
      final data = snap.data();
      if (data != null) {
        yield AppUser.fromMap(uid, data);
        continue;
      }
      yield null;
      if (!createRequested) {
        createRequested = true;
        // firestore.rules only accept the role that matches the email
        // domain, so nobody can sign themselves up as staff.
        await _doc(uid).set({
          'displayName': displayName,
          'email': email,
          'role': UserRole.forEmail(email).value,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
    }
  }

  @override
  Future<AppUser?> getUser(String uid) async {
    final snap = await _doc(uid).get();
    final data = snap.data();
    return data == null ? null : AppUser.fromMap(uid, data);
  }
}
