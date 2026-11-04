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

final storageProvider = Provider<FirebaseStorage>(
  (ref) => FirebaseStorage.instance,
);
