import 'dart:io';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:pos_flutter_firebase/shared/models/store.dart';
import 'package:pos_flutter_firebase/core/adapters/type_adapters.dart';
import 'package:pos_flutter_firebase/core/offline/sync_queue.dart';
import 'package:pos_flutter_firebase/core/network/connectivity_service.dart';
import 'package:pos_flutter_firebase/features/business/data/business_service.dart';

const businessId = 'test_business';

class OfflineConnectivity extends ConnectivityService {
  @override
  Future<bool> hasConnection() async => false;
}

void main() {
  late Directory tempDir;

  setUp(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    tempDir = await Directory.systemTemp.createTemp('pos-business-test-');
    Hive.init(tempDir.path);
    registerTypeAdapters();
    await Hive.openBox<List>('stores_v2');
    await Hive.openBox<Map>('syncQueue');
  });

  tearDown(() async {
    await Hive.close();
    if (await tempDir.exists()) await tempDir.delete(recursive: true);
  });

  group('BusinessService.updateBusiness (online)', () {
    test('updates business fields', () async {
      final db = FakeFirebaseFirestore();
      final service = BusinessService(firestore: db, connectivityService: ConnectivityService());

      await db.collection('businesses').doc(businessId).set({
        'name': 'Old Name',
        'currency': 'MXN',
        'timezone': 'America/Mexico_City',
      });

      await service.updateBusiness(
        businessId: businessId,
        name: 'New Name',
        currency: 'USD',
        timezone: 'America/New_York',
      );

      final doc = await db.collection('businesses').doc(businessId).get();
      expect(doc.data()?['name'], 'New Name');
      expect(doc.data()?['currency'], 'USD');
      expect(doc.data()?['timezone'], 'America/New_York');
    });
  });

  group('BusinessService.updateBusiness (offline)', () {
    test('enqueues update operation', () async {
      final db = FakeFirebaseFirestore();
      final service = BusinessService(firestore: db, connectivityService: OfflineConnectivity());

      await service.updateBusiness(
        businessId: businessId,
        name: 'Offline',
        currency: 'MXN',
        timezone: 'America/Mexico_City',
      );

      expect(SyncQueue.pendingCount, 1);
      expect(SyncQueue.getPending().single.type, 'updateBusiness');
    });
  });

  group('BusinessService.updateBusiness (validation)', () {
    test('throws on empty name', () async {
      final service = BusinessService(
        firestore: FakeFirebaseFirestore(),
        connectivityService: ConnectivityService(),
      );
      expect(
        () => service.updateBusiness(businessId: businessId, name: '  ', currency: 'MXN', timezone: 'UTC'),
        throwsA(isA<StateError>()),
      );
    });
  });

  group('BusinessService.addStore (online)', () {
    test('creates store document', () async {
      final db = FakeFirebaseFirestore();
      final service = BusinessService(firestore: db, connectivityService: ConnectivityService());

      await service.addStore(
        businessId: businessId,
        name: 'Sucursal Norte',
        address: 'Av. Principal 123',
        phone: '555-0100',
      );

      final stores = await db
          .collection('businesses').doc(businessId)
          .collection('stores').get();
      expect(stores.docs.length, 1);
      expect(stores.docs.first.data()['name'], 'Sucursal Norte');
      expect(stores.docs.first.data()['address'], 'Av. Principal 123');
      expect(stores.docs.first.data()['phone'], '555-0100');
      expect(stores.docs.first.data()['active'], true);
    });
  });

  group('BusinessService.addStore (offline)', () {
    test('enqueues add store operation', () async {
      final db = FakeFirebaseFirestore();
      final service = BusinessService(firestore: db, connectivityService: OfflineConnectivity());

      await service.addStore(businessId: businessId, name: 'Offline', address: '', phone: '');

      expect(SyncQueue.pendingCount, 1);
      expect(SyncQueue.getPending().single.type, 'addStore');
    });
  });

  group('BusinessService.addStore (validation)', () {
    test('throws on empty name', () async {
      final service = BusinessService(
        firestore: FakeFirebaseFirestore(),
        connectivityService: ConnectivityService(),
      );
      expect(
        () => service.addStore(businessId: businessId, name: '  ', address: '', phone: ''),
        throwsA(isA<StateError>()),
      );
    });
  });

  group('BusinessService.updateStore (online)', () {
    test('updates store fields', () async {
      final db = FakeFirebaseFirestore();
      final service = BusinessService(firestore: db, connectivityService: ConnectivityService());

      await db.collection('businesses').doc(businessId)
          .collection('stores').doc('s1')
          .set({'name': 'Old', 'address': '', 'phone': '', 'active': true});

      final store = Store(id: 's1', name: 'Old', address: '', phone: '', active: true);

      await service.updateStore(
        businessId: businessId,
        store: store,
        name: 'Updated',
        address: 'New Address',
        phone: '555-9999',
        active: false,
      );

      final doc = await db
          .collection('businesses').doc(businessId)
          .collection('stores').doc('s1').get();
      expect(doc.data()?['name'], 'Updated');
      expect(doc.data()?['address'], 'New Address');
      expect(doc.data()?['phone'], '555-9999');
      expect(doc.data()?['active'], false);
    });
  });

  group('BusinessService.updateStore (offline)', () {
    test('enqueues update store operation', () async {
      final db = FakeFirebaseFirestore();
      final service = BusinessService(firestore: db, connectivityService: OfflineConnectivity());

      final store = Store(id: 's_off', name: 'X', address: '', phone: '', active: true);
      await service.updateStore(
        businessId: businessId,
        store: store,
        name: 'Offline',
        address: '',
        phone: '',
        active: true,
      );

      expect(SyncQueue.pendingCount, 1);
      expect(SyncQueue.getPending().single.type, 'updateStore');
    });
  });

  group('BusinessService.updateStore (validation)', () {
    test('throws on empty store name', () async {
      final service = BusinessService(
        firestore: FakeFirebaseFirestore(),
        connectivityService: ConnectivityService(),
      );
      final store = Store(id: 's1', name: 'X', address: '', phone: '', active: true);
      expect(
        () => service.updateStore(
          businessId: businessId,
          store: store,
          name: '  ',
          address: '',
          phone: '',
          active: true,
        ),
        throwsA(isA<StateError>()),
      );
    });
  });
}
