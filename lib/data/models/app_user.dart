import 'package:flutter/foundation.dart';

import '../../core/constants.dart';

import 'firestore_converters.dart';

/// Role stored in `users/{uid}.role`: the single source of truth for what a
/// user can see and do.
///
/// Set once when the profile is created, from the email domain
/// ([UserRole.forEmail]); the rules only accept that role. After that the
/// client can never change it, but an administrator can (Firestore console
/// or Admin SDK): setting it to `staff` gives the Dashboard and every staff
/// permission, setting it to `student` gives the student screens and takes
/// staff permissions away, whatever the email domain. The change applies
/// immediately, without logging out.
enum UserRole {
  student('student', 'Student'),
  staff('staff', 'Staff');

  const UserRole(this.value, this.label);

  final String value;
  final String label;

  /// Parses the stored role. Case and surrounding spaces are ignored, so a
  /// value typed by hand in the console (`"Staff"`, `"staff "`) still works;
  /// `firestore.rules` normalises it the same way. Unknown or missing roles
  /// are treated as the least privileged one.
  static UserRole fromValue(Object? value) =>
      value is String && value.trim().toLowerCase() == UserRole.staff.value
      ? UserRole.staff
      : UserRole.student;

  /// Starting role for a new account: staff for [staffEmailDomains]
  /// (`@alueducation.com`), student otherwise (`@alustudent.com`).
  static UserRole forEmail(String email) {
    final domain = email.trim().toLowerCase().split('@').last;
    return staffEmailDomains.contains(domain)
        ? UserRole.staff
        : UserRole.student;
  }
}

/// Profile document at `users/{uid}`.
@immutable
class AppUser {
  const AppUser({
    required this.uid,
    required this.displayName,
    required this.email,
    required this.role,
    required this.createdAt,
  });

  final String uid;
  final String displayName;
  final String email;
  final UserRole role;
  final DateTime createdAt;

  bool get isStaff => role == UserRole.staff;

  /// Builds a user from a Firestore document map. [uid] is the document id.
  factory AppUser.fromMap(String uid, Map<String, dynamic> map) => AppUser(
    uid: uid,
    displayName: stringFrom(map['displayName']),
    email: stringFrom(map['email']),
    role: UserRole.fromValue(map['role']),
    createdAt: dateFromFirestore(map['createdAt']),
  );

  /// Fields written on registration. `createdAt` is added by the repository
  /// as a server timestamp, so it is not included here.
  Map<String, dynamic> toMap() => {
    'displayName': displayName,
    'email': email,
    'role': role.value,
  };

  @override
  bool operator ==(Object other) =>
      other is AppUser &&
      other.uid == uid &&
      other.displayName == displayName &&
      other.email == email &&
      other.role == role &&
      other.createdAt == createdAt;

  @override
  int get hashCode => Object.hash(uid, displayName, email, role, createdAt);
}
