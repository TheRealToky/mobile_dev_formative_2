import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../../core/constants.dart';
import 'firestore_errors.dart';

/// Incident photo storage.
///
/// Photos live in Cloud Firestore, not Cloud Storage, so the app runs on the
/// free Spark plan (new projects cannot create a Storage bucket without
/// Blaze). Each photo is one document,
/// `incidents/{incidentId}/photos/{photoId}`, holding the compressed JPEG as
/// a Bytes field. A Firestore document is capped at 1 MiB, which is why
/// [Limits.maxPhotoBytes] is lower than a typical Storage limit.
///
/// The incident's `photoUrls` list stores each photo's document path (a
/// "photo reference"). Older reports may still hold `https://` download URLs
/// from Cloud Storage; [isNetworkUrl] tells the two apart.
abstract interface class PhotoRepository {
  /// Saves a JPEG as a new photo document and returns its reference.
  /// [onProgress] receives 0.0-1.0 (Firestore reports no partial progress,
  /// so it jumps to 1.0 when the write is done or queued offline).
  Future<String> uploadIncidentPhoto({
    required String incidentId,
    required String uploaderUid,
    required Uint8List jpegBytes,
    void Function(double fraction)? onProgress,
  });

  /// The JPEG bytes for [photoRef], or `null` if the photo no longer exists.
  Future<Uint8List?> loadPhoto(String photoRef);

  /// Deletes a photo by its reference. Missing photos count as deleted.
  /// Legacy `https://` URLs are ignored (there is no Storage bucket).
  Future<void> deletePhoto(String photoRef);
}

/// Whether [photoRef] is a legacy Cloud Storage download URL rather than a
/// Firestore photo document path.
bool isNetworkUrl(String photoRef) =>
    photoRef.startsWith('https://') || photoRef.startsWith('http://');

/// Field names of a photo document. Mirrored in `firestore.rules`.
abstract final class PhotoFields {
  static const data = 'data';
  static const ownerUid = 'ownerUid';
  static const contentType = 'contentType';
  static const createdAt = 'createdAt';
}

/// [PhotoRepository] backed by Cloud Firestore.
class FirestorePhotoRepository implements PhotoRepository {
  FirestorePhotoRepository(
    this._db, {
    this.writeTimeout = const Duration(seconds: 15),
  });

  final FirebaseFirestore _db;

  /// How long to wait for the server to confirm a photo write. Offline, the
  /// write stays queued locally and Firestore sends it before the incident
  /// document that references it (writes are sent in order), so the submit
  /// can continue instead of hanging.
  final Duration writeTimeout;

  @override
  Future<String> uploadIncidentPhoto({
    required String incidentId,
    required String uploaderUid,
    required Uint8List jpegBytes,
    void Function(double fraction)? onProgress,
  }) => guardFirebase(() async {
    final doc = _db
        .collection(Paths.incidents)
        .doc(incidentId)
        .collection(Paths.photos)
        .doc();
    onProgress?.call(0);
    try {
      await doc
          .set({
            PhotoFields.data: Blob(jpegBytes),
            // firestore.rules require this to equal the uploader's uid, so
            // ownership is known before the incident document exists.
            PhotoFields.ownerUid: uploaderUid,
            PhotoFields.contentType: 'image/jpeg',
            PhotoFields.createdAt: FieldValue.serverTimestamp(),
          })
          .timeout(writeTimeout);
    } on TimeoutException {
      // Queued offline; see [writeTimeout].
    }
    onProgress?.call(1);
    return doc.path;
  });

  @override
  Future<Uint8List?> loadPhoto(String photoRef) => guardFirebase(() async {
    final snap = await _db.doc(photoRef).get();
    return switch (snap.data()?[PhotoFields.data]) {
      Blob(:final bytes) => bytes,
      Uint8List bytes => bytes,
      _ => null,
    };
  });

  @override
  Future<void> deletePhoto(String photoRef) => guardFirebase(() async {
    if (isNetworkUrl(photoRef)) return;
    await _db.doc(photoRef).delete();
  });
}

/// Builds a photo reference; used by tests and previews.
@visibleForTesting
String photoRefFor(String incidentId, String photoId) =>
    '${Paths.incidents}/$incidentId/${Paths.photos}/$photoId';
