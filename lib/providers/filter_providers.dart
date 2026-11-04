import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/incident.dart';

/// Feed filter state.
///
/// These are plain (not auto-disposed) providers, so the filters survive
/// opening an incident and coming back, and switching tabs.

/// Free-text search, applied client-side by `filteredIncidentsProvider`.
class SearchQuery extends Notifier<String> {
  @override
  String build() => '';

  void set(String query) => state = query;
  void clear() => state = '';
}

final searchQueryProvider = NotifierProvider<SearchQuery, String>(
  SearchQuery.new,
);

/// Selected category, or `null` for all. Applied server-side.
class CategoryFilter extends Notifier<IncidentCategory?> {
  @override
  IncidentCategory? build() => null;

  /// Selecting the active category again clears it (chip toggle).
  void toggle(IncidentCategory category) =>
      state = state == category ? null : category;
  void clear() => state = null;
}

final categoryFilterProvider =
    NotifierProvider<CategoryFilter, IncidentCategory?>(CategoryFilter.new);

/// Selected status, or `null` for all. Applied server-side.
class StatusFilter extends Notifier<IncidentStatus?> {
  @override
  IncidentStatus? build() => null;

  void toggle(IncidentStatus status) => state = state == status ? null : status;
  void clear() => state = null;
}

final statusFilterProvider = NotifierProvider<StatusFilter, IncidentStatus?>(
  StatusFilter.new,
);

/// True when any filter or search is active (shows "Clear filters").
final hasActiveFiltersProvider = Provider<bool>(
  (ref) =>
      ref.watch(searchQueryProvider).trim().isNotEmpty ||
      ref.watch(categoryFilterProvider) != null ||
      ref.watch(statusFilterProvider) != null,
);

/// Resets search, category and status in one go.
void clearAllFilters(WidgetRef ref) {
  ref.read(searchQueryProvider.notifier).clear();
  ref.read(categoryFilterProvider.notifier).clear();
  ref.read(statusFilterProvider.notifier).clear();
}
