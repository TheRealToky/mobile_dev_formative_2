import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_dev_formative_2/data/repositories/auth_repository.dart';

void main() {
  group('authErrorMessage', () {
    test('maps common Firebase codes to actionable messages', () {
      expect(authErrorMessage('email-already-in-use'), contains('Log in'));
      expect(authErrorMessage('too-many-requests'), contains('Wait'));
      expect(authErrorMessage('network-request-failed'), contains('internet'));
    });

    test('does not reveal whether an account exists', () {
      expect(
        authErrorMessage('user-not-found'),
        authErrorMessage('wrong-password'),
      );
      expect(
        authErrorMessage('invalid-credential'),
        authErrorMessage('wrong-password'),
      );
    });

    test('unknown codes get a generic message that names the code', () {
      expect(authErrorMessage('weird-code'), contains('weird-code'));
    });
  });

  group('FirebaseAuthRepository', () {
    test('rejects non-ALU emails before calling Firebase', () async {
      final auth = MockFirebaseAuth();
      final repo = FirebaseAuthRepository(auth);

      await expectLater(
        repo.register(
          email: 'me@gmail.com',
          password: 'campus2026',
          displayName: 'Me',
        ),
        throwsA(isA<AuthException>()),
      );
      expect(auth.currentUser, isNull);

      await expectLater(
        repo.signIn(email: 'me@gmail.com', password: 'x'),
        throwsA(isA<AuthException>()),
      );
    });

    test('registers an ALU email and signs the user in', () async {
      final auth = MockFirebaseAuth();
      final repo = FirebaseAuthRepository(auth);

      await repo.register(
        email: 'ada@alustudent.com',
        password: 'campus2026',
        displayName: 'Ada',
      );

      expect(auth.currentUser?.email, 'ada@alustudent.com');
    });

    test('signOut clears the current user', () async {
      final auth = MockFirebaseAuth(
        signedIn: true,
        mockUser: MockUser(email: 'ada@alustudent.com'),
      );
      final repo = FirebaseAuthRepository(auth);
      await repo.signOut();
      expect(repo.currentUser, isNull);
    });
  });
}
