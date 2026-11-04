import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_dev_formative_2/data/models/incident_status.dart';

void main() {
  group('IncidentStatus transitions', () {
    test('follow the documented lifecycle', () {
      expect(IncidentStatus.submitted.allowedNext, [
        IncidentStatus.underReview,
      ]);
      expect(IncidentStatus.underReview.allowedNext, [
        IncidentStatus.inProgress,
        IncidentStatus.rejected,
      ]);
      expect(IncidentStatus.inProgress.allowedNext, [IncidentStatus.resolved]);
      expect(IncidentStatus.resolved.allowedNext, isEmpty);
      expect(IncidentStatus.rejected.allowedNext, isEmpty);
    });

    test('forbid skipping steps, going back, or staying put', () {
      expect(
        IncidentStatus.submitted.canMoveTo(IncidentStatus.resolved),
        isFalse,
      );
      expect(
        IncidentStatus.submitted.canMoveTo(IncidentStatus.rejected),
        isFalse,
      );
      expect(
        IncidentStatus.inProgress.canMoveTo(IncidentStatus.underReview),
        isFalse,
      );
      for (final s in IncidentStatus.values) {
        expect(s.canMoveTo(s), isFalse, reason: '$s -> $s');
      }
    });

    test('final and open states', () {
      expect(IncidentStatus.resolved.isFinal, isTrue);
      expect(IncidentStatus.rejected.isFinal, isTrue);
      expect(IncidentStatus.submitted.isOpen, isTrue);
      expect(IncidentStatus.inProgress.isOpen, isTrue);
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
