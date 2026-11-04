import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/routes.dart';
import '../../app/theme.dart';
import '../../core/constants.dart';
import '../../core/errors.dart';
import '../../core/utils/feedback.dart';
import '../../core/validators.dart';
import '../../data/models/incident.dart';
import '../../data/models/report_draft.dart';
import '../../providers/report_controller.dart';
import '../../widgets/category_picker.dart';
import '../../widgets/loading_button.dart';
import '../../widgets/photo_picker.dart';

/// Create a report, or edit one when [initial] is given.
///
/// Field values live in the [Form]'s own fields (TextFormField / FormField),
/// so there is no `setState` here; submission, uploads and errors are handled
/// by [ReportController].
class ReportFormScreen extends ConsumerStatefulWidget {
  const ReportFormScreen({super.key, this.initial});

  final Incident? initial;

  @override
  ConsumerState<ReportFormScreen> createState() => _ReportFormScreenState();
}

class _ReportFormScreenState extends ConsumerState<ReportFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _categoryKey = GlobalKey<FormFieldState<IncidentCategory>>();
  final _buildingKey = GlobalKey<FormFieldState<String>>();
  final _photosKey = GlobalKey<FormFieldState<List<DraftPhoto>>>();
  final _anonymousKey = GlobalKey<FormFieldState<bool>>();

  late final ReportDraft? _initialDraft = widget.initial == null
      ? null
      : ReportDraft.fromIncident(widget.initial!);
  late final _title = TextEditingController(text: _initialDraft?.title);
  late final _description = TextEditingController(
    text: _initialDraft?.description,
  );
  late final _detail = TextEditingController(
    text: _initialDraft?.locationDetail,
  );

  bool get _isEdit => widget.initial != null;

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _detail.dispose();
    super.dispose();
  }

  Future<void> _addPhoto(
    FormFieldState<List<DraftPhoto>> field, {
    required bool fromCamera,
  }) async {
    try {
      final path = await ref
          .read(photoSourceProvider)
          .pick(fromCamera: fromCamera);
      if (path == null) return;
      field.didChange([...?field.value, LocalPhoto(path)]);
    } on Exception {
      if (mounted) {
        showSnack(
          context,
          fromCamera
              ? 'Could not open the camera. Check the app permissions.'
              : 'Could not open the gallery. Check the app permissions.',
          isError: true,
        );
      }
    }
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) {
      showSnack(context, 'Check the highlighted fields.', isError: true);
      return;
    }
    final draft = ReportDraft(
      title: _title.text,
      description: _description.text,
      category: _categoryKey.currentState!.value!,
      building: _buildingKey.currentState!.value!,
      locationDetail: _detail.text,
      isAnonymous: _anonymousKey.currentState!.value ?? false,
      photos: _photosKey.currentState!.value ?? const [],
    );

    final controller = ref.read(reportControllerProvider.notifier);
    final result = _isEdit
        ? await controller.saveEdit(widget.initial!, draft)
        : await controller.submit(draft);
    if (result == null || !mounted) return;

    showSnack(
      context,
      result.queuedOffline
          ? 'You are offline. The report is saved on this phone and will be '
                'sent when you are back online.'
          : (_isEdit ? 'Changes saved' : 'Report submitted'),
    );
    if (_isEdit) {
      context.pop();
    } else {
      _formKey.currentState!.reset();
      _title.clear();
      _description.clear();
      _detail.clear();
      context.push(Routes.incident(result.incidentId));
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(reportControllerProvider, (_, next) {
      if (next case AsyncError(:final error)) {
        showSnack(context, friendlyError(error), isError: true);
      }
    });
    final submission = ref.watch(reportControllerProvider);
    final busy = submission.isLoading;
    final textTheme = Theme.of(context).textTheme;

    Widget section(String label, {String? hint}) => Padding(
      padding: const EdgeInsets.only(top: Gap.xl, bottom: Gap.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: textTheme.titleMedium),
          if (hint != null) Text(hint, style: textTheme.bodySmall),
        ],
      ),
    );

    return Scaffold(
      appBar: AppBar(title: Text(_isEdit ? 'Edit report' : 'Report an issue')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: kMaxContentWidth),
            child: Form(
              key: _formKey,
              child: AbsorbPointer(
                absorbing: busy,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(
                    Gap.lg,
                    0,
                    Gap.lg,
                    Gap.xxl,
                  ),
                  children: [
                    section('What kind of issue?'),
                    FormField<IncidentCategory>(
                      key: _categoryKey,
                      initialValue: _initialDraft?.category,
                      validator: (v) => v == null ? 'Choose a category.' : null,
                      builder: (field) => _WithError(
                        field: field,
                        child: CategoryPicker(
                          selected: field.value,
                          onSelected: field.didChange,
                        ),
                      ),
                    ),
                    section('Details'),
                    TextFormField(
                      controller: _title,
                      maxLength: Limits.titleMax,
                      textCapitalization: TextCapitalization.sentences,
                      textInputAction: TextInputAction.next,
                      autovalidateMode: AutovalidateMode.onUnfocus,
                      validator: Validators.title,
                      decoration: const InputDecoration(
                        labelText: 'Title',
                        hintText: 'For example: Leaking tap in the library',
                      ),
                    ),
                    const SizedBox(height: Gap.sm),
                    TextFormField(
                      controller: _description,
                      minLines: 3,
                      maxLines: 8,
                      maxLength: Limits.descriptionMax,
                      textCapitalization: TextCapitalization.sentences,
                      autovalidateMode: AutovalidateMode.onUnfocus,
                      validator: Validators.description,
                      decoration: const InputDecoration(
                        labelText: 'What happened?',
                        hintText: 'What is wrong, since when, how serious',
                        alignLabelWithHint: true,
                      ),
                    ),
                    section('Where?'),
                    DropdownButtonFormField<String>(
                      key: _buildingKey,
                      initialValue: _initialDraft?.building,
                      isExpanded: true,
                      validator: Validators.building,
                      decoration: const InputDecoration(
                        labelText: 'Building',
                        prefixIcon: Icon(Icons.apartment),
                      ),
                      items: [
                        for (final b in {
                          ...campusBuildings,
                          // Keep an edited report's building even if the
                          // list has since changed.
                          ?_initialDraft?.building,
                        })
                          DropdownMenuItem(value: b, child: Text(b)),
                      ],
                      onChanged: (_) {},
                    ),
                    const SizedBox(height: Gap.md),
                    TextFormField(
                      controller: _detail,
                      maxLength: Limits.locationDetailMax,
                      autovalidateMode: AutovalidateMode.onUnfocus,
                      validator: Validators.locationDetail,
                      decoration: const InputDecoration(
                        labelText: 'Where exactly? (optional)',
                        hintText: 'Floor, room, near the main entrance...',
                      ),
                    ),
                    section(
                      'Photos (optional)',
                      hint:
                          'Up to ${Limits.maxPhotos}. Location data is '
                          'removed before upload.',
                    ),
                    FormField<List<DraftPhoto>>(
                      key: _photosKey,
                      initialValue: _initialDraft?.photos ?? const [],
                      builder: (field) => PhotoPicker(
                        photos: field.value ?? const [],
                        enabled: !busy,
                        onAdd: ({required fromCamera}) =>
                            _addPhoto(field, fromCamera: fromCamera),
                        onRemove: (i) =>
                            field.didChange([...?field.value]..removeAt(i)),
                      ),
                    ),
                    const SizedBox(height: Gap.lg),
                    FormField<bool>(
                      key: _anonymousKey,
                      initialValue: _initialDraft?.isAnonymous ?? false,
                      builder: (field) => SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        value: field.value ?? false,
                        onChanged: field.didChange,
                        title: const Text('Hide my name from other students'),
                        subtitle: const Text(
                          'Staff can still see who reported it, so they can '
                          'follow up.',
                        ),
                      ),
                    ),
                    const SizedBox(height: Gap.xl),
                    if (busy) ...[
                      _SubmitProgress(progress: submission.progress),
                      const SizedBox(height: Gap.md),
                    ],
                    LoadingButton(
                      label: _isEdit ? 'Save changes' : 'Submit report',
                      isLoading: busy,
                      onPressed: _submit,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Shows a [FormField]'s error text under a custom (non-text) input.
class _WithError<T> extends StatelessWidget {
  const _WithError({required this.field, required this.child});

  final FormFieldState<T> field;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        child,
        if (field.hasError)
          Padding(
            padding: const EdgeInsets.only(top: Gap.sm, left: Gap.md),
            child: Text(
              field.errorText!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ),
      ],
    );
  }
}

/// Upload / save progress shown above the submit button.
class _SubmitProgress extends StatelessWidget {
  const _SubmitProgress({required this.progress});

  final num? progress;

  @override
  Widget build(BuildContext context) {
    final p = (progress ?? 0).toDouble();
    final label = switch (p) {
      0 => 'Preparing...',
      < 0.9 => 'Uploading photos... ${(p / 0.9 * 100).round()} %',
      _ => 'Saving report...',
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(label, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: Gap.xs),
        LinearProgressIndicator(value: p == 0 ? null : p),
      ],
    );
  }
}
