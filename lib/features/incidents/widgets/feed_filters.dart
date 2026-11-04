import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme.dart';
import '../../../data/models/incident.dart';
import '../../../providers/filter_providers.dart';
import '../../../widgets/category_picker.dart';
import '../../../widgets/incident_visuals.dart';

/// Search field plus category and status chips. All state lives in the
/// filter providers, so it survives navigation; this widget only renders it.
class FeedFilters extends ConsumerStatefulWidget {
  const FeedFilters({super.key});

  @override
  ConsumerState<FeedFilters> createState() => _FeedFiltersState();
}

class _FeedFiltersState extends ConsumerState<FeedFilters> {
  // Seeded from the provider so returning to the feed shows the last query.
  late final _search = TextEditingController(
    text: ref.read(searchQueryProvider),
  );

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Keep the text field in sync when filters are cleared elsewhere.
    ref.listen(searchQueryProvider, (_, next) {
      if (next != _search.text) _search.text = next;
    });
    final query = ref.watch(searchQueryProvider);
    final category = ref.watch(categoryFilterProvider);
    final status = ref.watch(statusFilterProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: Gap.lg),
          child: SearchBar(
            controller: _search,
            hintText: 'Search title, description or building',
            leading: const Icon(Icons.search),
            elevation: const WidgetStatePropertyAll(0),
            onChanged: ref.read(searchQueryProvider.notifier).set,
            trailing: [
              if (query.isNotEmpty)
                IconButton(
                  tooltip: 'Clear search',
                  icon: const Icon(Icons.close),
                  onPressed: ref.read(searchQueryProvider.notifier).clear,
                ),
            ],
          ),
        ),
        const SizedBox(height: Gap.md),
        CategoryPicker(
          scrollable: true,
          selected: category,
          onSelected: ref.read(categoryFilterProvider.notifier).toggle,
        ),
        const SizedBox(height: Gap.sm),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: Gap.lg),
          child: Row(
            children: [
              for (final s in IncidentStatus.values) ...[
                FilterChip(
                  avatar: Icon(s.icon, size: 18),
                  label: Text(s.label),
                  selected: status == s,
                  showCheckmark: false,
                  onSelected: (_) =>
                      ref.read(statusFilterProvider.notifier).toggle(s),
                ),
                const SizedBox(width: Gap.sm),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
