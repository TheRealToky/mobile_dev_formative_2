import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_dev_formative_2/core/utils/incident_search.dart';
import 'package:mobile_dev_formative_2/data/models/incident.dart';

Incident _incident(
  String id,
  String title,
  String description,
  String building, {
  String detail = '',
}) => Incident(
  id: id,
  title: title,
  description: description,
  category: IncidentCategory.other,
  status: IncidentStatus.submitted,
  location: IncidentLocation(building: building, detail: detail),
  reporterId: 'u',
  isAnonymous: false,
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

void main() {
  final incidents = [
    _incident('1', 'Leaking tap', 'Water everywhere', 'Library'),
    _incident('2', 'Power cut', 'No electricity since 8am', 'Cafeteria'),
    _incident(
      '3',
      'Broken chair',
      'Leg snapped',
      'Main building',
      detail: 'Room 12',
    ),
  ];

  List<String> ids(List<Incident> list) => list.map((i) => i.id).toList();

  test('empty or blank query returns everything', () {
    expect(ids(searchIncidents(incidents, '')), ['1', '2', '3']);
    expect(ids(searchIncidents(incidents, '   ')), ['1', '2', '3']);
  });

  test('matches title, description, building and detail, case-insensitive', () {
    expect(ids(searchIncidents(incidents, 'TAP')), ['1']);
    expect(ids(searchIncidents(incidents, 'electricity')), ['2']);
    expect(ids(searchIncidents(incidents, 'cafeteria')), ['2']);
    expect(ids(searchIncidents(incidents, 'room 12')), ['3']);
  });

  test('every word must match', () {
    expect(ids(searchIncidents(incidents, 'leak library')), ['1']);
    expect(ids(searchIncidents(incidents, 'leak cafeteria')), isEmpty);
  });
}
