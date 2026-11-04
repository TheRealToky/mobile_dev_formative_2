/// Where an incident is in its lifecycle.
///
/// ```
/// submitted -> under_review -> in_progress -> resolved
///                  \-> rejected
/// ```
///
/// [value] is what Firestore stores; mirrored in `firestore.rules`.
enum IncidentStatus {
  submitted('submitted', 'Submitted'),
  underReview('under_review', 'Under review'),
  inProgress('in_progress', 'In progress'),
  resolved('resolved', 'Resolved'),
  rejected('rejected', 'Rejected');

  const IncidentStatus(this.value, this.label);

  /// Stored string, for example `'under_review'`.
  final String value;

  /// Human-readable label shown in the UI.
  final String label;

  /// Parses a stored value; unknown values fall back to [submitted].
  static IncidentStatus fromValue(Object? value) => values.firstWhere(
    (s) => s.value == value,
    orElse: () => IncidentStatus.submitted,
  );

  /// The statuses staff may move an incident to from this one.
  ///
  /// This is the single source of truth for the lifecycle; the staff update
  /// sheet only offers these options.
  List<IncidentStatus> get allowedNext => switch (this) {
    IncidentStatus.submitted => const [IncidentStatus.underReview],
    IncidentStatus.underReview => const [
      IncidentStatus.inProgress,
      IncidentStatus.rejected,
    ],
    IncidentStatus.inProgress => const [IncidentStatus.resolved],
    IncidentStatus.resolved => const [],
    IncidentStatus.rejected => const [],
  };

  /// Whether moving from this status to [next] is allowed.
  bool canMoveTo(IncidentStatus next) => allowedNext.contains(next);

  /// True once no further transitions are possible.
  bool get isFinal => allowedNext.isEmpty;

  /// True while staff still have work to do (dashboard "unresolved" queue).
  bool get isOpen => !isFinal;

  /// Position on the four-step lifecycle rail (0-3). Rejected sits on the
  /// "under review" step because that is where it left the main path.
  int get railStep => switch (this) {
    IncidentStatus.submitted => 0,
    IncidentStatus.underReview => 1,
    IncidentStatus.inProgress => 2,
    IncidentStatus.resolved => 3,
    IncidentStatus.rejected => 1,
  };
}
