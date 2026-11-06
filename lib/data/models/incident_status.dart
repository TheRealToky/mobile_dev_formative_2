/// Where an incident is in its lifecycle.
///
/// ```
/// submitted -> under_review -> in_progress -> resolved
///                  \-> rejected
/// ```
///
/// That is the usual path, but staff may move a report between any two
/// statuses, in both directions: for example reopen a resolved report as
/// submitted, or close a submitted duplicate as resolved.
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

  /// The statuses staff may move an incident to from this one: every other
  /// status, forwards or backwards, in lifecycle order.
  ///
  /// This is the single source of truth for transitions (mirrored in
  /// `firestore.rules`, `validTransition()`); the staff update sheet only
  /// offers these options.
  List<IncidentStatus> get allowedNext => [
    for (final s in values)
      if (s != this) s,
  ];

  /// Whether moving from this status to [next] is allowed (anything but
  /// staying put).
  bool canMoveTo(IncidentStatus next) => next != this;

  /// The option pre-selected in the staff update sheet: the next step on the
  /// usual path, or back to [submitted] for a closed report (reopening).
  IncidentStatus get suggestedNext => switch (this) {
    IncidentStatus.submitted => IncidentStatus.underReview,
    IncidentStatus.underReview => IncidentStatus.inProgress,
    IncidentStatus.inProgress => IncidentStatus.resolved,
    IncidentStatus.resolved ||
    IncidentStatus.rejected => IncidentStatus.submitted,
  };

  /// Resolved or rejected: staff are done with it unless they reopen it.
  bool get isClosed =>
      this == IncidentStatus.resolved || this == IncidentStatus.rejected;

  /// True while staff still have work to do (dashboard "unresolved" queue).
  bool get isOpen => !isClosed;

  /// Whether moving here from [from] goes back along the usual path, for
  /// example in progress -> submitted, or resolved -> in progress.
  bool isBackwardFrom(IncidentStatus from) =>
      isOpen && (from.isClosed || index < from.index);

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
