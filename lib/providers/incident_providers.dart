import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/utils/incident_search.dart';
import '../data/models/incident.dart';
import '../data/repositories/incident_repository.dart';
import 'auth_providers.dart';
import 'filter_providers.dart';
import 'firebase_providers.dart';

final incidentRepositoryProvider = Provider<IncidentRepository>(
  (ref) => FirestoreIncidentRepository(ref.watch(firestoreProvider)),
);

/// uid of the signed-in user, or `null`. Incident streams depend on it so
/// they are torn down on logout (rules would deny them anyway) and restarted
/// for the next user.
final _signedInUidProvider = Provider<String?>(
  (ref) => ref.watch(authStateProvider.select((a) => a.value?.uid)),
);

/// Real-time incidents for the feed, filtered server-side by the selected
/// category and status. Re-subscribes whenever a filter changes.
final incidentsStreamProvider = StreamProvider<List<Incident>>((ref) {
  if (ref.watch(_signedInUidProvider) == null) return Stream.value(const []);
  return ref
      .watch(incidentRepositoryProvider)
      .watchIncidents(
        category: ref.watch(categoryFilterProvider),
        status: ref.watch(statusFilterProvider),
      );
});

/// The single source of truth for the feed: the server-filtered stream plus
/// the client-side text search. Keeps loading and error states intact.
final filteredIncidentsProvider = Provider<AsyncValue<List<Incident>>>((ref) {
  final query = ref.watch(searchQueryProvider);
  return ref
      .watch(incidentsStreamProvider)
      .whenData((incidents) => searchIncidents(incidents, query));
});
