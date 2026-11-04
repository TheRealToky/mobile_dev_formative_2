import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_dev_formative_2/app/theme.dart';
import 'package:mobile_dev_formative_2/data/repositories/auth_repository.dart';
import 'package:mobile_dev_formative_2/features/auth/login_screen.dart';
import 'package:mobile_dev_formative_2/features/auth/register_screen.dart';
import 'package:mobile_dev_formative_2/providers/auth_providers.dart';
import 'package:mocktail/mocktail.dart';

import '../helpers/fakes.dart';

void main() {
  late MockAuthRepository auth;

  setUp(() => auth = MockAuthRepository());

  Future<void> pump(WidgetTester tester, Widget screen) async {
    await tester.binding.setSurfaceSize(const Size(400, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [authRepositoryProvider.overrideWithValue(auth)],
        child: MaterialApp(
          theme: AppTheme.light(useGoogleFont: false),
          home: screen,
        ),
      ),
    );
  }

  Future<void> fill(WidgetTester tester, String label, String text) =>
      tester.enterText(find.widgetWithText(TextFormField, label), text);

  group('register', () {
    testWidgets('rejects a non-ALU email without calling Firebase', (
      tester,
    ) async {
      await pump(tester, const RegisterScreen());
      await fill(tester, 'Full name', 'Ada Lovelace');
      await fill(tester, 'ALU email', 'ada@gmail.com');
      await fill(tester, 'Password', 'secret123');
      await fill(tester, 'Confirm password', 'secret123');
      await tester.tap(find.text('Create account'));
      await tester.pumpAndSettle();

      expect(
        find.text(
          'Use your ALU email (ending in @alustudent.com or @alueducation.com).',
        ),
        findsOneWidget,
      );
      verifyNever(
        () => auth.register(
          email: any(named: 'email'),
          password: any(named: 'password'),
          displayName: any(named: 'displayName'),
        ),
      );
    });

    testWidgets('flags mismatched passwords', (tester) async {
      await pump(tester, const RegisterScreen());
      await fill(tester, 'Password', 'secret123');
      await fill(tester, 'Confirm password', 'secret124');
      await tester.tap(find.text('Create account'));
      await tester.pumpAndSettle();
      expect(find.textContaining('do not match'), findsOneWidget);
    });

    testWidgets('a valid form creates the account', (tester) async {
      when(
        () => auth.register(
          email: any(named: 'email'),
          password: any(named: 'password'),
          displayName: any(named: 'displayName'),
        ),
      ).thenAnswer((_) async {});
      await pump(tester, const RegisterScreen());
      await fill(tester, 'Full name', 'Ada Lovelace');
      await fill(tester, 'ALU email', 'ada@alustudent.com');
      await fill(tester, 'Password', 'secret123');
      await fill(tester, 'Confirm password', 'secret123');
      await tester.tap(find.text('Create account'));
      await tester.pumpAndSettle();

      verify(
        () => auth.register(
          email: 'ada@alustudent.com',
          password: 'secret123',
          displayName: 'Ada Lovelace',
        ),
      ).called(1);
    });
  });

  group('login', () {
    testWidgets('wrong credentials show a clear message', (tester) async {
      when(
        () => auth.signIn(
          email: any(named: 'email'),
          password: any(named: 'password'),
        ),
      ).thenThrow(AuthException(authErrorMessage('invalid-credential')));
      await pump(tester, const LoginScreen());
      await fill(tester, 'ALU email', 'ada@alustudent.com');
      await fill(tester, 'Password', 'wrongpass1');
      await tester.tap(find.widgetWithText(FilledButton, 'Log in'));
      await tester.pumpAndSettle();

      expect(find.text('Email or password is incorrect.'), findsOneWidget);
    });

    testWidgets('empty fields are flagged before any request', (tester) async {
      await pump(tester, const LoginScreen());
      await tester.tap(find.widgetWithText(FilledButton, 'Log in'));
      await tester.pumpAndSettle();
      expect(find.text('Enter your ALU email.'), findsOneWidget);
      verifyNever(
        () => auth.signIn(
          email: any(named: 'email'),
          password: any(named: 'password'),
        ),
      );
    });
  });
}
