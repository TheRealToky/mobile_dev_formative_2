import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_dev_formative_2/core/validators.dart';

void main() {
  group('isAllowedEmail', () {
    test('accepts both ALU domains, case-insensitive and trimmed', () {
      expect(Validators.isAllowedEmail('a.b@alustudent.com'), isTrue);
      expect(Validators.isAllowedEmail('staff@alueducation.com'), isTrue);
      expect(Validators.isAllowedEmail('  A.B@ALUStudent.COM '), isTrue);
    });

    test('rejects other and look-alike domains', () {
      expect(Validators.isAllowedEmail('me@gmail.com'), isFalse);
      expect(Validators.isAllowedEmail('me@fake-alustudent.com'), isFalse);
      expect(Validators.isAllowedEmail('me@alustudent.com.evil.io'), isFalse);
      expect(Validators.isAllowedEmail('me@sub.alustudent.com'), isFalse);
      expect(Validators.isAllowedEmail('alustudent.com'), isFalse);
      expect(Validators.isAllowedEmail('@alustudent.com'), isFalse);
    });
  });

  group('email', () {
    test('explains each failure', () {
      expect(Validators.email(''), 'Enter your ALU email.');
      expect(Validators.email('not-an-email'), 'Enter a valid email address.');
      expect(Validators.email('me@gmail.com'), contains('@alustudent.com'));
      expect(Validators.email('me@alustudent.com'), isNull);
    });
  });

  group('passwords', () {
    test('new password needs length, a letter and a number', () {
      expect(Validators.newPassword(''), isNotNull);
      expect(Validators.newPassword('abc123'), contains('8'));
      expect(Validators.newPassword('abcdefgh'), contains('number'));
      expect(Validators.newPassword('12345678'), contains('letter'));
      expect(Validators.newPassword('campus2026'), isNull);
    });

    test('confirm password compares with the current password', () {
      var current = 'campus2026';
      final validate = Validators.confirmPassword(() => current);
      expect(validate('campus2026'), isNull);
      current = 'changed99';
      expect(validate('campus2026'), 'Passwords do not match.');
    });

    test('login password only checks presence', () {
      expect(Validators.loginPassword(''), isNotNull);
      expect(Validators.loginPassword('x'), isNull);
    });
  });

  group('title', () {
    test('enforces 5-80 trimmed characters', () {
      expect(Validators.title(null), isNotNull);
      expect(Validators.title('     '), isNotNull);
      expect(Validators.title('Leak'), contains('at least 5'));
      expect(Validators.title('Leaky'), isNull);
      expect(Validators.title('a' * 80), isNull);
      expect(Validators.title('a' * 81), contains('80'));
    });
  });

  group('description', () {
    test('enforces 10-1000 trimmed characters', () {
      expect(Validators.description(''), isNotNull);
      expect(Validators.description('Too short'), contains('at least 10'));
      expect(Validators.description('Tap leaks all night'), isNull);
      expect(Validators.description('a' * 1000), isNull);
      expect(Validators.description('a' * 1001), contains('1000'));
    });
  });

  group('other fields', () {
    test('location detail is optional but capped', () {
      expect(Validators.locationDetail(''), isNull);
      expect(Validators.locationDetail('a' * 121), isNotNull);
    });

    test('building is required', () {
      expect(Validators.building(null), isNotNull);
      expect(Validators.building('Library'), isNull);
    });

    test('display name needs 2-50 characters', () {
      expect(Validators.displayName('A'), isNotNull);
      expect(Validators.displayName('Ada'), isNull);
    });
  });
}
