import 'package:flutter/material.dart';

import '../app/theme.dart';
import '../data/models/incident.dart';
import 'incident_visuals.dart';

/// Single-choice category chips.
///
/// [scrollable] lays them out in one horizontal row (feed filters);
/// otherwise they wrap onto several lines (report form). Tapping the selected
/// chip calls [onSelected] again, so callers decide whether that clears it.
class CategoryPicker extends StatelessWidget {
  const CategoryPicker({
    super.key,
    required this.selected,
    required this.onSelected,
    this.scrollable = false,
    this.enabled = true,
  });

  final IncidentCategory? selected;
  final ValueChanged<IncidentCategory> onSelected;
  final bool scrollable;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final chips = [
      for (final category in IncidentCategory.values)
        FilterChip(
          avatar: Icon(category.icon, size: 18),
          label: Text(category.label),
          selected: selected == category,
          showCheckmark: false,
          onSelected: enabled ? (_) => onSelected(category) : null,
        ),
    ];

    if (!scrollable) {
      return Wrap(spacing: Gap.sm, runSpacing: Gap.sm, children: chips);
    }
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: Gap.lg),
      child: Row(
        children: [
          for (final chip in chips) ...[chip, const SizedBox(width: Gap.sm)],
        ],
      ),
    );
  }
}
