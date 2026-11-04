/// Kind of campus issue. [value] is what Firestore stores; it is mirrored in
/// the `category in [...]` check in `firestore.rules`.
enum IncidentCategory {
  water('water', 'Water'),
  electricity('electricity', 'Electricity'),
  facilities('facilities', 'Facilities'),
  furniture('furniture', 'Furniture'),
  sanitation('sanitation', 'Sanitation'),
  safety('safety', 'Safety'),
  other('other', 'Other');

  const IncidentCategory(this.value, this.label);

  /// Stored string, for example `'water'`.
  final String value;

  /// Human-readable label shown in the UI.
  final String label;

  /// Parses a stored value; unknown values fall back to [other] so a bad
  /// document never crashes the feed.
  static IncidentCategory fromValue(Object? value) => values.firstWhere(
    (c) => c.value == value,
    orElse: () => IncidentCategory.other,
  );
}
