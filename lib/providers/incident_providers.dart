import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/utils/incident_search.dart';
import '../data/models/app_user.dart';
import '../data/models/incident.dart';
import '../data/models/status_event.dart';
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

/// One incident, live. `null` once deleted. Auto-disposed when the detail
/// screen closes, so streams do not pile up.
final incidentDocProvider = StreamProvider.autoDispose
    .family<Incident?, String>((ref, id) {
      if (ref.watch(_signedInUidProvider) == null) return Stream.value(null);
      return ref.watch(incidentRepositoryProvider).watchIncident(id);
    });

/// The incident's status history, oldest first.
final statusHistoryProvider = StreamProvider.autoDispose
    .family<List<StatusEvent>, String>((ref, id) {
      if (ref.watch(_signedInUidProvider) == null) {
        return Stream.value(const []);
      }
      return ref.watch(incidentRepositoryProvider).watchHistory(id);
    });

/// An incident together with its status history, for the detail screen.
typedef IncidentDetail = ({Incident? incident, List<StatusEvent> history});

/// Incident plus history as one [AsyncValue]: loading until both have
/// arrived, an error if either fails. Both halves are real-time, so a staff
/// status change appears on the reporter's open detail screen immediately.
final incidentByIdProvider = Provider.autoDispose
    .family<AsyncValue<IncidentDetail>, String>((ref, id) {
      final incident = ref.watch(incidentDocProvider(id));
      final history = ref.watch(statusHistoryProvider(id));
      if (incident.hasError) {
        return AsyncError(incident.error!, incident.stackTrace!);
      }
      if (history.hasError) {
        return AsyncError(history.error!, history.stackTrace!);
      }
      if (!incident.hasValue || !history.hasValue) return const AsyncLoading();
      return AsyncData((incident: incident.value, history: history.value!));
    });

/// Reporter's profile, for staff only (rules deny it to students). Used to
/// show who filed an anonymous report.
final reporterProfileProvider = FutureProvider.autoDispose
    .family<AppUser?, String>((ref, uid) {
      if (!ref.watch(isStaffProvider)) return Future.value(null);
      return ref.watch(userRepositoryProvider).getUser(uid);
    });

/// The single source of truth for the feed: the server-filtered stream plus
/// the client-side text search. Keeps loading and error states intact.
final filteredIncidentsProvider = Provider<AsyncValue<List<Incident>>>((ref) {
  final query = ref.watch(searchQueryProvider);
  return ref
      .watch(incidentsStreamProvider)
      .whenData((incidents) => searchIncidents(incidents, query));
});
