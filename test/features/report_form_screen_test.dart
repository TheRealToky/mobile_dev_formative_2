import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_dev_formative_2/app/theme.dart';
import 'package:mobile_dev_formative_2/data/models/incident.dart';
import 'package:mobile_dev_formative_2/features/incidents/report_form_screen.dart';
import 'package:mobile_dev_formative_2/widgets/category_picker.dart';
import 'package:mobile_dev_formative_2/widgets/photo_picker.dart';

import '../helpers/builders.dart';

Future<void> _pump(
  WidgetTester tester, {
  Incident? initial,
  Size size = const Size(400, 2000),
}) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        theme: AppTheme.light(useGoogleFont: false),
        home: ReportFormScreen(initial: initial),
      ),
    ),
  );
}

void main() {
  testWidgets('submitting an empty form shows every validation message', (
    tester,
  ) async {
    await _pump(tester);
    await tester.tap(find.text('Submit report'));
    await tester.pumpAndSettle();

    expect(find.text('Choose a category.'), findsOneWidget);
    expect(find.text('Give the report a short title.'), findsOneWidget);
    expect(find.text('Describe what happened.'), findsOneWidget);
    expect(find.text('Choose a building.'), findsOneWidget);
    expect(find.text('Check the highlighted fields.'), findsOneWidget);
  });

  testWidgets('a short title is flagged when the field loses focus', (
    tester,
  ) async {
    await _pump(tester);
    await tester.enterText(find.widgetWithText(TextFormField, 'Title'), 'Leak');
    await tester.testTextInput.receiveAction(TextInputAction.next);
    await tester.pumpAndSettle();

    expect(find.text('Title needs at least 5 characters.'), findsOneWidget);
  });

  testWidgets('editing pre-fills every field', (tester) async {
    await _pump(
      tester,
      initial: buildIncident(
        title: 'Leaking tap',
        photoUrls: const ['https://example.com/a.jpg'],
        isAnonymous: true,
      ),
    );

    expect(find.text('Edit report'), findsOneWidget);
    expect(find.text('Leaking tap'), findsOneWidget);
    expect(find.text('Library'), findsOneWidget);
    expect(find.text('2nd floor'), findsOneWidget);
    expect(find.text('Save changes'), findsOneWidget);
    final picker = tester.widget<PhotoPicker>(find.byType(PhotoPicker));
    expect(picker.photos, hasLength(1));
    final toggle = tester.widget<SwitchListTile>(find.byType(SwitchListTile));
    expect(toggle.value, isTrue);
  });

  // Regression: the form used to be a lazy ListView, so on a phone the
  // category picker was disposed when scrolled away and Submit crashed.
  testWidgets('fields keep their values when scrolled off a small screen', (
    tester,
  ) async {
    await _pump(tester, size: const Size(360, 640));
    await tester.tap(find.text('Water'));
    await tester.pump();

    final submit = find.text('Submit report');
    await tester.scrollUntilVisible(
      submit,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(submit);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    await tester.scrollUntilVisible(
      find.byType(CategoryPicker),
      -300,
      scrollable: find.byType(Scrollable).first,
    );
    final picker = tester.widget<CategoryPicker>(find.byType(CategoryPicker));
    expect(picker.selected, IncidentCategory.water);
    expect(find.text('Choose a category.'), findsNothing);
    expect(find.text('Choose a building.'), findsOneWidget);
  });
}
