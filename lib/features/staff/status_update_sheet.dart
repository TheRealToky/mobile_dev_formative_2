import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../../core/constants.dart';
import '../../core/errors.dart';
import '../../core/validators.dart';
import '../../data/models/incident.dart';
import '../../providers/status_controller.dart';
import '../../widgets/incident_visuals.dart';
import '../../widgets/loading_button.dart';
import '../../widgets/status_chip.dart';

/// Opens the staff status sheet for [incident]. Completes with the result
/// once saved, or `null` if the sheet was dismissed.
Future<StatusUpdateResult?> showStatusUpdateSheet(
  BuildContext context,
  Incident incident,
) => showModalBottomSheet<StatusUpdateResult>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  useSafeArea: true,
  builder: (_) => StatusUpdateSheet(incident: incident),
);

/// Lets staff move an incident to one of its allowed next statuses, with a
/// note the reporter will see in the timeline.
class StatusUpdateSheet extends ConsumerStatefulWidget {
  const StatusUpdateSheet({super.key, required this.incident});

  final Incident incident;

  @override
  ConsumerState<StatusUpdateSheet> createState() => _StatusUpdateSheetState();
}

class _StatusUpdateSheetState extends ConsumerState<StatusUpdateSheet> {
  final _formKey = GlobalKey<FormState>();
  final _note = TextEditingController();

  /// Only the lifecycle's allowed next steps are offered, so an invalid
  /// transition cannot even be chosen.
  late final List<IncidentStatus> _options = widget.incident.status.allowedNext;
  late IncidentStatus _selected = _options.first;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final result = await ref
        .read(statusControllerProvider.notifier)
        .updateStatus(widget.incident, _selected, note: _note.text);
    if (result != null && mounted) Navigator.of(context).pop(result);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(statusControllerProvider);
    final busy = state.isLoading;
    final theme = Theme.of(context);
    final rejecting = _selected == IncidentStatus.rejected;

    return Padding(
      // Keep the note field above the keyboard.
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(Gap.lg, 0, Gap.lg, Gap.xl),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Update status', style: theme.textTheme.titleLarge),
              const SizedBox(height: Gap.xs),
              Text(
                widget.incident.title,
                style: theme.textTheme.bodyMedium,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: Gap.lg),
              Row(
                children: [
                  Text('Now', style: theme.textTheme.labelLarge),
                  const SizedBox(width: Gap.sm),
                  StatusChip(widget.incident.status),
                ],
              ),
              const SizedBox(height: Gap.lg),
              Text('Move to', style: theme.textTheme.labelLarge),
              const SizedBox(height: Gap.sm),
              Wrap(
                spacing: Gap.sm,
                runSpacing: Gap.sm,
                children: [
                  for (final s in _options)
                    ChoiceChip(
                      avatar: Icon(
                        s.icon,
                        size: 18,
                        color: s.palette(context).foreground,
                      ),
                      label: Text(s.label),
                      selected: s == _selected,
                      onSelected: busy
                          ? null
                          : (_) => setState(() => _selected = s),
                    ),
                ],
              ),
              const SizedBox(height: Gap.lg),
              TextFormField(
                controller: _note,
                enabled: !busy,
                minLines: 2,
                maxLines: 5,
                maxLength: Limits.statusNoteMax,
                textCapitalization: TextCapitalization.sentences,
                validator: rejecting
                    ? Validators.rejectionNote
                    : Validators.statusNote,
                decoration: InputDecoration(
                  labelText: rejecting
                      ? 'Reason (required)'
                      : 'Note (optional)',
                  hintText: rejecting
                      ? 'For example: duplicate of an earlier report'
                      : 'For example: plumber booked for Monday',
                  helperText: 'The reporter sees this in the status history.',
                ),
              ),
              if (state case AsyncError(:final error)) ...[
                const SizedBox(height: Gap.sm),
                Text(
                  friendlyError(error),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
              ],
              const SizedBox(height: Gap.lg),
              LoadingButton(
                label: 'Move to ${_selected.label.toLowerCase()}',
                isLoading: busy,
                onPressed: _save,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
