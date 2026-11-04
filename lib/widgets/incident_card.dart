import 'package:flutter/material.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../app/theme.dart';
import '../data/models/incident.dart';
import 'incident_visuals.dart';
import 'lifecycle_rail.dart';
import 'status_chip.dart';

/// One incident in a list, styled as a flat, outlined "ticket": category icon,
/// title, location, lifecycle rail with status chip, and relative time.
class IncidentCard extends StatelessWidget {
  const IncidentCard({super.key, required this.incident, this.onTap, this.now});

  final Incident incident;
  final VoidCallback? onTap;

  /// Reference time for "2 h ago"; injectable so tests are deterministic.
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodyMedium?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final age = timeago.format(incident.createdAt, clock: now);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: Gap.lg,
            vertical: Gap.md,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CategoryIcon(incident.category),
              const SizedBox(width: Gap.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      incident.title,
                      style: theme.textTheme.titleMedium,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: Gap.xs),
                    Row(
                      children: [
                        Icon(
                          Icons.place_outlined,
                          size: 16,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: Gap.xs),
                        Expanded(
                          child: Text(
                            incident.location.display,
                            style: muted,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: Gap.sm),
                    Wrap(
                      spacing: Gap.md,
                      runSpacing: Gap.sm,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        CompactLifecycleRail(incident.status),
                        StatusChip(incident.status),
                        Text(age, style: theme.textTheme.bodySmall),
                      ],
                    ),
                  ],
                ),
              ),
              if (incident.photoUrls.isNotEmpty) ...[
                const SizedBox(width: Gap.sm),
                Semantics(
                  label: '${incident.photoUrls.length} photos',
                  child: Icon(
                    Icons.photo_outlined,
                    size: 18,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Static placeholder shaped like an [IncidentCard], shown while loading.
class IncidentCardSkeleton extends StatelessWidget {
  const IncidentCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final block = Theme.of(context).colorScheme.surfaceContainerHighest;
    Widget bar(double width, double height) => Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: block,
        borderRadius: BorderRadius.circular(4),
      ),
    );

    return ExcludeSemantics(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: Gap.lg,
            vertical: Gap.md,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              bar(44, 44),
              const SizedBox(width: Gap.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    bar(double.infinity, 16),
                    const SizedBox(height: Gap.sm),
                    bar(140, 12),
                    const SizedBox(height: Gap.md),
                    bar(200, 20),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
