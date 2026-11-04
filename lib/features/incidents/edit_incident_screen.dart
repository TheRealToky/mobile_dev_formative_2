import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/auth_providers.dart';
import '../../providers/incident_providers.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/error_view.dart';
import 'report_form_screen.dart';

/// Loads an incident and opens the report form in edit mode, but only for
/// its reporter while it is still "Submitted" (the rules enforce the same).
/// A deep link to someone else's report, or one staff already picked up,
/// gets an explanation instead of a form that would fail on save.
class EditIncidentScreen extends ConsumerWidget {
  const EditIncidentScreen({super.key, required this.incidentId});

  final String incidentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final incident = ref.watch(incidentDocProvider(incidentId));
    final uid = ref.watch(currentUserProfileProvider).value?.uid;

    Widget message(IconData icon, String text) => Scaffold(
      appBar: AppBar(title: const Text('Edit report')),
      body: EmptyState(
        icon: icon,
        message: text,
        actionLabel: 'Back',
        onAction: () => context.pop(),
      ),
    );

    return switch (incident) {
      AsyncValue(:final error?) when !incident.isLoading => Scaffold(
        appBar: AppBar(title: const Text('Edit report')),
        body: ErrorView(
          error: error,
          title: 'Could not load this report',
          onRetry: () => ref.invalidate(incidentDocProvider(incidentId)),
        ),
      ),
      AsyncValue(hasValue: true, :final value) => switch (value) {
        null => message(
          Icons.delete_sweep_outlined,
          'This report was deleted.',
        ),
        final i when i.reporterId != uid => message(
          Icons.lock_outline,
          'Only the person who reported this can edit it.',
        ),
        final i when !i.isEditableByReporter => message(
          Icons.lock_clock_outlined,
          'Staff have started on this report, so it can no longer be edited.',
        ),
        // Keyed by id so the form is not rebuilt with stale values when
        // the live document updates while editing.
        final i => ReportFormScreen(key: ValueKey(i.id), initial: i),
      },
      _ => const Scaffold(body: Center(child: CircularProgressIndicator())),
    };
  }
}
