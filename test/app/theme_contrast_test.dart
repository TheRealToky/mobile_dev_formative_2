import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_dev_formative_2/app/theme.dart';

/// WCAG 2.x contrast ratio between two opaque colours.
double contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

void main() {
  for (final (name, theme) in [
    ('light', AppTheme.light(useGoogleFont: false)),
    ('dark', AppTheme.dark(useGoogleFont: false)),
  ]) {
    group('$name theme', () {
      final status = theme.extension<StatusColors>()!;
      final scheme = theme.colorScheme;
      final palettes = {
        'submitted': status.submitted,
        'underReview': status.underReview,
        'inProgress': status.inProgress,
        'resolved': status.resolved,
        'rejected': status.rejected,
      };

      palettes.forEach((key, p) {
        test('$key chip text meets WCAG AA (4.5:1)', () {
          expect(contrast(p.foreground, p.container), greaterThan(4.5));
        });
        test('$key icon/rail on the page meets 3:1', () {
          expect(contrast(p.foreground, scheme.surface), greaterThan(3));
        });
      });

      test('body text on surface meets AA', () {
        expect(contrast(scheme.onSurface, scheme.surface), greaterThan(4.5));
        expect(
          contrast(scheme.onSurfaceVariant, scheme.surface),
          greaterThan(4.5),
        );
      });
    });
  }
}
