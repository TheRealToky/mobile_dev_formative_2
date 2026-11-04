import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_dev_formative_2/app/theme.dart';
import 'package:mobile_dev_formative_2/data/models/incident.dart';
import 'package:mobile_dev_formative_2/widgets/incident_card.dart';
import 'package:mobile_dev_formative_2/widgets/status_chip.dart';

import '../helpers/builders.dart';

Widget _wrap(Widget child, {ThemeData? theme}) => MaterialApp(
  theme: theme ?? AppTheme.light(useGoogleFont: false),
  home: Scaffold(body: child),
);

void main() {
  testWidgets('shows title, location, status text and relative time', (
    tester,
  ) async {
    var tapped = false;
    await tester.pumpWidget(
      _wrap(
        IncidentCard(
          incident: buildIncident(
            title: 'Leaking tap',
            status: IncidentStatus.inProgress,
            createdAt: DateTime(2026, 11, 4, 9),
          ),
          now: DateTime(2026, 11, 4, 11),
          onTap: () => tapped = true,
        ),
      ),
    );

    expect(find.text('Leaking tap'), findsOneWidget);
    expect(find.text('Library, 2nd floor'), findsOneWidget);
    expect(find.text('In progress'), findsOneWidget);
    expect(find.text('2 hours ago'), findsOneWidget);

    await tester.tap(find.byType(IncidentCard));
    expect(tapped, isTrue);
  });

  testWidgets('status chip exposes the status to screen readers', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(_wrap(const StatusChip(IncidentStatus.resolved)));
    expect(find.bySemanticsLabel('Status: Resolved'), findsOneWidget);
    handle.dispose();
  });

  testWidgets('renders in dark mode with long titles without overflow', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      _wrap(
        IncidentCard(
          incident: buildIncident(
            title: 'A very long title ' * 6,
            detail: 'A very long location detail that keeps going on',
            status: IncidentStatus.rejected,
            photoUrls: const ['x'],
          ),
        ),
        theme: AppTheme.dark(useGoogleFont: false),
      ),
    );
    expect(tester.takeException(), isNull);
    expect(find.text('Rejected'), findsOneWidget);
  });
}
