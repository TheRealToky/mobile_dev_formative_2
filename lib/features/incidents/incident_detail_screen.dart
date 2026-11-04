import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../app/routes.dart';
import '../../app/theme.dart';
import '../../core/errors.dart';
import '../../core/utils/feedback.dart';
import '../../data/models/incident.dart';
import '../../data/models/status_event.dart';
import '../../providers/auth_providers.dart';
import '../../providers/incident_providers.dart';
import '../../providers/report_controller.dart';
import '../staff/status_update_sheet.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/error_view.dart';
import '../../widgets/incident_visuals.dart';
import '../../widgets/lifecycle_rail.dart';
import '../../widgets/status_chip.dart';
import '../../widgets/status_timeline.dart';
import 'widgets/photo_gallery.dart';

/// What the signed-in user may do with an incident. Mirrors the Security
/// Rules (the rules are the real check; this only hides buttons that would
/// fail).
typedef DetailPermissions = ({bool canEdit, bool canDelete});

DetailPermissions permissionsFor(
  Incident incident, {
  required String? uid,
  required bool isStaff,
}) {
  final ownsEditable =
      uid != null &&
      incident.reporterId == uid &&
      incident.isEditableByReporter;
  return (canEdit: ownsEditable, canDelete: ownsEditable || isStaff);
}

/// One incident: status rail, details, photos and status history, live.
class IncidentDetailScreen extends ConsumerWidget {
  const IncidentDetailScreen({super.key, required this.incidentId});

  final String incidentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(incidentByIdProvider(incidentId));
    final incident = detail.value?.incident;
    final uid = ref.watch(currentUserProfileProvider).value?.uid;
    final isStaff = ref.watch(isStaffProvider);
    final perms = incident == null
        ? (canEdit: false, canDelete: false)
        : permissionsFor(incident, uid: uid, isStaff: isStaff);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Report'),
        actions: [
          if (perms.canEdit)
            IconButton(
              tooltip: 'Edit report',
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => context.push(Routes.editIncident(incidentId)),
            ),
          if (perms.canDelete)
            IconButton(
              tooltip: 'Delete report',
              icon: const Icon(Icons.delete_outline),
              onPressed: () => _confirmDelete(context, ref, incident!),
            ),
        ],
      ),
      body: SafeArea(
        child: switch (detail) {
          AsyncValue(:final error?) when !detail.isLoading => ErrorView(
            error: error,
            title: 'Could not load this report',
            onRetry: () {
              ref.invalidate(incidentDocProvider(incidentId));
              ref.invalidate(statusHistoryProvider(incidentId));
            },
          ),
          AsyncValue(value: (incident: final Incident i, :final history)) =>
            _DetailBody(incident: i, history: history, isStaff: isStaff),
          AsyncValue(hasValue: true) => EmptyState(
            icon: Icons.delete_sweep_outlined,
            message: 'This report was deleted.',
            actionLabel: 'Back to reports',
            onAction: () => context.go(Routes.feed),
          ),
          _ => const Center(child: CircularProgressIndicator()),
        },
      ),
      // Staff action, kept in reach at the bottom while reading the report.
      bottomNavigationBar: isStaff && incident != null && incident.status.isOpen
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  Gap.lg,
                  Gap.sm,
                  Gap.lg,
                  Gap.md,
                ),
                child: FilledButton.icon(
                  icon: const Icon(Icons.swap_horiz),
                  label: const Text('Update status'),
                  onPressed: () => _updateStatus(context, incident),
                ),
              ),
            )
          : null,
    );
  }

  Future<void> _updateStatus(BuildContext context, Incident incident) async {
    final result = await showStatusUpdateSheet(context, incident);
    if (result == null || !context.mounted) return;
    showSnack(
      context,
      result.queuedOffline
          ? 'You are offline. The change is saved on this phone and will be '
                'sent when you are back online.'
          : 'Moved to ${result.status.label.toLowerCase()}',
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    Incident incident,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete this report?'),
        content: Text(
          incident.photoUrls.isEmpty
              ? 'The report and its history are removed for everyone. '
                    'This cannot be undone.'
              : 'The report, its photos and its history are removed for '
                    'everyone. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep report'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete report'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    final ok = await ref
        .read(reportControllerProvider.notifier)
        .delete(incident);
    if (!context.mounted) return;
    if (ok) {
      showSnack(context, 'Report deleted');
      if (context.canPop()) {
        context.pop();
      } else {
        context.go(Routes.feed);
      }
    } else {
      final error = ref.read(reportControllerProvider).error;
      showSnack(
        context,
        error == null ? 'Could not delete the report.' : friendlyError(error),
        isError: true,
      );
    }
  }
}

class _DetailBody extends ConsumerWidget {
  const _DetailBody({
    required this.incident,
    required this.history,
    required this.isStaff,
  });

  final Incident incident;
  final List<StatusEvent> history;
  final bool isStaff;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final date = DateFormat('d MMM yyyy, HH:mm');

    Widget heading(String text) => Padding(
      padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.xl, Gap.lg, Gap.sm),
      child: Text(text, style: textTheme.titleMedium),
    );

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: kMaxContentWidth),
        child: ListView(
          padding: const EdgeInsets.only(bottom: Gap.xxl),
          children: [
            // Status header: the rail is the first thing you read.
            Padding(
              padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.lg, Gap.lg, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  StatusChip(incident.status),
                  const SizedBox(height: Gap.md),
                  LifecycleRail(incident.status, dotSize: 14),
                  const SizedBox(height: Gap.lg),
                  Row(
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
                              style: textTheme.headlineSmall,
                            ),
                            Text(
                              incident.category.label,
                              style: textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: Gap.lg),
                  _InfoRow(
                    icon: Icons.place_outlined,
                    text: incident.location.display,
                  ),
                  _InfoRow(
                    icon: Icons.person_outline,
                    text: _ReporterLine.text(
                      incident,
                      isStaff: isStaff,
                      currentUid: ref
                          .watch(currentUserProfileProvider)
                          .value
                          ?.uid,
                      staffLookupName: isStaff && incident.isAnonymous
                          ? ref
                                .watch(
                                  reporterProfileProvider(incident.reporterId),
                                )
                                .value
                                ?.displayName
                          : null,
                    ),
                  ),
                  _InfoRow(
                    icon: Icons.schedule,
                    text: 'Reported ${date.format(incident.createdAt)}',
                  ),
                  if (incident.updatedAt.isAfter(incident.createdAt))
                    _InfoRow(
                      icon: Icons.update,
                      text: 'Updated ${date.format(incident.updatedAt)}',
                    ),
                ],
              ),
            ),
            heading('Description'),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: Gap.lg),
              child: Text(incident.description, style: textTheme.bodyLarge),
            ),
            if (incident.photoUrls.isNotEmpty) ...[
              heading('Photos'),
              PhotoGallery(urls: incident.photoUrls),
            ],
            heading('Status history'),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: Gap.lg),
              child: StatusTimeline(
                submittedAt: incident.createdAt,
                history: history,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Who reported it, respecting anonymity: students never see the name of
/// an anonymous reporter (it is not stored on the incident at all); staff
/// see it, looked up from the private `users` collection.
abstract final class _ReporterLine {
  static String text(
    Incident incident, {
    required bool isStaff,
    required String? currentUid,
    String? staffLookupName,
  }) {
    final isMine = currentUid != null && currentUid == incident.reporterId;
    if (!incident.isAnonymous) {
      return 'Reported by ${isMine ? 'you' : incident.reporterName ?? 'a student'}';
    }
    if (isMine) return 'Reported anonymously by you';
    if (isStaff && staffLookupName != null) {
      return 'Reported anonymously by $staffLookupName (visible to staff only)';
    }
    return 'Reported anonymously';
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: Gap.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: Gap.sm),
          Expanded(child: Text(text, style: theme.textTheme.bodyMedium)),
        ],
      ),
    );
  }
}
