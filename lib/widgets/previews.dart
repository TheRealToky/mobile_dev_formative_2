import 'package:flutter/material.dart';
import 'package:flutter/widget_previews.dart';

import '../app/theme.dart';
import '../data/models/incident.dart';
import 'category_picker.dart';
import 'empty_state.dart';
import 'error_view.dart';
import 'incident_card.dart';
import 'lifecycle_rail.dart';
import 'status_chip.dart';

// Widget previews for the reusable widgets. Open the "Flutter Widget
// Preview" panel in VS Code / Android Studio, or run
// `flutter widget-preview start`. Each widget is shown in light and dark.
//
// The wrappers apply the app theme directly because the Preview `theme`
// API is marked unstable in this Flutter version.

/// Preview wrapper applying the light app theme.
Widget lightTheme(Widget child) => _themed(AppTheme.light(), child);

/// Preview wrapper applying the dark app theme.
Widget darkTheme(Widget child) => _themed(AppTheme.dark(), child);

Widget _themed(ThemeData theme, Widget child) => Theme(
  data: theme,
  child: Material(
    color: theme.colorScheme.surface,
    child: Padding(padding: const EdgeInsets.all(Gap.lg), child: child),
  ),
);

final _sample = Incident(
  id: 'preview',
  title: 'Water leaking from the ceiling in the library',
  description: 'Drips onto the study desks near the window.',
  category: IncidentCategory.water,
  status: IncidentStatus.inProgress,
  location: const IncidentLocation(building: 'Library', detail: '2nd floor'),
  photoUrls: const ['https://example.com/photo.jpg'],
  reporterId: 'u1',
  reporterName: 'Ada',
  isAnonymous: false,
  createdAt: DateTime(2026, 11, 4, 9),
  updatedAt: DateTime(2026, 11, 4, 10),
);

/// Incident cards in several statuses.
@Preview(group: 'Incident card', name: 'Light', wrapper: lightTheme)
@Preview(group: 'Incident card', name: 'Dark', wrapper: darkTheme)
Widget incidentCardPreview() => Column(
  children: [
    IncidentCard(incident: _sample, now: DateTime(2026, 11, 4, 11)),
    const SizedBox(height: Gap.sm),
    IncidentCard(
      incident: _sample.copyWith(
        status: IncidentStatus.rejected,
        category: IncidentCategory.furniture,
        title: 'Duplicate: broken chair',
        photoUrls: const [],
      ),
      now: DateTime(2026, 11, 6),
    ),
    const SizedBox(height: Gap.sm),
    const IncidentCardSkeleton(),
  ],
);

/// Every status chip and lifecycle rail.
@Preview(group: 'Status', name: 'Chips and rails, light', wrapper: lightTheme)
@Preview(group: 'Status', name: 'Chips and rails, dark', wrapper: darkTheme)
Widget statusPreview() => Column(
  crossAxisAlignment: CrossAxisAlignment.start,
  children: [
    for (final status in IncidentStatus.values)
      Padding(
        padding: const EdgeInsets.only(bottom: Gap.md),
        child: Row(
          children: [
            SizedBox(width: 160, child: LifecycleRail(status)),
            const SizedBox(width: Gap.lg),
            StatusChip(status),
          ],
        ),
      ),
  ],
);

/// The category picker.
@Preview(group: 'Category picker', name: 'Wrapped', wrapper: lightTheme)
Widget categoryPickerPreview() =>
    CategoryPicker(selected: IncidentCategory.electricity, onSelected: (_) {});

/// An empty state with an action.
@Preview(group: 'States', name: 'Empty', wrapper: lightTheme)
Widget emptyStatePreview() => EmptyState(
  icon: Icons.search_off,
  message: 'No reports match these filters.',
  actionLabel: 'Clear filters',
  onAction: () {},
);

/// An error view with retry.
@Preview(group: 'States', name: 'Error', wrapper: darkTheme)
Widget errorViewPreview() =>
    ErrorView(error: Exception('offline'), onRetry: () {});
