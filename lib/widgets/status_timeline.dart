import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../app/theme.dart';
import '../data/models/incident.dart';
import '../data/models/status_event.dart';
import 'incident_visuals.dart';

/// One row of the timeline.
typedef TimelineEntry = ({
  IncidentStatus status,
  DateTime at,
  String note,
  bool byStaff,
});

/// Builds the timeline: the submission (from `createdAt`, since history
/// documents only exist for staff changes) followed by every status change,
/// oldest first, so it reads from submission to resolution.
List<TimelineEntry> buildTimeline(
  DateTime submittedAt,
  List<StatusEvent> history,
) => [
  (status: IncidentStatus.submitted, at: submittedAt, note: '', byStaff: false),
  for (final e in history)
    (status: e.to, at: e.at, note: e.note, byStaff: true),
];

/// Vertical timeline of an incident's status history.
class StatusTimeline extends StatelessWidget {
  const StatusTimeline({
    super.key,
    required this.submittedAt,
    required this.history,
  });

  final DateTime submittedAt;
  final List<StatusEvent> history;

  @override
  Widget build(BuildContext context) {
    final entries = buildTimeline(submittedAt, history);
    final theme = Theme.of(context);
    final dateFormat = DateFormat('d MMM yyyy, HH:mm');

    return Column(
      children: [
        for (var i = 0; i < entries.length; i++)
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Marker and connecting line.
                SizedBox(
                  width: 32,
                  child: Column(
                    children: [
                      Icon(
                        entries[i].status.icon,
                        size: 20,
                        color: entries[i].status.palette(context).foreground,
                      ),
                      if (i < entries.length - 1)
                        Expanded(
                          child: Container(
                            width: 2,
                            margin: const EdgeInsets.symmetric(
                              vertical: Gap.xs,
                            ),
                            color: theme.colorScheme.outlineVariant,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: Gap.sm),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: Gap.lg),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          entries[i].status.label,
                          style: theme.textTheme.titleSmall,
                        ),
                        Text(
                          '${dateFormat.format(entries[i].at)}'
                          '${entries[i].byStaff ? ', by staff' : ''}',
                          style: theme.textTheme.bodySmall,
                        ),
                        if (entries[i].note.isNotEmpty) ...[
                          const SizedBox(height: Gap.xs),
                          Text(
                            entries[i].note,
                            style: theme.textTheme.bodyMedium,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
