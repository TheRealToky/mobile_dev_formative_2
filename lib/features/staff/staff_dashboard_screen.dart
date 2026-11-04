import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/routes.dart';
import '../../app/theme.dart';
import '../../data/models/incident.dart';
import '../../providers/dashboard_providers.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/error_view.dart';
import '../../widgets/incident_card.dart';
import '../../widgets/incident_visuals.dart';

/// Staff overview: how many reports are at each status, and the open
/// queue with the report that has waited longest at the top.
class StaffDashboardScreen extends ConsumerWidget {
  const StaffDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(dashboardStatsProvider);
    final filter = ref.watch(dashboardQueueFilterProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Dashboard')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: kMaxContentWidth),
            child: switch (stats) {
              AsyncValue(:final error?) when !stats.isLoading => ErrorView(
                error: error,
                title: 'Could not load the dashboard',
                onRetry: () => ref.invalidate(allIncidentsStreamProvider),
              ),
              AsyncValue(:final DashboardStats value) => _DashboardBody(
                stats: value,
                filter: filter,
              ),
              _ => const Center(child: CircularProgressIndicator()),
            },
          ),
        ),
      ),
    );
  }
}

class _DashboardBody extends ConsumerWidget {
  const _DashboardBody({required this.stats, required this.filter});

  final DashboardStats stats;
  final IncidentStatus? filter;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    final queue = filter == null
        ? stats.openQueue
        : stats.openQueue.where((i) => i.status == filter).toList();

    return RefreshIndicator(
      onRefresh: () => ref.refresh(allIncidentsStreamProvider.future),
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.lg, Gap.lg, 0),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${stats.openCount} open of ${stats.total} reports',
                    style: textTheme.titleMedium,
                  ),
                  const SizedBox(height: Gap.md),
                  _StatusCounts(stats: stats, selected: filter),
                  const SizedBox(height: Gap.xl),
                  Text(
                    filter == null
                        ? 'Open reports, oldest first'
                        : '${filter!.label}, oldest first',
                    style: textTheme.titleMedium,
                  ),
                  const SizedBox(height: Gap.sm),
                ],
              ),
            ),
          ),
          if (queue.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: EmptyState(
                icon: Icons.task_alt,
                message: filter == null
                    ? 'Nothing waiting. Every report is resolved or rejected.'
                    : 'No reports are ${filter!.label.toLowerCase()}.',
                actionLabel: filter == null ? null : 'Show all open',
                onAction: filter == null
                    ? null
                    : () => ref
                          .read(dashboardQueueFilterProvider.notifier)
                          .toggle(filter!),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(Gap.lg, 0, Gap.lg, Gap.xl),
              sliver: SliverList.separated(
                itemCount: queue.length,
                separatorBuilder: (_, _) => const SizedBox(height: Gap.sm),
                itemBuilder: (context, i) => IncidentCard(
                  incident: queue[i],
                  onTap: () => context.push(Routes.incident(queue[i].id)),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// One tile per status. Open statuses act as quick filters for the queue;
/// final ones (resolved, rejected) are counts only.
class _StatusCounts extends ConsumerWidget {
  const _StatusCounts({required this.stats, required this.selected});

  final DashboardStats stats;
  final IncidentStatus? selected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Two columns on phones, more when there is room.
        final columns = constraints.maxWidth >= 520 ? 5 : 2;
        final width = (constraints.maxWidth - Gap.sm * (columns - 1)) / columns;
        return Wrap(
          spacing: Gap.sm,
          runSpacing: Gap.sm,
          children: [
            for (final s in IncidentStatus.values)
              SizedBox(
                width: width,
                child: _CountTile(
                  status: s,
                  count: stats.counts[s] ?? 0,
                  selected: s == selected,
                  onTap: s.isOpen
                      ? () => ref
                            .read(dashboardQueueFilterProvider.notifier)
                            .toggle(s)
                      : null,
                ),
              ),
          ],
        );
      },
    );
  }
}

class _CountTile extends StatelessWidget {
  const _CountTile({
    required this.status,
    required this.count,
    required this.selected,
    this.onTap,
  });

  final IncidentStatus status;
  final int count;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final palette = status.palette(context);
    final textTheme = Theme.of(context).textTheme;
    return Semantics(
      button: onTap != null,
      selected: selected,
      label:
          '${status.label}: $count'
          '${onTap != null ? ', show in queue' : ''}',
      excludeSemantics: true,
      child: Material(
        color: palette.container,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.card),
          side: BorderSide(
            color: selected ? palette.foreground : Colors.transparent,
            width: 2,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(Gap.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(status.icon, size: 18, color: palette.foreground),
                    const Spacer(),
                    Text(
                      '$count',
                      style: textTheme.headlineSmall?.copyWith(
                        color: palette.foreground,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: Gap.xs),
                Text(
                  status.label,
                  style: textTheme.labelLarge?.copyWith(
                    color: palette.foreground,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
