import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/app_user.dart';
import '../data/repositories/auth_repository.dart';
import '../data/repositories/user_repository.dart';
import 'firebase_providers.dart';

/// Repository providers: the application layer's only way to reach Firebase.
final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => FirebaseAuthRepository(ref.watch(firebaseAuthProvider)),
);

final userRepositoryProvider = Provider<UserRepository>(
  (ref) => FirestoreUserRepository(ref.watch(firestoreProvider)),
);

/// Current Firebase user, or `null` when signed out. Drives router redirects.
///
/// Every user-derived provider watches this one, so on logout they all
/// rebuild with no user and cached data is discarded.
final authStateProvider = StreamProvider<User?>(
  (ref) => ref.watch(authRepositoryProvider).userChanges(),
);

/// The `users/{uid}` profile (with the role) of the signed-in, verified user.
///
/// Emits `null` while signed out, unverified, or while the profile document
/// is being created on first login.
final currentUserProfileProvider = StreamProvider<AppUser?>((ref) async* {
  // Only rebuild when the identity or verification changes, not on every
  // hourly token refresh (which emits a new User object).
  final identity = ref.watch(
    authStateProvider.select((auth) {
      final user = auth.value;
      return user == null
          ? null
          : (
              uid: user.uid,
              verified: user.emailVerified,
              email: user.email ?? '',
              name: user.displayName ?? '',
            );
    }),
  );
  if (identity == null || !identity.verified) {
    yield null;
    return;
  }
  // Rules check `email_verified` on the ID token, which can lag behind the
  // reloaded user. Refresh it before the first Firestore read/write.
  await ref.read(authRepositoryProvider).refreshIdToken();
  yield* ref
      .read(userRepositoryProvider)
      .watchOrCreateProfile(
        uid: identity.uid,
        email: identity.email,
        displayName: identity.name,
      );
});

/// Where the user is in the sign-in journey; the router redirects from it.
sealed class SessionState {
  const SessionState();
}

/// Waiting for the first auth event or for the profile document.
class SessionLoading extends SessionState {
  const SessionLoading();
}

class SessionSignedOut extends SessionState {
  const SessionSignedOut();
}

/// Signed in but the email link has not been opened yet.
class SessionUnverified extends SessionState {
  const SessionUnverified(this.email);
  final String email;
}

/// Verified with a loaded profile: the app is usable.
class SessionReady extends SessionState {
  const SessionReady(this.profile);
  final AppUser profile;
  bool get isStaff => profile.isStaff;
}

/// The profile could not be loaded (offline, rules denied, ...).
class SessionError extends SessionState {
  const SessionError(this.error);
  final Object error;
}

/// Combines auth and profile into one [SessionState].
///
/// Showing a splash until both have resolved avoids flashing the wrong
/// screen (for example the login screen for a user who is already signed in).
final sessionProvider = Provider<SessionState>((ref) {
  final auth = ref.watch(authStateProvider);
  if (auth.hasError) return SessionError(auth.error!);
  if (!auth.hasValue) return const SessionLoading();

  final user = auth.value;
  if (user == null) return const SessionSignedOut();
  if (!user.emailVerified) return SessionUnverified(user.email ?? '');

  final profile = ref.watch(currentUserProfileProvider);
  if (profile.hasError) return SessionError(profile.error!);
  final data = profile.value;
  return data == null ? const SessionLoading() : SessionReady(data);
});

/// Runs auth actions (log in, register, resend email, ...) and exposes their
/// progress as an [AsyncValue] so buttons can show a spinner and screens can
/// show the error message.
class AuthController extends AsyncNotifier<void> {
  @override
  FutureOr<void> build() {}

  AuthRepository get _repo => ref.read(authRepositoryProvider);

  Future<bool> signIn({required String email, required String password}) =>
      _run(() => _repo.signIn(email: email, password: password));

  Future<bool> register({
    required String email,
    required String password,
    required String displayName,
  }) => _run(
    () => _repo.register(
      email: email,
      password: password,
      displayName: displayName,
    ),
  );

  Future<bool> sendPasswordReset(String email) =>
      _run(() => _repo.sendPasswordReset(email));

  Future<bool> resendVerification() => _run(_repo.sendEmailVerification);

  Future<bool> signOut() => _run(_repo.signOut);

  /// Silent check used by the Verify Email screen's timer: it does not touch
  /// [state], so no spinner flickers every few seconds.
  Future<bool> checkEmailVerified() async {
    try {
      return await _repo.reloadAndCheckVerified();
    } on Exception {
      return false;
    }
  }

  Future<bool> _run(Future<void> Function() action) async {
    state = const AsyncLoading();
    final result = await AsyncValue.guard(action);
    if (!ref.mounted) return !result.hasError;
    state = result;
    return !result.hasError;
  }
}

final authControllerProvider = AsyncNotifierProvider<AuthController, void>(
  AuthController.new,
);
