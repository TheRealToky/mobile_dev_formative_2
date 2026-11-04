import 'package:firebase_auth/firebase_auth.dart';

import '../../core/constants.dart';
import '../../core/errors.dart';
import '../../core/validators.dart';

/// Authentication error with a message that is safe to show as-is.
class AuthException extends UserFacingException {
  const AuthException(super.message);
}

/// Authentication operations used by the app.
///
/// Abstract so tests can inject a fake; [FirebaseAuthRepository] is the only
/// code that talks to Firebase Authentication.
abstract interface class AuthRepository {
  /// Emits the signed-in user (or `null`) whenever sign-in state, the ID
  /// token, or the user's profile (including `emailVerified`) changes.
  Stream<User?> userChanges();

  User? get currentUser;

  /// Creates the account, stores [displayName] and sends the verification
  /// email. Rejects non-ALU addresses before calling Firebase.
  Future<void> register({
    required String email,
    required String password,
    required String displayName,
  });

  Future<void> signIn({required String email, required String password});

  Future<void> signOut();

  Future<void> sendEmailVerification();

  Future<void> sendPasswordReset(String email);

  /// Reloads the user from the server and returns whether the email is now
  /// verified. When it is, the ID token is refreshed so Security Rules see
  /// `email_verified == true` straight away.
  Future<bool> reloadAndCheckVerified();

  /// Forces a fresh ID token (claims such as `email_verified` update).
  Future<void> refreshIdToken();
}

/// [AuthRepository] backed by Firebase Authentication.
class FirebaseAuthRepository implements AuthRepository {
  FirebaseAuthRepository(this._auth);

  final FirebaseAuth _auth;

  /// `userChanges()` rather than `authStateChanges()`: it is a superset that
  /// also fires after `reload()` and token refreshes, which is how the app
  /// notices that the email has been verified.
  @override
  Stream<User?> userChanges() => _auth.userChanges();

  @override
  User? get currentUser => _auth.currentUser;

  @override
  Future<void> register({
    required String email,
    required String password,
    required String displayName,
  }) => _guard(() async {
    if (!Validators.isAllowedEmail(email)) {
      throw AuthException(
        'Only ALU emails can register (${allowedEmailDomains.join(', ')}).',
      );
    }
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    final user = credential.user!;
    await user.updateDisplayName(displayName.trim());
    await user.sendEmailVerification();
  });

  @override
  Future<void> signIn({required String email, required String password}) =>
      _guard(() async {
        if (!Validators.isAllowedEmail(email)) {
          throw const AuthException('Use your ALU email to log in.');
        }
        await _auth.signInWithEmailAndPassword(
          email: email.trim(),
          password: password,
        );
      });

  @override
  Future<void> signOut() => _guard(_auth.signOut);

  @override
  Future<void> sendEmailVerification() =>
      _guard(() async => _auth.currentUser?.sendEmailVerification());

  @override
  Future<void> sendPasswordReset(String email) =>
      _guard(() => _auth.sendPasswordResetEmail(email: email.trim()));

  @override
  Future<bool> reloadAndCheckVerified() => _guard(() async {
    final user = _auth.currentUser;
    if (user == null) return false;
    await user.reload();
    final verified = _auth.currentUser?.emailVerified ?? false;
    if (verified) await _auth.currentUser?.getIdToken(true);
    return verified;
  });

  @override
  Future<void> refreshIdToken() =>
      _guard(() async => _auth.currentUser?.getIdToken(true));

  /// Runs [action], converting Firebase errors into [AuthException].
  Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on FirebaseAuthException catch (e) {
      throw AuthException(authErrorMessage(e.code));
    }
  }
}

/// Maps `FirebaseAuthException.code` to a message the user can act on.
///
/// Wrong password and unknown user share one message on purpose, so the app
/// does not reveal which emails have accounts.
String authErrorMessage(String code) => switch (code) {
  'invalid-email' => 'That email address is not valid.',
  'user-disabled' => 'This account has been disabled. Contact campus support.',
  'user-not-found' ||
  'wrong-password' ||
  'invalid-credential' ||
  'INVALID_LOGIN_CREDENTIALS' => 'Email or password is incorrect.',
  'email-already-in-use' =>
    'An account already exists for this email. Log in instead.',
  'weak-password' => 'Choose a stronger password (at least 8 characters).',
  'too-many-requests' => 'Too many attempts. Wait a few minutes and try again.',
  'network-request-failed' =>
    'No internet connection. Check your network and try again.',
  'operation-not-allowed' =>
    'Email sign-in is not enabled for this app. Contact the administrator.',
  'requires-recent-login' => 'Log in again to continue.',
  _ => 'Something went wrong signing you in ($code). Try again.',
};
