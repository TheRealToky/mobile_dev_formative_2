import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/incident.dart';
import 'auth_providers.dart';
import 'incident_providers.dart';

/// Counts per status plus the open queue, oldest first.
@immutable
class DashboardStats {
  const DashboardStats({required this.counts, required this.openQueue});

  /// Builds the stats from every incident (any order).
  factory DashboardStats.from(List<Incident> incidents) {
    final counts = {for (final s in IncidentStatus.values) s: 0};
    for (final i in incidents) {
      counts[i.status] = counts[i.status]! + 1;
    }
    final open = incidents.where((i) => i.status.isOpen).toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return DashboardStats(
      counts: Map.unmodifiable(counts),
      openQueue: List.unmodifiable(open),
    );
  }

  final Map<IncidentStatus, int> counts;

  /// Unresolved incidents, the one waiting longest first.
  final List<Incident> openQueue;

  int get total => counts.values.fold(0, (a, b) => a + b);
  int get openCount => openQueue.length;
}

/// Every incident (no feed filters), staff only. Separate from the feed
/// stream so dashboard numbers do not change when the feed is filtered.
final allIncidentsStreamProvider = StreamProvider.autoDispose<List<Incident>>((
  ref,
) {
  if (!ref.watch(isStaffProvider)) return Stream.value(const []);
  return ref.watch(incidentRepositoryProvider).watchIncidents();
});

final dashboardStatsProvider = Provider.autoDispose<AsyncValue<DashboardStats>>(
  (ref) => ref.watch(allIncidentsStreamProvider).whenData(DashboardStats.from),
);

/// Quick filter for the dashboard queue: one open status, or `null` for
/// all open reports.
class DashboardQueueFilter extends Notifier<IncidentStatus?> {
  @override
  IncidentStatus? build() => null;

  /// Selects [status]; selecting it again goes back to all open reports.
  void toggle(IncidentStatus status) => state = state == status ? null : status;
}

final dashboardQueueFilterProvider =
    NotifierProvider<DashboardQueueFilter, IncidentStatus?>(
      DashboardQueueFilter.new,
    );
