import 'dart:io';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:pos_flutter_firebase/core/adapters/type_adapters.dart';
import 'package:pos_flutter_firebase/core/offline/sync_queue.dart';
import 'package:pos_flutter_firebase/core/network/connectivity_service.dart';
import 'package:pos_flutter_firebase/features/pos/data/modifier_service.dart';

const businessId = 'test_business';

class OfflineConnectivity extends ConnectivityService {
  @override
  Future<bool> hasConnection() async => false;
}

void main() {
  late Directory tempDir;

  setUp(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    tempDir = await Directory.systemTemp.createTemp('pos-modifier-test-');
    Hive.init(tempDir.path);
    registerTypeAdapters();
    await Hive.openBox<List>('modifiers_v2');
    await Hive.openBox<Map>('syncQueue');
  });

  tearDown(() async {
    await Hive.close();
    if (await tempDir.exists()) await tempDir.delete(recursive: true);
  });

  group('ModifierService.addModifier (online)', () {
    test('creates modifier document and returns id', () async {
      final db = FakeFirebaseFirestore();
      final service = ModifierService(firestore: db, connectivityService: ConnectivityService());

      final id = await service.addModifier(
        businessId: businessId,
        name: 'Extra queso',
        price: 15.0,
      );

      final doc = await db
          .collection('businesses').doc(businessId)
          .collection('modifiers').doc(id).get();
      expect(doc.data()?['name'], 'Extra queso');
      expect(doc.data()?['price'], 15.0);
      expect(doc.data()?['active'], true);
    });
  });

  group('ModifierService.addModifier (offline)', () {
    test('enqueues operation and returns temp id', () async {
      final db = FakeFirebaseFirestore();
      final service = ModifierService(firestore: db, connectivityService: OfflineConnectivity());

      final id = await service.addModifier(businessId: businessId, name: 'Offline', price: 5.0);

      expect(id, startsWith('temp_'));
      expect(SyncQueue.pendingCount, 1);
      expect(SyncQueue.getPending().single.type, 'addModifier');
    });
  });

  group('ModifierService.addModifier (validation)', () {
    test('throws on empty name', () async {
      final service = ModifierService(
        firestore: FakeFirebaseFirestore(),
        connectivityService: ConnectivityService(),
      );
      expect(
        () => service.addModifier(businessId: businessId, name: '  ', price: 10),
        throwsA(isA<StateError>()),
      );
    });

    test('throws on negative price', () async {
      final service = ModifierService(
        firestore: FakeFirebaseFirestore(),
        connectivityService: ConnectivityService(),
      );
      expect(
        () => service.addModifier(businessId: businessId, name: 'Neg', price: -1),
        throwsA(isA<StateError>()),
      );
    });
  });

  group('ModifierService.updateModifier (online)', () {
    test('updates modifier fields', () async {
      final db = FakeFirebaseFirestore();
      final service = ModifierService(firestore: db, connectivityService: ConnectivityService());

      await db.collection('businesses').doc(businessId)
          .collection('modifiers').doc('m1')
          .set({'name': 'Old', 'price': 5.0, 'active': true});

      await service.updateModifier(
        businessId: businessId,
        modifierId: 'm1',
        name: 'New',
        price: 10.0,
      );

      final doc = await db
          .collection('businesses').doc(businessId)
          .collection('modifiers').doc('m1').get();
      expect(doc.data()?['name'], 'New');
      expect(doc.data()?['price'], 10.0);
    });
  });

  group('ModifierService.updateModifier (offline)', () {
    test('enqueues update operation', () async {
      final db = FakeFirebaseFirestore();
      final service = ModifierService(firestore: db, connectivityService: OfflineConnectivity());

      await service.updateModifier(businessId: businessId, modifierId: 'm_off', name: 'X', price: 1);

      expect(SyncQueue.pendingCount, 1);
      expect(SyncQueue.getPending().single.type, 'updateModifier');
    });
  });

  group('ModifierService.deactivateModifier', () {
    test('online: deactivates modifier', () async {
      final db = FakeFirebaseFirestore();
      final service = ModifierService(firestore: db, connectivityService: ConnectivityService());

      await db.collection('businesses').doc(businessId)
          .collection('modifiers').doc('m2')
          .set({'name': 'Activo', 'price': 0, 'active': true});

      await service.deactivateModifier(businessId: businessId, modifierId: 'm2');

      final doc = await db
          .collection('businesses').doc(businessId)
          .collection('modifiers').doc('m2').get();
      expect(doc.data()?['active'], false);
    });

    test('offline: enqueues deactivate operation', () async {
      final db = FakeFirebaseFirestore();
      final service = ModifierService(firestore: db, connectivityService: OfflineConnectivity());

      await service.deactivateModifier(businessId: businessId, modifierId: 'm_off');

      expect(SyncQueue.pendingCount, 1);
      expect(SyncQueue.getPending().single.type, 'deactivateModifier');
    });
  });
}
