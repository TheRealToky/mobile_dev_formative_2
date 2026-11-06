import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_dev_formative_2/data/models/incident_status.dart';

void main() {
  group('IncidentStatus transitions', () {
    test('every other status is allowed, in lifecycle order', () {
      expect(IncidentStatus.submitted.allowedNext, [
        IncidentStatus.underReview,
        IncidentStatus.inProgress,
        IncidentStatus.resolved,
        IncidentStatus.rejected,
      ]);
      expect(IncidentStatus.resolved.allowedNext, [
        IncidentStatus.submitted,
        IncidentStatus.underReview,
        IncidentStatus.inProgress,
        IncidentStatus.rejected,
      ]);
      for (final s in IncidentStatus.values) {
        expect(s.allowedNext, hasLength(IncidentStatus.values.length - 1));
        expect(s.allowedNext, isNot(contains(s)));
      }
    });

    test('works in both directions, but never stays put', () {
      expect(
        IncidentStatus.resolved.canMoveTo(IncidentStatus.submitted),
        isTrue,
      );
      expect(
        IncidentStatus.submitted.canMoveTo(IncidentStatus.resolved),
        isTrue,
      );
      expect(
        IncidentStatus.inProgress.canMoveTo(IncidentStatus.underReview),
        isTrue,
      );
      for (final s in IncidentStatus.values) {
        expect(s.canMoveTo(s), isFalse, reason: '$s -> $s');
      }
    });

    test('suggests the next step, or reopening a closed report', () {
      expect(
        IncidentStatus.submitted.suggestedNext,
        IncidentStatus.underReview,
      );
      expect(
        IncidentStatus.underReview.suggestedNext,
        IncidentStatus.inProgress,
      );
      expect(IncidentStatus.inProgress.suggestedNext, IncidentStatus.resolved);
      expect(IncidentStatus.resolved.suggestedNext, IncidentStatus.submitted);
      expect(IncidentStatus.rejected.suggestedNext, IncidentStatus.submitted);
    });

    test('closed and open states', () {
      expect(IncidentStatus.resolved.isClosed, isTrue);
      expect(IncidentStatus.rejected.isClosed, isTrue);
      expect(IncidentStatus.submitted.isOpen, isTrue);
      expect(IncidentStatus.inProgress.isOpen, isTrue);
    });

    test('knows which moves go backwards', () {
      expect(
        IncidentStatus.submitted.isBackwardFrom(IncidentStatus.resolved),
        isTrue,
      );
      expect(
        IncidentStatus.underReview.isBackwardFrom(IncidentStatus.inProgress),
        isTrue,
      );
      expect(
        IncidentStatus.inProgress.isBackwardFrom(IncidentStatus.underReview),
        isFalse,
      );
      expect(
        IncidentStatus.rejected.isBackwardFrom(IncidentStatus.resolved),
        isFalse,
      );
    });
  });

  group('IncidentStatus values', () {
    test('round-trip through the stored string', () {
      for (final s in IncidentStatus.values) {
        expect(IncidentStatus.fromValue(s.value), s);
      }
      expect(IncidentStatus.underReview.value, 'under_review');
    });

    test('unknown values fall back to submitted', () {
      expect(IncidentStatus.fromValue('closed'), IncidentStatus.submitted);
      expect(IncidentStatus.fromValue(null), IncidentStatus.submitted);
    });
  });
}
