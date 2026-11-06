import 'package:flutter/foundation.dart';

import 'firestore_converters.dart';
import 'incident_category.dart';
import 'incident_status.dart';

export 'incident_category.dart';
export 'incident_status.dart';

/// Where on campus the incident is: a building from the fixed list plus a
/// free-text detail ("2nd floor, room B2-04").
@immutable
class IncidentLocation {
  const IncidentLocation({required this.building, this.detail = ''});

  final String building;
  final String detail;

  /// "Library, 2nd floor" or just "Library" when there is no detail.
  String get display => detail.isEmpty ? building : '$building, $detail';

  factory IncidentLocation.fromMap(Object? map) => switch (map) {
    Map<Object?, Object?> m => IncidentLocation(
      building: stringFrom(m['building'], orElse: 'Unknown'),
      detail: stringFrom(m['detail']),
    ),
    _ => const IncidentLocation(building: 'Unknown'),
  };

  Map<String, dynamic> toMap() => {'building': building, 'detail': detail};

  @override
  bool operator ==(Object other) =>
      other is IncidentLocation &&
      other.building == building &&
      other.detail == detail;

  @override
  int get hashCode => Object.hash(building, detail);
}

/// An incident report, stored at `incidents/{id}`.
@immutable
class Incident {
  const Incident({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.status,
    required this.location,
    required this.reporterId,
    required this.isAnonymous,
    required this.createdAt,
    required this.updatedAt,
    this.reporterName,
    this.photoUrls = const [],
  });

  final String id;
  final String title;
  final String description;
  final IncidentCategory category;
  final IncidentStatus status;
  final IncidentLocation location;

  /// Photo references: Firestore document paths
  /// (`incidents/{id}/photos/{photoId}`), or `https://` URLs on reports
  /// made while photos were in Cloud Storage. Shown with `IncidentPhoto`.
  final List<String> photoUrls;
  final String reporterId;

  /// Reporter's display name, copied at submission time so the feed does not
  /// need to read other users' profiles. `null` for anonymous reports: the
  /// name is never written, and staff look it up from `users/{reporterId}`.
  final String? reporterName;
  final bool isAnonymous;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// Students may only edit or delete while staff have not started on it.
  bool get isEditableByReporter => status == IncidentStatus.submitted;

  /// Builds an incident from a Firestore document map. [id] is the doc id.
  factory Incident.fromMap(String id, Map<String, dynamic> map) {
    final created = dateFromFirestore(map['createdAt']);
    return Incident(
      id: id,
      title: stringFrom(map['title']),
      description: stringFrom(map['description']),
      category: IncidentCategory.fromValue(map['category']),
      status: IncidentStatus.fromValue(map['status']),
      location: IncidentLocation.fromMap(map['location']),
      photoUrls: switch (map['photoUrls']) {
        List<Object?> list => list.whereType<String>().toList(growable: false),
        _ => const [],
      },
      reporterId: stringFrom(map['reporterId']),
      reporterName: map['reporterName'] as String?,
      isAnonymous: map['isAnonymous'] == true,
      createdAt: created,
      updatedAt: dateFromFirestore(map['updatedAt'], fallback: created),
    );
  }

  /// Document fields. `createdAt`/`updatedAt` are added by the repository as
  /// server timestamps, so the client clock is never trusted.
  Map<String, dynamic> toMap() => {
    'title': title,
    'description': description,
    'category': category.value,
    'status': status.value,
    'location': location.toMap(),
    'photoUrls': photoUrls,
    'reporterId': reporterId,
    'reporterName': isAnonymous ? null : reporterName,
    'isAnonymous': isAnonymous,
  };

  Incident copyWith({
    String? title,
    String? description,
    IncidentCategory? category,
    IncidentStatus? status,
    IncidentLocation? location,
    List<String>? photoUrls,
    bool? isAnonymous,
    DateTime? updatedAt,
  }) => Incident(
    id: id,
    title: title ?? this.title,
    description: description ?? this.description,
    category: category ?? this.category,
    status: status ?? this.status,
    location: location ?? this.location,
    photoUrls: photoUrls ?? this.photoUrls,
    reporterId: reporterId,
    reporterName: reporterName,
    isAnonymous: isAnonymous ?? this.isAnonymous,
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );

  @override
  bool operator ==(Object other) =>
      other is Incident &&
      other.id == id &&
      other.title == title &&
      other.description == description &&
      other.category == category &&
      other.status == status &&
      other.location == location &&
      listEquals(other.photoUrls, photoUrls) &&
      other.reporterId == reporterId &&
      other.reporterName == reporterName &&
      other.isAnonymous == isAnonymous &&
      other.createdAt == createdAt &&
      other.updatedAt == updatedAt;

  @override
  int get hashCode => Object.hash(
    id,
    title,
    description,
    category,
    status,
    location,
    Object.hashAll(photoUrls),
    reporterId,
    reporterName,
    isAnonymous,
    createdAt,
    updatedAt,
  );
}
