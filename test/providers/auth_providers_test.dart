import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_dev_formative_2/data/models/app_user.dart';
import 'package:mobile_dev_formative_2/data/repositories/auth_repository.dart';
import 'package:mobile_dev_formative_2/providers/auth_providers.dart';
import 'package:mocktail/mocktail.dart';

import '../helpers/fakes.dart';

void main() {
  late MockAuthRepository auth;
  late MockUserRepository users;
  late StreamController<User?> authEvents;

  setUp(() {
    auth = MockAuthRepository();
    users = MockUserRepository();
    authEvents = StreamController<User?>.broadcast();
    when(() => auth.userChanges()).thenAnswer((_) => authEvents.stream);
    when(() => auth.refreshIdToken()).thenAnswer((_) async {});
  });

  tearDown(() => authEvents.close());

  ProviderContainer makeContainer() {
    final container = ProviderContainer.test(
      overrides: [
        authRepositoryProvider.overrideWithValue(auth),
        userRepositoryProvider.overrideWithValue(users),
      ],
    );
    // Keep the session (and everything it depends on) alive.
    container.listen(sessionProvider, (_, _) {});
    return container;
  }

  Future<void> settle() => Future<void>.delayed(Duration.zero);

  group('sessionProvider', () {
    test('is loading until the first auth event', () {
      final container = makeContainer();
      expect(container.read(sessionProvider), isA<SessionLoading>());
    });

    test('signed out when there is no user', () async {
      final container = makeContainer();
      authEvents.add(null);
      await settle();
      expect(container.read(sessionProvider), isA<SessionSignedOut>());
    });

    test('unverified users never load a profile', () async {
      final container = makeContainer();
      authEvents.add(mockUser(verified: false));
      await settle();
      expect(container.read(sessionProvider), isA<SessionUnverified>());
      verifyNever(
        () => users.watchOrCreateProfile(
          uid: any(named: 'uid'),
          email: any(named: 'email'),
          displayName: any(named: 'displayName'),
        ),
      );
    });

    test('verified user is ready once the profile arrives', () async {
      final profile = StreamController<AppUser?>();
      when(
        () => users.watchOrCreateProfile(
          uid: 'uid1',
          email: 'ada@alustudent.com',
          displayName: 'Ada',
        ),
      ).thenAnswer((_) => profile.stream);

      final container = makeContainer();
      authEvents.add(mockUser());
      await settle();
      expect(container.read(sessionProvider), isA<SessionLoading>());

      profile.add(
        AppUser(
          uid: 'uid1',
          displayName: 'Ada',
          email: 'ada@alustudent.com',
          role: UserRole.staff,
          createdAt: DateTime(2026),
        ),
      );
      await settle();
      final session = container.read(sessionProvider);
      expect(session, isA<SessionReady>());
      expect((session as SessionReady).isStaff, isTrue);
      verify(() => auth.refreshIdToken()).called(1);
      await profile.close();
    });
  });

  group('AuthController', () {
    test('exposes a friendly error when sign-in fails', () async {
      when(
        () => auth.signIn(
          email: any(named: 'email'),
          password: any(named: 'password'),
        ),
      ).thenThrow(const AuthException('Email or password is incorrect.'));

      final container = makeContainer();
      final ok = await container
          .read(authControllerProvider.notifier)
          .signIn(email: 'ada@alustudent.com', password: 'bad');

      expect(ok, isFalse);
      final state = container.read(authControllerProvider);
      expect(state.error, isA<AuthException>());
    });

    test('returns true and clears loading on success', () async {
      when(() => auth.signOut()).thenAnswer((_) async {});
      final container = makeContainer();
      final ok = await container
          .read(authControllerProvider.notifier)
          .signOut();
      expect(ok, isTrue);
      expect(container.read(authControllerProvider).isLoading, isFalse);
    });
  });
}
