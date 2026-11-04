import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/constants.dart';
import '../models/incident.dart';
import '../models/status_event.dart';
import 'firestore_errors.dart';

/// Reads and writes incidents and their status history.
///
/// Abstract so tests and providers can use a fake; the Firestore
/// implementation is the only code that touches the `incidents` collection.
abstract interface class IncidentRepository {
  /// Real-time list, newest first. [category] and [status] are applied as
  /// server-side `where` filters (backed by `firestore.indexes.json`).
  Stream<List<Incident>> watchIncidents({
    IncidentCategory? category,
    IncidentStatus? status,
  });

  /// Real-time list of the reports filed by [reporterUid], newest first
  /// (Profile, "My reports"). Includes the user's anonymous reports.
  Stream<List<Incident>> watchMyIncidents(String reporterUid);

  /// Real-time single incident; emits `null` once it is deleted.
  Stream<Incident?> watchIncident(String id);

  /// Real-time status history, oldest first (timeline order).
  Stream<List<StatusEvent>> watchHistory(String incidentId);

  /// A fresh document id, so photos can be uploaded to
  /// `incident_photos/{id}/` before the document is written.
  String newIncidentId();

  /// Writes a new incident with [Incident.id] as its document id. Status is
  /// forced to `submitted` and timestamps are set by the server.
  Future<void> createIncident(Incident incident);

  /// Saves the reporter-editable fields of an existing incident.
  Future<void> updateIncident(Incident incident);

  /// Deletes the incident and any history entries in one batch.
  Future<void> deleteIncident(String id);

  /// Staff status change: updates `status`/`updatedAt` and appends the
  /// history entry in one atomic batch, so they succeed or fail together.
  Future<void> updateStatus({
    required String incidentId,
    required IncidentStatus from,
    required IncidentStatus to,
    required String changedBy,
    String note = '',
  });
}

/// [IncidentRepository] backed by Cloud Firestore.
class FirestoreIncidentRepository implements IncidentRepository {
  FirestoreIncidentRepository(this._db);

  final FirebaseFirestore _db;

  /// Upper bound on the feed size; free-text search runs client-side over
  /// this window (see Limitations in the report).
  static const feedLimit = 200;

  CollectionReference<Map<String, dynamic>> get _incidents =>
      _db.collection(Paths.incidents);

  CollectionReference<Map<String, dynamic>> _history(String incidentId) =>
      _incidents.doc(incidentId).collection(Paths.statusHistory);

  @override
  Stream<List<Incident>> watchIncidents({
    IncidentCategory? category,
    IncidentStatus? status,
  }) {
    Query<Map<String, dynamic>> query = _incidents;
    if (category != null) {
      query = query.where('category', isEqualTo: category.value);
    }
    if (status != null) {
      query = query.where('status', isEqualTo: status.value);
    }
    return query
        .orderBy('createdAt', descending: true)
        .limit(feedLimit)
        .snapshots()
        .map(
          (snap) => [
            for (final doc in snap.docs) Incident.fromMap(doc.id, doc.data()),
          ],
        )
        .userFacingErrors();
  }

  @override
  Stream<List<Incident>> watchMyIncidents(String reporterUid) => _incidents
      .where('reporterId', isEqualTo: reporterUid)
      .orderBy('createdAt', descending: true)
      .limit(feedLimit)
      .snapshots()
      .map(
        (snap) => [
          for (final doc in snap.docs) Incident.fromMap(doc.id, doc.data()),
        ],
      )
      .userFacingErrors();

  @override
  Stream<Incident?> watchIncident(String id) =>
      _incidents.doc(id).snapshots().map((snap) {
        final data = snap.data();
        return data == null ? null : Incident.fromMap(snap.id, data);
      }).userFacingErrors();

  @override
  Stream<List<StatusEvent>> watchHistory(String incidentId) =>
      _history(incidentId)
          .orderBy('at')
          .snapshots()
          .map(
            (snap) => [
              for (final doc in snap.docs)
                StatusEvent.fromMap(doc.id, doc.data()),
            ],
          )
          .userFacingErrors();

  @override
  String newIncidentId() => _incidents.doc().id;

  @override
  Future<void> createIncident(Incident incident) => guardFirebase(
    () => _incidents.doc(incident.id).set({
      ...incident.copyWith(status: IncidentStatus.submitted).toMap(),
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }),
  );

  @override
  Future<void> updateIncident(Incident incident) => guardFirebase(() {
    final map = incident.toMap();
    return _incidents.doc(incident.id).update({
      // Only the fields a reporter may change (mirrors firestore.rules).
      for (final key in const [
        'title',
        'description',
        'category',
        'location',
        'photoUrls',
        'isAnonymous',
        'reporterName',
      ])
        key: map[key],
      'updatedAt': FieldValue.serverTimestamp(),
    });
  });

  @override
  Future<void> deleteIncident(String id) => guardFirebase(() async {
    final history = await _history(id).get();
    final batch = _db.batch();
    for (final doc in history.docs) {
      batch.delete(doc.reference);
    }
    batch.delete(_incidents.doc(id));
    await batch.commit();
  });

  @override
  Future<void> updateStatus({
    required String incidentId,
    required IncidentStatus from,
    required IncidentStatus to,
    required String changedBy,
    String note = '',
  }) => guardFirebase(() {
    final event = StatusEvent(
      id: '',
      from: from,
      to: to,
      note: note.trim(),
      changedBy: changedBy,
      at: DateTime.now(),
    );
    final batch = _db.batch()
      ..update(_incidents.doc(incidentId), {
        'status': to.value,
        'updatedAt': FieldValue.serverTimestamp(),
      })
      ..set(_history(incidentId).doc(), {
        ...event.toMap(),
        'at': FieldValue.serverTimestamp(),
      });
    return batch.commit();
  });
}
