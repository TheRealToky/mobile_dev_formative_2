import 'package:firebase_core/firebase_core.dart';

import '../../core/errors.dart';

/// Converts Firestore/Storage SDK errors into [UserFacingException]s.
///
/// Repositories call this so the application and presentation layers only
/// ever see messages they can show.
Object toUserFacing(Object error) => switch (error) {
  UserFacingException() => error,
  FirebaseException(:final code) => UserFacingException(
    firebaseErrorMessage(code),
  ),
  _ => error,
};

/// Message for a `FirebaseException.code` from Firestore or Storage.
String firebaseErrorMessage(String code) => switch (code) {
  'permission-denied' ||
  'unauthorized' => 'You do not have permission to do that.',
  'unauthenticated' => 'Your session has expired. Log in again.',
  'unavailable' || 'deadline-exceeded' || 'retry-limit-exceeded' =>
    'You appear to be offline. Check your connection and try again.',
  'not-found' || 'object-not-found' => 'That report no longer exists.',
  'failed-precondition' =>
    'This filter needs a database index that is still being built. '
        'Try again in a few minutes.',
  'quota-exceeded' => 'The storage limit has been reached. Try again later.',
  'canceled' => 'The upload was cancelled.',
  _ => 'Something went wrong ($code). Try again.',
};

/// Rethrows any stream error as a user-facing one.
extension UserFacingStream<T> on Stream<T> {
  Stream<T> userFacingErrors() =>
      handleError((Object e, StackTrace s) => throw toUserFacing(e));
}

/// Runs [action], rethrowing SDK errors as [UserFacingException].
Future<T> guardFirebase<T>(Future<T> Function() action) async {
  try {
    return await action();
  } on FirebaseException catch (e) {
    throw toUserFacing(e);
  }
}
