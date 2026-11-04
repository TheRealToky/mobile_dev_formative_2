import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Firebase SDK singletons. Exposed as providers (never used directly) so
/// tests can override them with fakes such as `FakeFirebaseFirestore`.
final firebaseAuthProvider = Provider<FirebaseAuth>(
  (ref) => FirebaseAuth.instance,
);

final firestoreProvider = Provider<FirebaseFirestore>(
  (ref) => FirebaseFirestore.instance,
);

/// Uploads give up after 30 s instead of the SDK's 10 min default, so an
/// offline submission reports an error promptly instead of spinning.
final storageProvider = Provider<FirebaseStorage>(
  (ref) => FirebaseStorage.instance
    ..setMaxUploadRetryTime(const Duration(seconds: 30))
    ..setMaxOperationRetryTime(const Duration(seconds: 30)),
);
