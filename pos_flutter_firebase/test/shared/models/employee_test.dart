import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pos_flutter_firebase/shared/models/employee.dart';

Employee _employee(String pin) => Employee(
      id: 'e1',
      businessId: 'b1',
      authUid: '',
      name: 'Test',
      email: 'test@test.com',
      role: 'cashier',
      storeIds: const ['s1'],
      permissions: const ['pos'],
      pin: pin,
      active: true,
    );

void main() {
  group('Employee.verifyPin', () {
    test('verifies a modern pbkdf2 hashed pin', () {
      final employee = _employee(Employee.hashPin('1234'));
      expect(employee.verifyPin('1234'), isTrue);
      expect(employee.verifyPin('12345'), isFalse);
      expect(employee.pin, startsWith(r'pbkdf2$'));
    });

    test('generates a unique salt for each hash', () {
      final first = Employee.hashPin('1234');
      final second = Employee.hashPin('1234');
      expect(first, isNot(second));
    });

    test('verifies legacy sha-256 hashes (no salt)', () {
      final legacySha = sha256.convert(utf8.encode('9999')).toString();
      final employee = _employee(legacySha);
      expect(employee.verifyPin('9999'), isTrue);
      expect(employee.verifyPin('0000'), isFalse);
    });

    test('verifies legacy plaintext digit pins', () {
      final employee = _employee('0000');
      expect(employee.verifyPin('0000'), isTrue);
      expect(employee.verifyPin('0001'), isFalse);
    });

    test('accepts hashPin and verifyHashedPin matching', () {
      final hashed = Employee.hashPin('4321');
      expect(Employee.verifyHashedPin('4321', hashed), isTrue);
      expect(Employee.verifyHashedPin('4322', hashed), isFalse);
    });
  });
}