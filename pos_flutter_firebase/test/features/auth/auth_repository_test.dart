import 'dart:async';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pos_flutter_firebase/shared/models/employee.dart';
import 'package:pos_flutter_firebase/features/auth/data/auth_service.dart';

class MockUser extends Mock implements User {}

class MockFirebaseAuth extends Mock implements FirebaseAuth {
  @override
  Stream<User?> authStateChanges() => const Stream.empty();
}

class MockUserCredential extends Mock implements UserCredential {}

void main() {
  late FakeFirebaseFirestore fakeFirestore;
  late MockFirebaseAuth mockAuth;
  late MockUser mockUser;
  late AuthService authService;

  setUp(() {
    fakeFirestore = FakeFirebaseFirestore();
    mockAuth = MockFirebaseAuth();
    mockUser = MockUser();
    authService = AuthService(auth: mockAuth, firestore: fakeFirestore);
  });

  group('AuthService.createOwnerWorkspace', () {
    test('creates business, store, employee and user doc', () async {
      when(() => mockUser.uid).thenReturn('test_uid_123');
      when(() => mockUser.email).thenReturn('owner@test.com');

      await authService.createOwnerWorkspace(
        businessName: 'Mi Tienda',
        user: mockUser,
      );

      final userDoc = await fakeFirestore.collection('users').doc('test_uid_123').get();
      expect(userDoc.exists, true);
      expect(userDoc.data()?['email'], 'owner@test.com');

      final businesses = await fakeFirestore.collection('businesses').get();
      expect(businesses.docs.length, 1);
      final businessData = businesses.docs.first.data();
      expect(businessData['name'], 'Mi Tienda');
      expect(businessData['ownerUid'], 'test_uid_123');
      final businessId = businesses.docs.first.id;

      final stores = await fakeFirestore
          .collection('businesses').doc(businessId)
          .collection('stores').get();
      expect(stores.docs.length, 1);
      expect(stores.docs.first.data()['name'], 'Sucursal principal');

      final employees = await fakeFirestore
          .collection('businesses').doc(businessId)
          .collection('employees').get();
      expect(employees.docs.length, 1);
      final empData = employees.docs.first.data();
      expect(empData['name'], 'owner@test.com');
      expect(empData['role'], 'owner');
      expect(empData['permissions'], ['*']);
      expect(empData['active'], true);

      final hashed = Employee.hashPin('0000');
      expect(empData['pin'], hashed);
    });

    test('skips if user document already exists', () async {
      when(() => mockUser.uid).thenReturn('existing_uid');
      when(() => mockUser.email).thenReturn('existing@test.com');

      await fakeFirestore.collection('users').doc('existing_uid').set({
        'businessId': 'existing_biz',
        'email': 'existing@test.com',
      });

      await authService.createOwnerWorkspace(
        businessName: 'New Biz',
        user: mockUser,
      );

      final businesses = await fakeFirestore.collection('businesses').get();
      expect(businesses.docs.length, 0);
    });

    test('does nothing when user is null', () async {
      await authService.createOwnerWorkspace(
        businessName: 'Test',
        user: null,
      );

      final businesses = await fakeFirestore.collection('businesses').get();
      expect(businesses.docs.length, 0);
    });

    test('creates workspace with default name when name is empty', () async {
      when(() => mockUser.uid).thenReturn('uid_empty');
      when(() => mockUser.email).thenReturn('empty@test.com');

      await authService.createOwnerWorkspace(
        businessName: '',
        user: mockUser,
      );

      final businesses = await fakeFirestore.collection('businesses').get();
      expect(businesses.docs.length, 1);
      expect(businesses.docs.first.data()['name'], 'Mi negocio');
    });

    test('sets default currency and timezone', () async {
      when(() => mockUser.uid).thenReturn('uid_curr');
      when(() => mockUser.email).thenReturn('curr@test.com');

      await authService.createOwnerWorkspace(
        businessName: 'Tienda',
        user: mockUser,
      );

      final businesses = await fakeFirestore.collection('businesses').get();
      final data = businesses.docs.first.data();
      expect(data['currency'], 'MXN');
      expect(data['timezone'], 'America/Mexico_City');
    });
  });

  group('AuthService.signIn', () {
    test('returns null on successful sign in', () async {
      final mockCredential = MockUserCredential();
      when(() => mockUser.uid).thenReturn('uid');
      when(() => mockCredential.user).thenReturn(mockUser);
      when(
        () => mockAuth.signInWithEmailAndPassword(
          email: any(named: 'email'),
          password: any(named: 'password'),
        ),
      ).thenAnswer((_) async => mockCredential);

      final result = await authService.signIn('test@test.com', 'password123');

      expect(result, isNull);
      verify(
        () => mockAuth.signInWithEmailAndPassword(
          email: 'test@test.com',
          password: 'password123',
        ),
      ).called(1);
    });

    test('returns error message on FirebaseAuthException', () async {
      when(
        () => mockAuth.signInWithEmailAndPassword(
          email: any(named: 'email'),
          password: any(named: 'password'),
        ),
      ).thenThrow(
        FirebaseAuthException(code: 'user-not-found', message: 'User not found'),
      );

      final result = await authService.signIn('wrong@test.com', 'pass');

      expect(result, 'No existe una cuenta con ese correo');
    });

    test('returns correct messages for different error codes', () async {
      final testCases = {
        'wrong-password': 'Contrasena incorrecta',
        'email-already-in-use': 'Ese correo ya esta registrado',
        'invalid-email': 'Correo invalido',
        'weak-password': 'La contrasena debe tener al menos 6 caracteres',
        'invalid-credential': 'Correo o contrasena incorrectos',
        'unknown-code': 'Error: unknown-code',
      };

      for (final entry in testCases.entries) {
        final mockAuthLocal = MockFirebaseAuth();
        final service = AuthService(auth: mockAuthLocal, firestore: fakeFirestore);

        when(
          () => mockAuthLocal.signInWithEmailAndPassword(
            email: any(named: 'email'),
            password: any(named: 'password'),
          ),
        ).thenThrow(
          FirebaseAuthException(code: entry.key, message: 'test'),
        );

        final result = await service.signIn('a@b.com', 'x');
        expect(result, entry.value);
      }
    });
  });

  group('AuthService.signUp', () {
    test('creates user and workspace on successful sign up', () async {
      final mockCredential = MockUserCredential();
      when(() => mockUser.uid).thenReturn('new_uid');
      when(() => mockUser.email).thenReturn('new@test.com');
      when(() => mockCredential.user).thenReturn(mockUser);
      when(
        () => mockAuth.createUserWithEmailAndPassword(
          email: any(named: 'email'),
          password: any(named: 'password'),
        ),
      ).thenAnswer((_) async => mockCredential);

      final result = await authService.signUp('new@test.com', 'password123', 'Mi Negocio');

      expect(result, isNull);

      final businesses = await fakeFirestore.collection('businesses').get();
      expect(businesses.docs.length, 1);
    });

    test('returns error on FirebaseAuthException', () async {
      when(
        () => mockAuth.createUserWithEmailAndPassword(
          email: any(named: 'email'),
          password: any(named: 'password'),
        ),
      ).thenThrow(FirebaseAuthException(code: 'email-already-in-use'));

      final result = await authService.signUp('existing@test.com', 'pass', 'Biz');

      expect(result, 'Ese correo ya esta registrado');
    });
  });

  group('AuthService.signOut', () {
    test('calls FirebaseAuth.signOut', () async {
      when(() => mockAuth.signOut()).thenAnswer((_) async {});

      await authService.signOut();

      verify(() => mockAuth.signOut()).called(1);
    });
  });

  group('AuthService.authStateChanges', () {
    test('returns auth state stream', () {
      final stream = authService.authStateChanges;
      expect(stream, isA<Stream<User?>>());
    });
  });

  group('AuthService.ensureCurrentUserWorkspace', () {
    test('creates workspace when no user doc exists', () async {
      when(() => mockAuth.currentUser).thenReturn(mockUser);
      when(() => mockUser.uid).thenReturn('no_doc_uid');
      when(() => mockUser.email).thenReturn('nodoc@test.com');

      await authService.ensureCurrentUserWorkspace();

      final businesses = await fakeFirestore.collection('businesses').get();
      expect(businesses.docs.length, 1);
    });

    test('does nothing when user doc already exists', () async {
      when(() => mockAuth.currentUser).thenReturn(mockUser);
      when(() => mockUser.uid).thenReturn('has_doc_uid');

      await fakeFirestore.collection('users').doc('has_doc_uid').set({
        'businessId': 'existing',
        'email': 'has@test.com',
      });

      await authService.ensureCurrentUserWorkspace();

      final businesses = await fakeFirestore.collection('businesses').get();
      expect(businesses.docs.length, 0);
    });

    test('does nothing when currentUser is null', () async {
      when(() => mockAuth.currentUser).thenReturn(null);

      await authService.ensureCurrentUserWorkspace();

      final businesses = await fakeFirestore.collection('businesses').get();
      expect(businesses.docs.length, 0);
    });
  });
}
