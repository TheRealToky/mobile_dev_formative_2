import 'package:mobile_dev_formative_2/data/models/incident.dart';

/// Test incident with sensible defaults; override what the test cares about.
Incident buildIncident({
  String id = 'inc1',
  String title = 'Leaking tap',
  String description = 'The tap in the bathroom leaks all night long.',
  IncidentCategory category = IncidentCategory.water,
  IncidentStatus status = IncidentStatus.submitted,
  String building = 'Library',
  String detail = '2nd floor',
  List<String> photoUrls = const [],
  String reporterId = 'uid1',
  String? reporterName = 'Ada',
  bool isAnonymous = false,
  DateTime? createdAt,
}) {
  final created = createdAt ?? DateTime(2026, 11, 1, 9);
  return Incident(
    id: id,
    title: title,
    description: description,
    category: category,
    status: status,
    location: IncidentLocation(building: building, detail: detail),
    photoUrls: photoUrls,
    reporterId: reporterId,
    reporterName: reporterName,
    isAnonymous: isAnonymous,
    createdAt: created,
    updatedAt: created,
  );
}
