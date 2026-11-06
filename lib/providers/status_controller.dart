import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/errors.dart';
import '../data/models/incident.dart';
import 'auth_providers.dart';
import 'incident_providers.dart';
import 'report_controller.dart';

/// Result of a successful status change.
typedef StatusUpdateResult = ({IncidentStatus status, bool queuedOffline});

/// Staff status changes.
///
/// The incident update and its `statusHistory` entry are written in one
/// batch by [IncidentRepository.updateStatus], so the history can never
/// disagree with the status. The transition is checked here against
/// [IncidentStatus.canMoveTo] (any other status, in either direction) and
/// again by the Security Rules.
class StatusController extends AsyncNotifier<void> {
  @override
  FutureOr<void> build() {}

  /// Moves [incident] to [to] with an optional [note]. Returns `null` on
  /// failure; the error is in [state].
  Future<StatusUpdateResult?> updateStatus(
    Incident incident,
    IncidentStatus to, {
    String note = '',
  }) async {
    if (state.isLoading) return null;
    state = const AsyncLoading();
    try {
      final profile = ref.read(currentUserProfileProvider).value;
      if (profile == null || !profile.isStaff) {
        throw const UserFacingException(
          'Only staff can change the status of a report.',
        );
      }
      if (!incident.status.canMoveTo(to)) {
        throw UserFacingException(
          'This report is already ${to.label.toLowerCase()}.',
        );
      }

      var queued = false;
      await ref
          .read(incidentRepositoryProvider)
          .updateStatus(
            incidentId: incident.id,
            from: incident.status,
            to: to,
            changedBy: profile.uid,
            note: note,
          )
          .timeout(
            ref.read(reportWriteTimeoutProvider),
            // Offline: Firestore keeps the batch and sends it later.
            onTimeout: () {
              queued = true;
            },
          );

      if (ref.mounted) state = const AsyncData(null);
      return (status: to, queuedOffline: queued);
    } catch (e, st) {
      if (ref.mounted) state = AsyncError(e, st);
      return null;
    }
  }
}

/// Auto-disposed with the sheet, so an old error is not shown next time.
final statusControllerProvider =
    AsyncNotifierProvider.autoDispose<StatusController, void>(
      StatusController.new,
    );
