import 'constants.dart';

/// Form validators. Each returns an error message, or `null` when valid, so
/// they plug straight into `TextFormField.validator`.
///
/// They are pure functions (no Flutter, no Firebase) so they are trivially
/// unit tested. The same limits are enforced again in `firestore.rules`.
abstract final class Validators {
  static final _emailPattern = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');

  /// True when [email] belongs to one of [allowedEmailDomains].
  ///
  /// Exact domain match: `x@alustudent.com` passes,
  /// `x@fake-alustudent.com` and `x@alustudent.com.evil.io` do not.
  static bool isAllowedEmail(String email) {
    final normalised = email.trim().toLowerCase();
    final at = normalised.lastIndexOf('@');
    if (at < 1) return false;
    return allowedEmailDomains.contains(normalised.substring(at + 1));
  }

  static String get _domainHint =>
      allowedEmailDomains.map((d) => '@$d').join(' or ');

  static String? email(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Enter your ALU email.';
    if (!_emailPattern.hasMatch(v)) return 'Enter a valid email address.';
    if (!isAllowedEmail(v)) {
      return 'Use your ALU email (ending in $_domainHint).';
    }
    return null;
  }

  /// Login only checks presence, so the user gets Firebase's answer rather
  /// than a client-side guess about an existing password.
  static String? loginPassword(String? value) =>
      (value ?? '').isEmpty ? 'Enter your password.' : null;

  static String? newPassword(String? value) {
    final v = value ?? '';
    if (v.isEmpty) return 'Choose a password.';
    if (v.length < Limits.passwordMin) {
      return 'Use at least ${Limits.passwordMin} characters.';
    }
    if (!RegExp(r'[A-Za-z]').hasMatch(v) || !RegExp(r'\d').hasMatch(v)) {
      return 'Use at least one letter and one number.';
    }
    return null;
  }

  /// Returns a validator that checks the value equals [password()].
  static String? Function(String?) confirmPassword(
    String Function() password,
  ) =>
      (value) => value == password() ? null : 'Passwords do not match.';

  static String? displayName(String? value) => _length(
    value,
    min: Limits.displayNameMin,
    max: Limits.displayNameMax,
    empty: 'Enter your name.',
    what: 'Name',
  );

  static String? title(String? value) => _length(
    value,
    min: Limits.titleMin,
    max: Limits.titleMax,
    empty: 'Give the report a short title.',
    what: 'Title',
  );

  static String? description(String? value) => _length(
    value,
    min: Limits.descriptionMin,
    max: Limits.descriptionMax,
    empty: 'Describe what happened.',
    what: 'Description',
  );

  /// Optional, but limited in length.
  static String? locationDetail(String? value) {
    final v = value?.trim() ?? '';
    return v.length > Limits.locationDetailMax
        ? 'Keep this under ${Limits.locationDetailMax} characters.'
        : null;
  }

  static String? building(String? value) =>
      (value == null || value.isEmpty) ? 'Choose a building.' : null;

  static String? statusNote(String? value) {
    final v = value?.trim() ?? '';
    return v.length > Limits.statusNoteMax
        ? 'Keep the note under ${Limits.statusNoteMax} characters.'
        : null;
  }

  /// A rejection must say why, so the reporter is not left guessing.
  static String? rejectionNote(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Say why the report is rejected.';
    return statusNote(v);
  }

  /// Checks trimmed length so "     " does not count as a title.
  static String? _length(
    String? value, {
    required int min,
    required int max,
    required String empty,
    required String what,
  }) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return empty;
    if (v.length < min) return '$what needs at least $min characters.';
    if (v.length > max) return '$what must be $max characters or fewer.';
    return null;
  }
}
