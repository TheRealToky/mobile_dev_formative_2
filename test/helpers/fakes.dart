import 'package:firebase_auth/firebase_auth.dart';
import 'package:mobile_dev_formative_2/data/repositories/auth_repository.dart';
import 'package:mobile_dev_formative_2/data/repositories/user_repository.dart';
import 'package:mocktail/mocktail.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

class MockUserRepository extends Mock implements UserRepository {}

class MockUser extends Mock implements User {}

/// A Firebase [User] mock with the fields the app reads.
MockUser mockUser({
  String uid = 'uid1',
  String email = 'ada@alustudent.com',
  String displayName = 'Ada',
  bool verified = true,
}) {
  final user = MockUser();
  when(() => user.uid).thenReturn(uid);
  when(() => user.email).thenReturn(email);
  when(() => user.displayName).thenReturn(displayName);
  when(() => user.emailVerified).thenReturn(verified);
  return user;
}
