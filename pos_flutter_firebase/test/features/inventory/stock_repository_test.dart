import 'dart:io';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:pos_flutter_firebase/shared/models/product_stock.dart';
import 'package:pos_flutter_firebase/core/adapters/type_adapters.dart';
import 'package:pos_flutter_firebase/core/offline/local_database.dart';
import 'package:pos_flutter_firebase/features/inventory/data/stock_service.dart';

const businessId = 'test_business';
const storeId = 'test_store';

void main() {
  late Directory tempDir;

  setUp(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    tempDir = await Directory.systemTemp.createTemp('pos-stock-test-');
    Hive.init(tempDir.path);
    registerTypeAdapters();
    await Hive.openBox<List>('productStock_v2');
  });

  tearDown(() async {
    await Hive.close();
    if (await tempDir.exists()) await tempDir.delete(recursive: true);
  });

  group('StockService.getCachedStock', () {
    test('returns null when no cached data', () {
      final service = StockService(firestore: FakeFirebaseFirestore());
      expect(service.getCachedStock(businessId), isNull);
    });

    test('returns cached stock data', () async {
      await LocalDatabase.cacheProductStock(businessId, [
        ProductStock(productId: 'p1', storeId: storeId, stockQuantity: 10.0, lowStockAlertQuantity: 2.0),
        ProductStock(productId: 'p2', storeId: storeId, stockQuantity: 5.0, lowStockAlertQuantity: 1.0),
      ]);

      final service = StockService(firestore: FakeFirebaseFirestore());
      final cached = service.getCachedStock(businessId);
      expect(cached, isNotNull);
      expect(cached!.length, 2);
      expect(cached['p1']!.stockQuantity, 10.0);
      expect(cached['p2']!.stockQuantity, 5.0);
    });
  });

  group('StockService.applyLocalStockDelta', () {
    test('decrements cached stock correctly', () async {
      await LocalDatabase.cacheProductStock(businessId, [
        ProductStock(productId: 'p1', storeId: storeId, stockQuantity: 10.0, lowStockAlertQuantity: 2.0),
      ]);

      final service = StockService(firestore: FakeFirebaseFirestore());
      await service.applyLocalStockDelta(businessId: businessId, productId: 'p1', delta: -3.0);

      final cached = LocalDatabase.getCachedProductStock(businessId)!;
      expect(cached.single.stockQuantity, 7.0);
    });

    test('increments cached stock correctly', () async {
      await LocalDatabase.cacheProductStock(businessId, [
        ProductStock(productId: 'p1', storeId: storeId, stockQuantity: 5.0, lowStockAlertQuantity: 1.0),
      ]);

      final service = StockService(firestore: FakeFirebaseFirestore());
      await service.applyLocalStockDelta(businessId: businessId, productId: 'p1', delta: 2.5);

      final cached = LocalDatabase.getCachedProductStock(businessId)!;
      expect(cached.single.stockQuantity, 7.5);
    });

    test('clamps to zero when delta would make stock negative', () async {
      await LocalDatabase.cacheProductStock(businessId, [
        ProductStock(productId: 'p1', storeId: storeId, stockQuantity: 3.0, lowStockAlertQuantity: 1.0),
      ]);

      final service = StockService(firestore: FakeFirebaseFirestore());
      await service.applyLocalStockDelta(businessId: businessId, productId: 'p1', delta: -10.0);

      final cached = LocalDatabase.getCachedProductStock(businessId)!;
      expect(cached.single.stockQuantity, 0.0);
    });

    test('does nothing when product is not in cache', () async {
      final service = StockService(firestore: FakeFirebaseFirestore());
      await service.applyLocalStockDelta(businessId: businessId, productId: 'unknown', delta: -5.0);
      expect(LocalDatabase.getCachedProductStock(businessId), isNull);
    });
  });

  group('StockService.watchStockByStore', () {
    test('emits stock data from Firestore', () async {
      final db = FakeFirebaseFirestore();
      final service = StockService(firestore: db);

      await db
          .collection('businesses').doc(businessId)
          .collection('products').doc('p1')
          .set({'name': 'Producto 1', 'active': true});
      await db
          .collection('businesses').doc(businessId)
          .collection('products').doc('p1')
          .collection('stockByStore').doc(storeId)
          .set({
        'businessId': businessId,
        'storeId': storeId,
        'productId': 'p1',
        'stockQuantity': 15.0,
        'lowStockAlertQuantity': 3.0,
      });

      final stream = service.watchStockByStore(businessId: businessId, storeId: storeId);
      final result = await stream.first;
      expect(result, isNotEmpty);
      expect(result['p1']!.stockQuantity, 15.0);
    });

    test('includes multiple products in stock map', () async {
      final db = FakeFirebaseFirestore();
      final service = StockService(firestore: db);

      final batch = db.batch();
      for (final pid in ['p1', 'p2']) {
        batch.set(
          db
              .collection('businesses').doc(businessId)
              .collection('products').doc(pid),
          {'name': 'Producto $pid', 'active': true},
        );
        batch.set(
          db
              .collection('businesses').doc(businessId)
              .collection('products').doc(pid)
              .collection('stockByStore').doc(storeId),
          {
            'businessId': businessId,
            'storeId': storeId,
            'productId': pid,
            'stockQuantity': pid == 'p1' ? 10.0 : 20.0,
            'lowStockAlertQuantity': 2.0,
          },
        );
      }
      await batch.commit();

      final stream = service.watchStockByStore(businessId: businessId, storeId: storeId);
      final result = await stream.firstWhere((m) => m.length >= 2);
      expect(result.length, 2);
      expect(result['p1']!.stockQuantity, 10.0);
      expect(result['p2']!.stockQuantity, 20.0);
    });
  });
}
