import 'package:flutter/material.dart';

import '../app/theme.dart';
import '../data/models/incident.dart';

/// Icons and colours for statuses and categories, from DESIGN_NOTES.md.
///
/// Exhaustive switches: adding a status or category without a visual is a
/// compile error.
extension IncidentStatusVisuals on IncidentStatus {
  IconData get icon => switch (this) {
    IncidentStatus.submitted => Icons.outbox_outlined,
    IncidentStatus.underReview => Icons.visibility_outlined,
    IncidentStatus.inProgress => Icons.construction,
    IncidentStatus.resolved => Icons.check_circle_outline,
    IncidentStatus.rejected => Icons.block,
  };

  StatusPalette palette(BuildContext context) {
    final colors = Theme.of(context).extension<StatusColors>()!;
    return switch (this) {
      IncidentStatus.submitted => colors.submitted,
      IncidentStatus.underReview => colors.underReview,
      IncidentStatus.inProgress => colors.inProgress,
      IncidentStatus.resolved => colors.resolved,
      IncidentStatus.rejected => colors.rejected,
    };
  }
}

/// Icon for each category (DESIGN_NOTES.md).
extension IncidentCategoryVisuals on IncidentCategory {
  IconData get icon => switch (this) {
    IncidentCategory.water => Icons.water_drop_outlined,
    IncidentCategory.electricity => Icons.bolt,
    IncidentCategory.facilities => Icons.apartment,
    IncidentCategory.furniture => Icons.chair_outlined,
    IncidentCategory.sanitation => Icons.cleaning_services_outlined,
    IncidentCategory.safety => Icons.health_and_safety_outlined,
    IncidentCategory.other => Icons.more_horiz,
  };
}

/// Category icon in a neutral square, so category never competes with status
/// for colour.
class CategoryIcon extends StatelessWidget {
  const CategoryIcon(this.category, {super.key, this.size = 44});

  final IncidentCategory category;
  final double size;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      label: '${category.label} issue',
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(Radii.chip),
        ),
        child: Icon(
          category.icon,
          size: size * 0.5,
          color: scheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
