import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/errors.dart';
import '../data/models/app_user.dart';
import '../data/models/incident.dart';
import '../data/models/report_draft.dart';
import '../data/repositories/storage_repository.dart';
import '../data/services/photo_services.dart';
import 'auth_providers.dart';
import 'firebase_providers.dart';
import 'incident_providers.dart';

final storageRepositoryProvider = Provider<StorageRepository>(
  (ref) => FirebaseStorageRepository(ref.watch(storageProvider)),
);

final photoSourceProvider = Provider<PhotoSource>(
  (ref) => ImagePickerPhotoSource(),
);

final imageCompressorProvider = Provider<ImageCompressor>(
  (ref) => const FlutterImageCompressor(),
);

/// How long to wait for the server to confirm a write before treating the
/// device as offline. The write stays queued by Firestore, so photos are
/// kept. A provider so tests can shorten it.
final reportWriteTimeoutProvider = Provider<Duration>(
  (ref) => const Duration(seconds: 15),
);

/// Result of a successful submit or edit.
class ReportResult {
  const ReportResult({required this.incidentId, this.queuedOffline = false});

  final String incidentId;

  /// The device is offline: Firestore saved the write locally and will send
  /// it when the connection returns (same document id, so no duplicate).
  final bool queuedOffline;
}

/// Submits, edits and deletes reports.
///
/// While working, [state] is `AsyncLoading(progress: 0..1)`: photo uploads
/// take the first 90 %, the Firestore write the rest. The order is chosen
/// so the document only ever contains working photo URLs:
///   1. compress each photo (strips EXIF) and upload it,
///   2. write the document with the download URLs,
///   3. if anything fails, delete the photos uploaded in step 1.
class ReportController extends AsyncNotifier<void> {
  static const _uploadShare = 0.9;

  @override
  FutureOr<void> build() {}

  /// Creates a new incident from [draft]. Returns `null` on failure (the
  /// error is in [state]).
  Future<ReportResult?> submit(ReportDraft draft) => _run((profile) async {
    final id = ref.read(incidentRepositoryProvider).newIncidentId();
    final uploaded = <String>[];
    try {
      final urls = await _uploadPhotos(id, profile.uid, draft, uploaded);
      final incident = draft.toIncident(
        id: id,
        reporterId: profile.uid,
        reporterName: profile.displayName,
        photoUrls: urls,
      );
      return await _write(
        id,
        () => ref.read(incidentRepositoryProvider).createIncident(incident),
      );
    } catch (_) {
      await _deleteQuietly(uploaded);
      rethrow;
    }
  });

  /// Saves the reporter's changes to [original]. New photos are uploaded
  /// first; photos the user removed are deleted only after the save.
  Future<ReportResult?> saveEdit(Incident original, ReportDraft draft) => _run((
    profile,
  ) async {
    final uploaded = <String>[];
    final ReportResult result;
    try {
      final urls = await _uploadPhotos(
        original.id,
        profile.uid,
        draft,
        uploaded,
      );
      final updated = draft.toIncident(
        id: original.id,
        reporterId: original.reporterId,
        reporterName: profile.displayName,
        photoUrls: urls,
        status: original.status,
        createdAt: original.createdAt,
      );
      result = await _write(
        original.id,
        () => ref.read(incidentRepositoryProvider).updateIncident(updated),
      );
    } catch (_) {
      await _deleteQuietly(uploaded);
      rethrow;
    }
    final kept = draft.keptUrls.toSet();
    await _deleteQuietly(original.photoUrls.where((u) => !kept.contains(u)));
    return result;
  });

  /// Deletes [incident] and then its photos. Returns whether it succeeded.
  Future<bool> delete(Incident incident) async {
    final result = await _run((_) async {
      await ref.read(incidentRepositoryProvider).deleteIncident(incident.id);
      // The report is gone either way; leftover files are only storage cost.
      await _deleteQuietly(incident.photoUrls);
      return true;
    });
    return result ?? false;
  }

  /// Compresses and uploads the draft's local photos, in order, keeping
  /// remote ones. Every uploaded URL is added to [uploaded] immediately so
  /// the caller can clean up after a partial failure.
  Future<List<String>> _uploadPhotos(
    String incidentId,
    String uid,
    ReportDraft draft,
    List<String> uploaded,
  ) async {
    final total = draft.localPhotos.length;
    var done = 0;
    final urls = <String>[];
    final compressor = ref.read(imageCompressorProvider);
    final storage = ref.read(storageRepositoryProvider);

    for (final photo in draft.photos) {
      switch (photo) {
        case RemotePhoto(:final url):
          urls.add(url);
        case LocalPhoto(:final path):
          final bytes = await compressor.compressForUpload(path);
          final url = await storage.uploadIncidentPhoto(
            incidentId: incidentId,
            uploaderUid: uid,
            jpegBytes: bytes,
            onProgress: (f) => _progress((done + f) / total * _uploadShare),
          );
          uploaded.add(url);
          urls.add(url);
          done++;
          _progress(done / total * _uploadShare);
      }
    }
    _progress(_uploadShare);
    return urls;
  }

  Future<ReportResult> _write(String id, Future<void> Function() write) async {
    try {
      await write().timeout(ref.read(reportWriteTimeoutProvider));
      return ReportResult(incidentId: id);
    } on TimeoutException {
      return ReportResult(incidentId: id, queuedOffline: true);
    }
  }

  Future<void> _deleteQuietly(Iterable<String> urls) async {
    final storage = ref.read(storageRepositoryProvider);
    for (final url in urls.toList()) {
      try {
        await storage.deleteByUrl(url);
      } on Object {
        // Best effort: an orphaned file is harmless and never shown.
      }
    }
  }

  void _progress(double value) {
    if (ref.mounted) state = AsyncLoading(progress: value.clamp(0, 1));
  }

  /// Runs [action] for the signed-in user, tracking loading/error state.
  Future<T?> _run<T>(Future<T> Function(AppUser profile) action) async {
    final profile = ref.read(currentUserProfileProvider).value;
    if (profile == null) {
      state = AsyncError(
        const UserFacingException('Your session has expired. Log in again.'),
        StackTrace.current,
      );
      return null;
    }
    state = const AsyncLoading(progress: 0);
    try {
      final result = await action(profile);
      if (ref.mounted) state = const AsyncData(null);
      return result;
    } catch (e, s) {
      if (ref.mounted) state = AsyncError(e, s);
      return null;
    }
  }
}

final reportControllerProvider = AsyncNotifierProvider<ReportController, void>(
  ReportController.new,
);
