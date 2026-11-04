import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_dev_formative_2/app/app.dart';
import 'package:mobile_dev_formative_2/app/theme.dart';

void main() {
  testWidgets('app boots into the shell with bottom navigation', (
    tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(child: CampusApp(useGoogleFont: false)),
    );
    await tester.pumpAndSettle();

    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.text('Feed'), findsOneWidget);
    expect(find.text('Dashboard'), findsNothing);
  });

  test('both themes carry the status colour extension', () {
    for (final theme in [
      AppTheme.light(useGoogleFont: false),
      AppTheme.dark(useGoogleFont: false),
    ]) {
      expect(theme.extension<StatusColors>(), isNotNull);
      expect(theme.useMaterial3, isTrue);
    }
  });
}
