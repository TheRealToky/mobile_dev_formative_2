import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_dev_formative_2/app/theme.dart';
import 'package:mobile_dev_formative_2/core/errors.dart';
import 'package:mobile_dev_formative_2/data/models/incident.dart';
import 'package:mobile_dev_formative_2/features/incidents/feed_screen.dart';
import 'package:mobile_dev_formative_2/providers/filter_providers.dart';
import 'package:mobile_dev_formative_2/providers/incident_providers.dart';
import 'package:mobile_dev_formative_2/providers/retry_policy.dart';
import 'package:mobile_dev_formative_2/widgets/incident_card.dart';

import '../helpers/builders.dart';

/// Pumps the feed with the stream provider replaced by [stream], so the
/// real filteredIncidentsProvider and filter providers still run.
Future<ProviderContainer> pumpFeed(
  WidgetTester tester,
  Stream<List<Incident>> stream,
) async {
  final container = ProviderContainer(
    retry: noAutomaticRetry,
    overrides: [incidentsStreamProvider.overrideWith((ref) => stream)],
  );
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: AppTheme.light(useGoogleFont: false),
        home: const FeedScreen(),
      ),
    ),
  );
  return container;
}

void main() {
  testWidgets('shows skeletons while loading', (tester) async {
    await pumpFeed(tester, const Stream.empty());
    await tester.pump();
    expect(find.byType(IncidentCardSkeleton), findsWidgets);
  });

  testWidgets('lists incidents with a count', (tester) async {
    await pumpFeed(
      tester,
      Stream.value([
        buildIncident(id: 'a', title: 'Leaking tap'),
        buildIncident(id: 'b', title: 'Broken chair'),
      ]),
    );
    await tester.pumpAndSettle();
    expect(find.text('2 reports'), findsOneWidget);
    expect(find.byType(IncidentCard), findsNWidgets(2));
  });

  testWidgets('search filters the list and offers to clear', (tester) async {
    final container = await pumpFeed(
      tester,
      Stream.value([
        buildIncident(id: 'a', title: 'Leaking tap'),
        buildIncident(id: 'b', title: 'Broken chair', building: 'Cafeteria'),
      ]),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(SearchBar), 'chair');
    await tester.pumpAndSettle();
    expect(find.text('1 report'), findsOneWidget);
    expect(find.text('Clear filters'), findsOneWidget);

    await tester.enterText(find.byType(SearchBar), 'nothing matches');
    await tester.pumpAndSettle();
    expect(find.text('No reports match these filters.'), findsOneWidget);

    await tester.tap(find.text('Clear filters').first);
    await tester.pumpAndSettle();
    expect(container.read(searchQueryProvider), isEmpty);
    expect(find.byType(IncidentCard), findsNWidgets(2));
  });

  testWidgets('empty feed invites a report', (tester) async {
    await pumpFeed(tester, Stream.value(const []));
    await tester.pumpAndSettle();
    expect(find.text('Report an issue'), findsOneWidget);
  });

  testWidgets('errors show the message and a retry button', (tester) async {
    await pumpFeed(
      tester,
      Stream.error(const UserFacingException('You appear to be offline.')),
    );
    await tester.pumpAndSettle();
    expect(find.text('You appear to be offline.'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
  });
}
