import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/routes.dart';
import '../../app/theme.dart';
import '../../data/models/incident.dart';
import '../../providers/filter_providers.dart';
import '../../providers/incident_providers.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/error_view.dart';
import '../../widgets/incident_card.dart';
import 'widgets/feed_filters.dart';

/// Browse all reports: search, category/status filters, real-time list.
class FeedScreen extends ConsumerWidget {
  const FeedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final incidents = ref.watch(filteredIncidentsProvider);
    final hasFilters = ref.watch(hasActiveFiltersProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Reports'),
        actions: [
          if (hasFilters)
            TextButton.icon(
              onPressed: () => clearAllFilters(ref),
              icon: const Icon(Icons.filter_alt_off_outlined),
              label: const Text('Clear filters'),
            ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: kMaxContentWidth),
          child: Column(
            children: [
              const SizedBox(height: Gap.sm),
              const FeedFilters(),
              // Thin bar while a filter change reloads, keeping the old list.
              SizedBox(
                height: 4,
                child: incidents.isLoading && incidents.hasValue
                    ? const LinearProgressIndicator()
                    : null,
              ),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () => ref.refresh(incidentsStreamProvider.future),
                  child: _FeedBody(
                    incidents: incidents,
                    hasFilters: hasFilters,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FeedBody extends ConsumerWidget {
  const _FeedBody({required this.incidents, required this.hasFilters});

  final AsyncValue<List<Incident>> incidents;
  final bool hasFilters;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Each branch is scrollable so pull-to-refresh works in every state.
    // Show the error unless a reload is still in progress over a list we
    // already have (then keep the list and the thin progress bar).
    if (incidents.hasError && !(incidents.isLoading && incidents.hasValue)) {
      return _scrollableCentered(
        ErrorView(
          error: incidents.error!,
          onRetry: () => ref.invalidate(incidentsStreamProvider),
        ),
      );
    }
    final list = incidents.value;
    if (list == null) {
      return ListView.separated(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.all(Gap.lg),
        itemCount: 4,
        separatorBuilder: (_, _) => const SizedBox(height: Gap.sm),
        itemBuilder: (_, _) => const IncidentCardSkeleton(),
      );
    }
    if (list.isEmpty) {
      return _scrollableCentered(
        hasFilters
            ? EmptyState(
                icon: Icons.search_off,
                message: 'No reports match these filters.',
                actionLabel: 'Clear filters',
                onAction: () => clearAllFilters(ref),
              )
            : EmptyState(
                icon: Icons.task_alt,
                message: 'No reports yet. Spotted a problem on campus?',
                actionLabel: 'Report an issue',
                onAction: () => context.go(Routes.report),
              ),
      );
    }

    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.sm, Gap.lg, Gap.xl),
      itemCount: list.length + 1,
      separatorBuilder: (_, _) => const SizedBox(height: Gap.sm),
      itemBuilder: (context, index) {
        if (index == 0) {
          return Text(
            list.length == 1 ? '1 report' : '${list.length} reports',
            style: Theme.of(context).textTheme.bodySmall,
          );
        }
        final incident = list[index - 1];
        return IncidentCard(
          incident: incident,
          onTap: () => context.push(Routes.incident(incident.id)),
        );
      },
    );
  }

  Widget _scrollableCentered(Widget child) => LayoutBuilder(
    builder: (context, constraints) => SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: constraints.maxHeight),
        child: child,
      ),
    ),
  );
}
