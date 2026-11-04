import 'package:flutter/foundation.dart';

import 'firestore_converters.dart';

/// Role stored in `users/{uid}.role`. Only `student` can be written by the
/// client; `staff` is set by an administrator (Console or Admin SDK).
enum UserRole {
  student('student', 'Student'),
  staff('staff', 'Staff');

  const UserRole(this.value, this.label);

  final String value;
  final String label;

  /// Unknown or missing roles are treated as the least privileged one.
  static UserRole fromValue(Object? value) =>
      value == UserRole.staff.value ? UserRole.staff : UserRole.student;
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
