import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:pos_flutter_firebase/core/adapters/type_adapters.dart';
import 'package:pos_flutter_firebase/features/butcher/data/butcher_stock_service.dart';

const businessId = 'test_business';
const storeId = 'test_store';

void main() {
  late Directory tempDir;

  setUp(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    tempDir = await Directory.systemTemp.createTemp('pos-butcher-stock-test-');
    Hive.init(tempDir.path);
    registerTypeAdapters();
    await Hive.openBox<List>('productStock_v2');
  });

  tearDown(() async {
    await Hive.close();
    if (await tempDir.exists()) await tempDir.delete(recursive: true);
  });

  group('ButcherStockService.addStockFromYields', () {
    test('adds stock to products matching section names', () async {
      final db = FakeFirebaseFirestore();
      final service = ButcherStockService(firestore: db);

      await db.collection('businesses').doc(businessId)
          .collection('products').doc('p1').set({
        'name': 'Pechuga',
        'trackStock': true,
        'active': true,
      });
      await db.collection('businesses').doc(businessId)
          .collection('products').doc('p2').set({
        'name': 'Pierna',
        'trackStock': true,
        'active': true,
      });

      await service.addStockFromYields(
        businessId: businessId,
        storeId: storeId,
        yields: [
          (name: 'Pechuga', weight: 10.0, percentage: 50.0),
          (name: 'Pierna', weight: 5.0, percentage: 50.0),
        ],
      );

      final stock1 = await db
          .collection('businesses').doc(businessId)
          .collection('products').doc('p1')
          .collection('stockByStore').doc(storeId).get();
      expect(stock1.data()?['stockQuantity'], 10.0);

      final stock2 = await db
          .collection('businesses').doc(businessId)
          .collection('products').doc('p2')
          .collection('stockByStore').doc(storeId).get();
      expect(stock2.data()?['stockQuantity'], 5.0);
    });

    test('skips products that do not track stock', () async {
      final db = FakeFirebaseFirestore();
      final service = ButcherStockService(firestore: db);

      await db.collection('businesses').doc(businessId)
          .collection('products').doc('p1').set({
        'name': 'Pechuga',
        'trackStock': false,
        'active': true,
      });

      await service.addStockFromYields(
        businessId: businessId,
        storeId: storeId,
        yields: [(name: 'Pechuga', weight: 10.0, percentage: 100.0)],
      );

      final stock = await db
          .collection('businesses').doc(businessId)
          .collection('products').doc('p1')
          .collection('stockByStore').doc(storeId).get();
      expect(stock.exists, false);
    });
  });

  group('ButcherStockService.subtractStockFromYields', () {
    test('subtracts stock from matching products', () async {
      final db = FakeFirebaseFirestore();
      final service = ButcherStockService(firestore: db);

      await db.collection('businesses').doc(businessId)
          .collection('products').doc('p1').set({
        'name': 'Pechuga',
        'trackStock': true,
        'active': true,
      });
      final stockRef = db
          .collection('businesses').doc(businessId)
          .collection('products').doc('p1')
          .collection('stockByStore').doc(storeId);
      await stockRef.set({'stockQuantity': 20.0});

      await service.subtractStockFromYields(
        businessId: businessId,
        storeId: storeId,
        yields: [(name: 'Pechuga', weight: 5.0, percentage: 100.0)],
      );

      final stock = await stockRef.get();
      expect(stock.data()?['stockQuantity'], 15.0);
    });
  });

  group('ButcherStockService.getPendingStockBySection', () {
    test('returns pending stock from active receipts', () async {
      final db = FakeFirebaseFirestore();
      final service = ButcherStockService(firestore: db);

      final receiptRef = db
          .collection('businesses').doc(businessId)
          .collection('butcherReceipts').doc('r1');
      await receiptRef.set({
        'storeId': storeId,
        'status': 'active',
        'yields': [
          {'name': 'Pechuga', 'weight': 10.0, 'percentage': 50.0},
          {'name': 'Pierna', 'weight': 5.0, 'percentage': 25.0},
        ],
        'consumedSections': ['Pierna'],
        'createdAt': Timestamp.fromDate(DateTime.now().subtract(const Duration(days: 1))),
      });

      final pending = await service.getPendingStockBySection(businessId, storeId: storeId);

      expect(pending.length, 1);
      expect(pending[0].name, 'Pechuga');
      expect(pending[0].totalWeight, 10.0);
    });

    test('returns empty when all sections consumed', () async {
      final db = FakeFirebaseFirestore();
      final service = ButcherStockService(firestore: db);

      await db.collection('businesses').doc(businessId)
          .collection('butcherReceipts').doc('r1').set({
        'storeId': storeId,
        'status': 'active',
        'yields': [{'name': 'Pechuga', 'weight': 5.0, 'percentage': 100.0}],
        'consumedSections': ['Pechuga'],
        'createdAt': Timestamp.fromDate(DateTime.now().subtract(const Duration(days: 1))),
      });

      final pending = await service.getPendingStockBySection(businessId, storeId: storeId);
      expect(pending, isEmpty);
    });
  });

  group('ButcherStockService.getSectionRealData', () {
    test('returns price, stock and sales for each section', () async {
      final db = FakeFirebaseFirestore();
      final service = ButcherStockService(firestore: db);

      await db.collection('businesses').doc(businessId)
          .collection('products').doc('p1').set({
        'name': 'Pechuga',
        'price': 45.0,
        'trackStock': true,
        'active': true,
      });
      await db.collection('businesses').doc(businessId)
          .collection('products').doc('p1')
          .collection('stockByStore').doc(storeId).set({
        'storeId': storeId,
        'productId': 'p1',
        'stockQuantity': 15.0,
      });

      await db.collection('businesses').doc(businessId)
          .collection('sales').add({
        'storeId': storeId,
        'items': [
          {'name': 'Pechuga', 'quantity': 3.0},
        ],
        'createdAt': Timestamp.now(),
      });

      final data = await service.getSectionRealData(
        businessId: businessId,
        storeId: storeId,
        sectionNames: ['Pechuga', 'Inexistente'],
      );

      final pechuga = data['Pechuga'];
      expect(pechuga?.price, 45.0);
      expect(pechuga?.stock, 15.0);
      expect(pechuga?.sales, 3.0);

      final inexistente = data['Inexistente'];
      expect(inexistente?.price, 0.0);
      expect(inexistente?.stock, 0.0);
      expect(inexistente?.sales, 0.0);
    });
  });

  group('ButcherStockService.clearStoreStock', () {
    test('resets stock to zero and clears pending', () async {
      final db = FakeFirebaseFirestore();
      final service = ButcherStockService(firestore: db);

      await db.collection('businesses').doc(businessId)
          .collection('products').doc('p1').set({
        'name': 'Prod1',
        'trackStock': true,
        'active': true,
      });
      final stockRef = db
          .collection('businesses').doc(businessId)
          .collection('products').doc('p1')
          .collection('stockByStore').doc(storeId);
      await stockRef.set({'stockQuantity': 50.0});

      await service.clearStoreStock(businessId: businessId, storeId: storeId);

      final stock = await stockRef.get();
      expect(stock.data()?['stockQuantity'], 0.0);
    });
  });
}
