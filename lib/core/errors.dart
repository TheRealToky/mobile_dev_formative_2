/// Base for errors whose [message] is safe to show to the user as-is.
///
/// Repositories catch SDK exceptions (Firebase codes, platform errors) and
/// rethrow one of these, so screens never handle raw Firebase errors.
class UserFacingException implements Exception {
  const UserFacingException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Turns any error into a sentence the user can read.
String friendlyError(Object error) => switch (error) {
  UserFacingException(:final message) => message,
  _ => 'Something went wrong. Check your connection and try again.',
};
