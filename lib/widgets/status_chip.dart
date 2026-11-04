import 'package:flutter/material.dart';

import '../app/theme.dart';
import '../data/models/incident.dart';
import 'incident_visuals.dart';

/// Status shown as colour + icon + text (never colour alone).
class StatusChip extends StatelessWidget {
  const StatusChip(this.status, {super.key});

  final IncidentStatus status;

  @override
  Widget build(BuildContext context) {
    final palette = status.palette(context);
    final style = Theme.of(context).textTheme.labelMedium
        ?.copyWith(color: palette.foreground);

    return Semantics(
      label: 'Status: ${status.label}',
      excludeSemantics: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: palette.container,
          borderRadius: BorderRadius.circular(Radii.chip),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: Gap.sm,
            vertical: Gap.xs,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(status.icon, size: 16, color: palette.foreground),
              const SizedBox(width: Gap.xs),
              // Shrinks with an ellipsis on very narrow cards or large text
              // instead of overflowing; the full label stays in Semantics.
              Flexible(
                child: Text(
                  status.label,
                  style: style,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
