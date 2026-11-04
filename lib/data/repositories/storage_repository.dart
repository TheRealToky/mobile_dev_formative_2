import 'dart:typed_data';

import 'package:firebase_storage/firebase_storage.dart';

import '../../core/constants.dart';
import '../../core/errors.dart';
import 'firestore_errors.dart';

/// Incident photo storage.
abstract interface class StorageRepository {
  /// Uploads a JPEG to `incident_photos/{incidentId}/{fileName}` and returns
  /// its download URL. [onProgress] receives 0.0-1.0 as bytes are sent.
  Future<String> uploadIncidentPhoto({
    required String incidentId,
    required String uploaderUid,
    required Uint8List jpegBytes,
    void Function(double fraction)? onProgress,
  });

  /// Deletes a photo by its download URL. Missing files count as deleted.
  Future<void> deleteByUrl(String url);
}

/// [StorageRepository] backed by Firebase Storage.
class FirebaseStorageRepository implements StorageRepository {
  FirebaseStorageRepository(this._storage);

  final FirebaseStorage _storage;

  @override
  Future<String> uploadIncidentPhoto({
    required String incidentId,
    required String uploaderUid,
    required Uint8List jpegBytes,
    void Function(double fraction)? onProgress,
  }) => _guard(() async {
    final name = '${DateTime.now().microsecondsSinceEpoch}.jpg';
    final ref = _storage.ref('${Paths.incidentPhotos}/$incidentId/$name');
    final task = ref.putData(
      jpegBytes,
      SettableMetadata(
        contentType: 'image/jpeg',
        // storage.rules require this to equal the uploader's uid, which is
        // how ownership is checked before the incident document exists.
        customMetadata: {'ownerUid': uploaderUid},
      ),
    );
    final sub = task.snapshotEvents.listen((s) {
      if (s.totalBytes > 0) onProgress?.call(s.bytesTransferred / s.totalBytes);
    });
    try {
      await task;
    } finally {
      await sub.cancel();
    }
    return ref.getDownloadURL();
  });

  @override
  Future<void> deleteByUrl(String url) => _guard(() async {
    try {
      await _storage.refFromURL(url).delete();
    } on FirebaseException catch (e) {
      if (e.code != 'object-not-found') rethrow;
    }
  });

  Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on FirebaseException catch (e) {
      throw switch (e.code) {
        // No bucket yet: on new projects Storage needs the Blaze plan.
        'bucket-not-found' || 'project-not-found' => const UserFacingException(
          'Photo uploads are not available right now. '
          'Remove the photos to submit the report without them.',
        ),
        _ => toUserFacing(e),
      };
    }
  }
}
