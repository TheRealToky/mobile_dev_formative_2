import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_dev_formative_2/app/app.dart';
import 'package:mobile_dev_formative_2/app/theme.dart';
import 'package:mobile_dev_formative_2/providers/auth_providers.dart';
import 'package:mocktail/mocktail.dart';

import 'helpers/fakes.dart';

void main() {
  testWidgets('signed-out users land on the login screen', (tester) async {
    final auth = MockAuthRepository();
    when(() => auth.userChanges()).thenAnswer((_) => Stream.value(null));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [authRepositoryProvider.overrideWithValue(auth)],
        child: const CampusApp(useGoogleFont: false),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Log in'), findsWidgets);
    expect(find.text('Create an account'), findsOneWidget);
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
