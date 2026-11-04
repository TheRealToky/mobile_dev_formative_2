import 'package:flutter/foundation.dart';

import 'firestore_converters.dart';
import 'incident_status.dart';

/// One immutable audit entry at `incidents/{id}/statusHistory/{eventId}`.
///
/// Created only by staff, together with the status change, in one batch.
/// Security Rules forbid updating or deleting it.
@immutable
class StatusEvent {
  const StatusEvent({
    required this.id,
    required this.from,
    required this.to,
    required this.changedBy,
    required this.at,
    this.note = '',
  });

  final String id;
  final IncidentStatus from;
  final IncidentStatus to;
  final String note;

  /// uid of the staff member who made the change.
  final String changedBy;
  final DateTime at;

  factory StatusEvent.fromMap(String id, Map<String, dynamic> map) =>
      StatusEvent(
        id: id,
        from: IncidentStatus.fromValue(map['from']),
        to: IncidentStatus.fromValue(map['to']),
        note: stringFrom(map['note']),
        changedBy: stringFrom(map['changedBy']),
        at: dateFromFirestore(map['at']),
      );

  /// Fields written by staff. `at` is added as a server timestamp.
  Map<String, dynamic> toMap() => {
    'from': from.value,
    'to': to.value,
    'note': note,
    'changedBy': changedBy,
  };

  @override
  bool operator ==(Object other) =>
      other is StatusEvent &&
      other.id == id &&
      other.from == from &&
      other.to == to &&
      other.note == note &&
      other.changedBy == changedBy &&
      other.at == at;

  @override
  int get hashCode => Object.hash(id, from, to, note, changedBy, at);
}
