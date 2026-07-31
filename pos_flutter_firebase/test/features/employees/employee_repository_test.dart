import 'dart:io';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:pos_flutter_firebase/shared/models/employee.dart';
import 'package:pos_flutter_firebase/core/adapters/type_adapters.dart';
import 'package:pos_flutter_firebase/core/offline/sync_queue.dart';
import 'package:pos_flutter_firebase/core/network/connectivity_service.dart';
import 'package:pos_flutter_firebase/features/employees/data/employee_service.dart';

const businessId = 'test_business';

class OfflineConnectivity extends ConnectivityService {
  @override
  Future<bool> hasConnection() async => false;
}

void main() {
  late Directory tempDir;

  setUp(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    tempDir = await Directory.systemTemp.createTemp('pos-employee-test-');
    Hive.init(tempDir.path);
    registerTypeAdapters();
    await Hive.openBox<List>('employees_v2');
    await Hive.openBox<Map>('syncQueue');
  });

  tearDown(() async {
    await Hive.close();
    if (await tempDir.exists()) await tempDir.delete(recursive: true);
  });

  group('EmployeeService.addEmployee (online)', () {
    test('creates employee with hashed pin', () async {
      final db = FakeFirebaseFirestore();
      final service = EmployeeService(firestore: db, connectivityService: ConnectivityService());

      await service.addEmployee(
        businessId: businessId,
        name: 'Juan Perez',
        email: 'juan@test.com',
        role: 'cashier',
        pin: '1234',
        storeIds: ['s1'],
        permissions: ['pos'],
      );

      final employees = await db
          .collection('businesses').doc(businessId)
          .collection('employees').get();
      expect(employees.docs.length, 1);

      final data = employees.docs.first.data();
      expect(data['name'], 'Juan Perez');
      expect(data['email'], 'juan@test.com');
      expect(data['role'], 'cashier');
      expect(data['storeIds'], ['s1']);
      expect(data['permissions'], ['pos']);
      expect(data['active'], true);

      final hashed = Employee.hashPin('1234');
      expect(data['pin'], hashed);
    });
  });

  group('EmployeeService.addEmployee (offline)', () {
    test('enqueues operation with hashed pin', () async {
      final db = FakeFirebaseFirestore();
      final service = EmployeeService(firestore: db, connectivityService: OfflineConnectivity());

      await service.addEmployee(
        businessId: businessId,
        name: 'Offline',
        email: 'off@test.com',
        role: 'cashier',
        pin: '9999',
        storeIds: ['s1'],
        permissions: ['pos'],
      );

      expect(SyncQueue.pendingCount, 1);
      final pending = SyncQueue.getPending().single;
      expect(pending.type, 'addEmployee');
      expect(pending.data['pin'], Employee.hashPin('9999'));
    });
  });

  group('EmployeeService.addEmployee (validation)', () {
    test('throws on empty name', () async {
      final service = EmployeeService(
        firestore: FakeFirebaseFirestore(),
        connectivityService: ConnectivityService(),
      );
      expect(
        () => service.addEmployee(
          businessId: businessId,
          name: '  ',
          email: 'a@b.com',
          role: 'cashier',
          pin: '1234',
          storeIds: ['s1'],
          permissions: [],
        ),
        throwsA(isA<StateError>()),
      );
    });

    test('throws on empty email', () async {
      final service = EmployeeService(
        firestore: FakeFirebaseFirestore(),
        connectivityService: ConnectivityService(),
      );
      expect(
        () => service.addEmployee(
          businessId: businessId,
          name: 'Test',
          email: '  ',
          role: 'cashier',
          pin: '1234',
          storeIds: ['s1'],
          permissions: [],
        ),
        throwsA(isA<StateError>()),
      );
    });

    test('throws on empty storeIds', () async {
      final service = EmployeeService(
        firestore: FakeFirebaseFirestore(),
        connectivityService: ConnectivityService(),
      );
      expect(
        () => service.addEmployee(
          businessId: businessId,
          name: 'Test',
          email: 'a@b.com',
          role: 'cashier',
          pin: '1234',
          storeIds: [],
          permissions: [],
        ),
        throwsA(isA<StateError>()),
      );
    });

    test('throws on pin shorter than 4 digits', () async {
      final service = EmployeeService(
        firestore: FakeFirebaseFirestore(),
        connectivityService: ConnectivityService(),
      );
      expect(
        () => service.addEmployee(
          businessId: businessId,
          name: 'Test',
          email: 'a@b.com',
          role: 'cashier',
          pin: '123',
          storeIds: ['s1'],
          permissions: [],
        ),
        throwsA(isA<StateError>()),
      );
    });
  });

  group('EmployeeService.updateEmployee (online)', () {
    test('updates employee fields', () async {
      final db = FakeFirebaseFirestore();
      final service = EmployeeService(firestore: db, connectivityService: ConnectivityService());

      final docRef = db
          .collection('businesses').doc(businessId)
          .collection('employees').doc('e1');
      await docRef.set({
        'name': 'Old',
        'email': 'old@test.com',
        'role': 'cashier',
        'pin': Employee.hashPin('0000'),
        'storeIds': ['s1'],
        'permissions': [],
        'active': true,
      });

      final employee = Employee(
        id: 'e1',
        businessId: businessId,
        authUid: '',
        name: 'Old',
        email: 'old@test.com',
        role: 'cashier',
        storeIds: ['s1'],
        permissions: [],
        pin: Employee.hashPin('0000'),
        active: true,
      );

      await service.updateEmployee(
        businessId: businessId,
        employee: employee,
        role: 'admin',
        pin: '5678',
        storeIds: ['s1', 's2'],
        permissions: ['pos', 'admin'],
        active: true,
      );

      final doc = await docRef.get();
      expect(doc.data()?['role'], 'admin');
      expect(doc.data()?['pin'], Employee.hashPin('5678'));
      expect(doc.data()?['storeIds'], ['s1', 's2']);
      expect(doc.data()?['permissions'], ['pos', 'admin']);
    });
  });

  group('EmployeeService.updateEmployee (offline)', () {
    test('enqueues update operation', () async {
      final db = FakeFirebaseFirestore();
      final service = EmployeeService(firestore: db, connectivityService: OfflineConnectivity());

      final employee = Employee(
        id: 'e_off',
        businessId: businessId,
        authUid: '',
        name: 'X',
        email: 'x@test.com',
        role: 'cashier',
        storeIds: ['s1'],
        permissions: [],
        pin: Employee.hashPin('0000'),
        active: true,
      );

      await service.updateEmployee(
        businessId: businessId,
        employee: employee,
        role: 'admin',
        pin: '1111',
        storeIds: ['s1'],
        permissions: ['pos'],
        active: true,
      );

      expect(SyncQueue.pendingCount, 1);
      expect(SyncQueue.getPending().single.type, 'updateEmployee');
    });
  });

  group('EmployeeService.updateEmployee (validation)', () {
    test('throws on empty storeIds', () async {
      final service = EmployeeService(
        firestore: FakeFirebaseFirestore(),
        connectivityService: ConnectivityService(),
      );
      final employee = Employee(
        id: 'e1',
        businessId: businessId,
        authUid: '',
        name: 'Test',
        email: 'a@b.com',
        role: 'cashier',
        storeIds: ['s1'],
        permissions: [],
        pin: Employee.hashPin('0000'),
        active: true,
      );
      expect(
        () => service.updateEmployee(
          businessId: businessId,
          employee: employee,
          role: 'cashier',
          pin: '1234',
          storeIds: [],
          permissions: [],
          active: true,
        ),
        throwsA(isA<StateError>()),
      );
    });
  });
}
