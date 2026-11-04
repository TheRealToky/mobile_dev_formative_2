import 'package:flutter/foundation.dart';

import 'incident.dart';

/// A photo in the report form: either already uploaded (editing) or a local
/// file the user just picked.
sealed class DraftPhoto {
  const DraftPhoto();
}

/// Already in Storage; kept as its download URL.
final class RemotePhoto extends DraftPhoto {
  const RemotePhoto(this.url);
  final String url;

  @override
  bool operator ==(Object other) => other is RemotePhoto && other.url == url;
  @override
  int get hashCode => url.hashCode;
}

/// Picked on this device; uploaded (after compression) on submit.
final class LocalPhoto extends DraftPhoto {
  const LocalPhoto(this.path);
  final String path;

  @override
  bool operator ==(Object other) => other is LocalPhoto && other.path == path;
  @override
  int get hashCode => path.hashCode;
}

/// What the user typed into the report form, before it becomes an
/// [Incident]. Text is trimmed when converted.
@immutable
class ReportDraft {
  const ReportDraft({
    required this.title,
    required this.description,
    required this.category,
    required this.building,
    this.locationDetail = '',
    this.isAnonymous = false,
    this.photos = const [],
  });

  /// Pre-fills the form when a reporter edits their incident.
  factory ReportDraft.fromIncident(Incident incident) => ReportDraft(
    title: incident.title,
    description: incident.description,
    category: incident.category,
    building: incident.location.building,
    locationDetail: incident.location.detail,
    isAnonymous: incident.isAnonymous,
    photos: [for (final url in incident.photoUrls) RemotePhoto(url)],
  );

  final String title;
  final String description;
  final IncidentCategory category;
  final String building;
  final String locationDetail;
  final bool isAnonymous;
  final List<DraftPhoto> photos;

  Iterable<LocalPhoto> get localPhotos => photos.whereType<LocalPhoto>();
  Iterable<String> get keptUrls =>
      photos.whereType<RemotePhoto>().map((p) => p.url);

  /// Builds the incident to save. [reporterName] is dropped for anonymous
  /// reports, so the name is never written to the document.
  Incident toIncident({
    required String id,
    required String reporterId,
    required String reporterName,
    required List<String> photoUrls,
    IncidentStatus status = IncidentStatus.submitted,
    DateTime? createdAt,
  }) {
    final now = DateTime.now();
    return Incident(
      id: id,
      title: title.trim(),
      description: description.trim(),
      category: category,
      status: status,
      location: IncidentLocation(
        building: building,
        detail: locationDetail.trim(),
      ),
      photoUrls: photoUrls,
      reporterId: reporterId,
      reporterName: isAnonymous ? null : reporterName,
      isAnonymous: isAnonymous,
      createdAt: createdAt ?? now,
      updatedAt: now,
    );
  }
}
