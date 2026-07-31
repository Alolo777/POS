import 'dart:io';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:pos_flutter_firebase/core/adapters/type_adapters.dart';
import 'package:pos_flutter_firebase/core/offline/sync_queue.dart';
import 'package:pos_flutter_firebase/core/network/connectivity_service.dart';
import 'package:pos_flutter_firebase/features/pos/data/discount_service.dart';

const businessId = 'test_business';

class OfflineConnectivity extends ConnectivityService {
  @override
  Future<bool> hasConnection() async => false;
}

void main() {
  late Directory tempDir;

  setUp(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    tempDir = await Directory.systemTemp.createTemp('pos-discount-test-');
    Hive.init(tempDir.path);
    registerTypeAdapters();
    await Hive.openBox<List>('discounts_v2');
    await Hive.openBox<Map>('syncQueue');
  });

  tearDown(() async {
    await Hive.close();
    if (await tempDir.exists()) await tempDir.delete(recursive: true);
  });

  group('DiscountService.addDiscount (online)', () {
    test('creates percentage discount', () async {
      final db = FakeFirebaseFirestore();
      final service = DiscountService(firestore: db, connectivityService: ConnectivityService());

      final id = await service.addDiscount(
        businessId: businessId,
        name: '10% Off',
        type: 'percentage',
        value: 10.0,
      );

      final doc = await db
          .collection('businesses').doc(businessId)
          .collection('discounts').doc(id).get();
      expect(doc.data()?['name'], '10% Off');
      expect(doc.data()?['type'], 'percentage');
      expect(doc.data()?['value'], 10.0);
      expect(doc.data()?['active'], true);
    });

    test('creates fixed discount', () async {
      final db = FakeFirebaseFirestore();
      final service = DiscountService(firestore: db, connectivityService: ConnectivityService());

      final id = await service.addDiscount(
        businessId: businessId,
        name: r'$5 Off',
        type: 'fixed',
        value: 5.0,
      );

      final doc = await db
          .collection('businesses').doc(businessId)
          .collection('discounts').doc(id).get();
      expect(doc.data()?['type'], 'fixed');
      expect(doc.data()?['value'], 5.0);
    });
  });

  group('DiscountService.addDiscount (offline)', () {
    test('enqueues operation and returns temp id', () async {
      final db = FakeFirebaseFirestore();
      final service = DiscountService(firestore: db, connectivityService: OfflineConnectivity());

      final id = await service.addDiscount(
        businessId: businessId,
        name: 'Offline',
        type: 'fixed',
        value: 10.0,
      );

      expect(id, startsWith('temp_'));
      expect(SyncQueue.pendingCount, 1);
      expect(SyncQueue.getPending().single.type, 'addDiscount');
    });
  });

  group('DiscountService.addDiscount (validation)', () {
    test('throws on empty name', () async {
      final service = DiscountService(
        firestore: FakeFirebaseFirestore(),
        connectivityService: ConnectivityService(),
      );
      expect(
        () => service.addDiscount(businessId: businessId, name: '  ', type: 'fixed', value: 10),
        throwsA(isA<StateError>()),
      );
    });

    test('throws on invalid type', () async {
      final service = DiscountService(
        firestore: FakeFirebaseFirestore(),
        connectivityService: ConnectivityService(),
      );
      expect(
        () => service.addDiscount(businessId: businessId, name: 'Bad', type: 'invalid', value: 10),
        throwsA(isA<StateError>()),
      );
    });

    test('throws on zero value', () async {
      final service = DiscountService(
        firestore: FakeFirebaseFirestore(),
        connectivityService: ConnectivityService(),
      );
      expect(
        () => service.addDiscount(businessId: businessId, name: 'Zero', type: 'fixed', value: 0),
        throwsA(isA<StateError>()),
      );
    });

    test('throws on percentage > 100', () async {
      final service = DiscountService(
        firestore: FakeFirebaseFirestore(),
        connectivityService: ConnectivityService(),
      );
      expect(
        () => service.addDiscount(businessId: businessId, name: 'Over', type: 'percentage', value: 101),
        throwsA(isA<StateError>()),
      );
    });
  });

  group('DiscountService.updateDiscount (online)', () {
    test('updates discount fields', () async {
      final db = FakeFirebaseFirestore();
      final service = DiscountService(firestore: db, connectivityService: ConnectivityService());

      final docRef = db
          .collection('businesses').doc(businessId)
          .collection('discounts').doc('d1');
      await docRef.set({
        'name': 'Old', 'type': 'fixed', 'value': 5.0, 'active': true,
      });

      await service.updateDiscount(
        businessId: businessId,
        discountId: 'd1',
        name: 'New',
        type: 'percentage',
        value: 15.0,
      );

      final doc = await docRef.get();
      expect(doc.data()?['name'], 'New');
      expect(doc.data()?['type'], 'percentage');
      expect(doc.data()?['value'], 15.0);
    });
  });

  group('DiscountService.updateDiscount (offline)', () {
    test('enqueues update operation', () async {
      final db = FakeFirebaseFirestore();
      final service = DiscountService(firestore: db, connectivityService: OfflineConnectivity());

      await service.updateDiscount(
        businessId: businessId,
        discountId: 'd_off',
        name: 'X',
        type: 'fixed',
        value: 5.0,
      );

      expect(SyncQueue.pendingCount, 1);
      expect(SyncQueue.getPending().single.type, 'updateDiscount');
    });
  });

  group('DiscountService.deactivateDiscount', () {
    test('online: deactivates discount', () async {
      final db = FakeFirebaseFirestore();
      final service = DiscountService(firestore: db, connectivityService: ConnectivityService());

      await db.collection('businesses').doc(businessId)
          .collection('discounts').doc('d2')
          .set({'name': 'Activo', 'active': true});

      await service.deactivateDiscount(businessId: businessId, discountId: 'd2');

      final doc = await db
          .collection('businesses').doc(businessId)
          .collection('discounts').doc('d2').get();
      expect(doc.data()?['active'], false);
    });

    test('offline: enqueues deactivate operation', () async {
      final db = FakeFirebaseFirestore();
      final service = DiscountService(firestore: db, connectivityService: OfflineConnectivity());

      await service.deactivateDiscount(businessId: businessId, discountId: 'd_off');

      expect(SyncQueue.pendingCount, 1);
      expect(SyncQueue.getPending().single.type, 'deactivateDiscount');
    });
  });
}
