import 'dart:io';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:pos_flutter_firebase/core/adapters/type_adapters.dart';
import 'package:pos_flutter_firebase/core/offline/sync_queue.dart';
import 'package:pos_flutter_firebase/core/network/connectivity_service.dart';
import 'package:pos_flutter_firebase/features/pos/data/category_service.dart';

const businessId = 'test_business';

class OfflineConnectivity extends ConnectivityService {
  @override
  Future<bool> hasConnection() async => false;
}

void main() {
  late Directory tempDir;

  setUp(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    tempDir = await Directory.systemTemp.createTemp('pos-category-test-');
    Hive.init(tempDir.path);
    registerTypeAdapters();
    await Hive.openBox<List>('categories_v2');
    await Hive.openBox<Map>('syncQueue');
  });

  tearDown(() async {
    await Hive.close();
    if (await tempDir.exists()) await tempDir.delete(recursive: true);
  });

  group('CategoryService.addCategory (online)', () {
    test('creates category document and returns id', () async {
      final db = FakeFirebaseFirestore();
      final service = CategoryService(firestore: db, connectivityService: ConnectivityService());

      final id = await service.addCategory(
        businessId: businessId,
        name: 'Bebidas',
        color: 0xFF2196F3,
      );

      expect(id, isNotEmpty);

      final doc = await db
          .collection('businesses').doc(businessId)
          .collection('categories').doc(id).get();
      expect(doc.exists, true);
      expect(doc.data()?['name'], 'Bebidas');
      expect(doc.data()?['color'], 0xFF2196F3);
      expect(doc.data()?['active'], true);
    });
  });

  group('CategoryService.addCategory (offline)', () {
    test('enqueues operation and returns temp id', () async {
      final db = FakeFirebaseFirestore();
      final service = CategoryService(firestore: db, connectivityService: OfflineConnectivity());

      final id = await service.addCategory(
        businessId: businessId,
        name: 'Offline Cat',
        color: 0xFF000000,
      );

      expect(id, startsWith('temp_'));
      expect(SyncQueue.pendingCount, 1);
      expect(SyncQueue.getPending().single.type, 'addCategory');
    });
  });

  group('CategoryService.addCategory (validation)', () {
    test('throws on empty name', () async {
      final service = CategoryService(
        firestore: FakeFirebaseFirestore(),
        connectivityService: ConnectivityService(),
      );

      expect(
        () => service.addCategory(businessId: businessId, name: '  ', color: 0xFF000000),
        throwsA(isA<StateError>()),
      );
    });
  });

  group('CategoryService.updateCategory (online)', () {
    test('updates category document', () async {
      final db = FakeFirebaseFirestore();
      final service = CategoryService(firestore: db, connectivityService: ConnectivityService());

      final docRef = db
          .collection('businesses').doc(businessId)
          .collection('categories').doc('cat1');
      await docRef.set({
        'businessId': businessId,
        'name': 'Old Name',
        'color': 0xFF000000,
        'active': true,
      });

      await service.updateCategory(
        businessId: businessId,
        categoryId: 'cat1',
        name: 'New Name',
        color: 0xFFFF0000,
      );

      final doc = await docRef.get();
      expect(doc.data()?['name'], 'New Name');
      expect(doc.data()?['color'], 0xFFFF0000);
    });

    test('updates category name in related products', () async {
      final db = FakeFirebaseFirestore();
      final service = CategoryService(firestore: db, connectivityService: ConnectivityService());

      final docRef = db
          .collection('businesses').doc(businessId)
          .collection('categories').doc('cat1');
      await docRef.set({
        'businessId': businessId,
        'name': 'Old',
        'color': 0xFF000000,
        'active': true,
      });

      await db.collection('businesses').doc(businessId)
          .collection('products').doc('p1')
          .set({'name': 'Prod', 'categoryId': 'cat1', 'categoryName': 'Old', 'active': true});
      await db.collection('businesses').doc(businessId)
          .collection('products').doc('p2')
          .set({'name': 'Prod2', 'categoryId': 'cat1', 'categoryName': 'Old', 'active': true});

      await service.updateCategory(
        businessId: businessId,
        categoryId: 'cat1',
        name: 'Updated',
        color: 0xFF000000,
      );

      final p1 = await db
          .collection('businesses').doc(businessId)
          .collection('products').doc('p1').get();
      expect(p1.data()?['categoryName'], 'Updated');

      final p2 = await db
          .collection('businesses').doc(businessId)
          .collection('products').doc('p2').get();
      expect(p2.data()?['categoryName'], 'Updated');
    });
  });

  group('CategoryService.updateCategory (offline)', () {
    test('enqueues update operation', () async {
      final db = FakeFirebaseFirestore();
      final service = CategoryService(firestore: db, connectivityService: OfflineConnectivity());

      await db.collection('businesses').doc(businessId)
          .collection('categories').doc('cat2')
          .set({'name': 'Old', 'color': 0, 'active': true});

      await service.updateCategory(
        businessId: businessId,
        categoryId: 'cat2',
        name: 'New',
        color: 0xFF000000,
      );

      expect(SyncQueue.pendingCount, 1);
      expect(SyncQueue.getPending().single.type, 'updateCategory');
    });
  });

  group('CategoryService.deactivateCategory (online)', () {
    test('deactivates category and removes categoryId from products', () async {
      final db = FakeFirebaseFirestore();
      final service = CategoryService(firestore: db, connectivityService: ConnectivityService());

      await db.collection('businesses').doc(businessId)
          .collection('categories').doc('cat3')
          .set({'name': 'ToDelete', 'color': 0, 'active': true});

      await db.collection('businesses').doc(businessId)
          .collection('products').doc('p1')
          .set({'name': 'Prod', 'categoryId': 'cat3', 'categoryName': 'ToDelete', 'active': true});

      await service.deactivateCategory(businessId: businessId, categoryId: 'cat3');

      final cat = await db
          .collection('businesses').doc(businessId)
          .collection('categories').doc('cat3').get();
      expect(cat.data()?['active'], false);

      final p1 = await db
          .collection('businesses').doc(businessId)
          .collection('products').doc('p1').get();
      expect(p1.data()?['categoryId'], isNull);
      expect(p1.data()?['categoryName'], isNull);
    });
  });

  group('CategoryService.deactivateCategory (offline)', () {
    test('enqueues deactivate operation', () async {
      final db = FakeFirebaseFirestore();
      final service = CategoryService(firestore: db, connectivityService: OfflineConnectivity());

      await service.deactivateCategory(businessId: businessId, categoryId: 'cat_off');

      expect(SyncQueue.pendingCount, 1);
      expect(SyncQueue.getPending().single.type, 'deactivateCategory');
    });
  });
}
