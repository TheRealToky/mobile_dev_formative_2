import '../../data/models/incident.dart';

/// Client-side free-text search over title, description and building.
///
/// Firestore has no substring search, so category and status are filtered
/// server-side (indexed query) and this runs on the results. Case-insensitive;
/// every word in [query] must appear somewhere ("leak library" matches a
/// leaking tap in the library).
List<Incident> searchIncidents(List<Incident> incidents, String query) {
  final terms = query
      .toLowerCase()
      .split(RegExp(r'\s+'))
      .where((t) => t.isNotEmpty)
      .toList();
  if (terms.isEmpty) return incidents;

  return incidents.where((incident) {
    final haystack = [
      incident.title,
      incident.description,
      incident.location.building,
      incident.location.detail,
    ].join(' ').toLowerCase();
    return terms.every(haystack.contains);
  }).toList();
}
