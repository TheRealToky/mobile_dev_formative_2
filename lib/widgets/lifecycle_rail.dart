import 'package:flutter/material.dart';

import '../app/theme.dart';
import '../data/models/incident.dart';
import 'incident_visuals.dart';

/// Four-step progress rail: Submitted -> Under review -> In progress ->
/// Resolved, filled up to the current step in the status colour.
///
/// A rejected report fills up to "Under review" and the rest of the rail is
/// drawn broken (dashed), showing it left the normal path. This is the app's
/// signature element (DESIGN_NOTES.md section 2).
class LifecycleRail extends StatelessWidget {
  const LifecycleRail(this.status, {super.key, this.dotSize = 10});

  final IncidentStatus status;
  final double dotSize;

  static const _steps = 4;

  @override
  Widget build(BuildContext context) {
    final palette = status.palette(context);
    final idle = Theme.of(context).colorScheme.outlineVariant;
    final current = status.railStep;
    final rejected = status == IncidentStatus.rejected;

    Widget dot(int i) {
      final reached = i <= current;
      return Container(
        width: dotSize,
        height: dotSize,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: reached ? palette.foreground : Colors.transparent,
          border: Border.all(
            color: reached ? palette.foreground : idle,
            width: 2,
          ),
        ),
      );
    }

    Widget segment(int i) {
      final reached = i < current;
      final broken = rejected && i >= current;
      return Expanded(
        child: broken
            ? _DashedLine(color: idle)
            : Container(height: 2, color: reached ? palette.foreground : idle),
      );
    }

    final progress = rejected
        ? 'Rejected after review'
        : 'Step ${current + 1} of $_steps, ${status.label}';

    return Semantics(
      label: 'Progress: $progress',
      excludeSemantics: true,
      child: Row(
        children: [
          for (var i = 0; i < _steps; i++) ...[
            dot(i),
            if (i < _steps - 1) segment(i),
          ],
        ],
      ),
    );
  }
}

class _DashedLine extends StatelessWidget {
  const _DashedLine({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const dash = 4.0;
        final count = (constraints.maxWidth / (dash * 2)).floor().clamp(1, 99);
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            for (var i = 0; i < count; i++)
              Container(width: dash, height: 2, color: color),
          ],
        );
      },
    );
  }
}

/// Width-limited rail used inside cards so it never stretches too far.
class CompactLifecycleRail extends StatelessWidget {
  const CompactLifecycleRail(this.status, {super.key});

  final IncidentStatus status;

  @override
  Widget build(BuildContext context) => ConstrainedBox(
    constraints: const BoxConstraints(maxWidth: 120),
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: Gap.xs),
      child: LifecycleRail(status, dotSize: 8),
    ),
  );
}
