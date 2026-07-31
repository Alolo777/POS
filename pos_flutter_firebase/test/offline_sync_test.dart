import 'dart:io';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:pos_flutter_firebase/shared/models/cart_item.dart';
import 'package:pos_flutter_firebase/shared/models/product.dart';
import 'package:pos_flutter_firebase/shared/models/product_stock.dart';
import 'package:pos_flutter_firebase/core/adapters/type_adapters.dart';
import 'package:pos_flutter_firebase/core/offline/local_database.dart';
import 'package:pos_flutter_firebase/core/offline/sync_queue.dart';
import 'package:pos_flutter_firebase/core/offline/sync_service.dart';
import 'package:pos_flutter_firebase/core/network/connectivity_service.dart';
import 'package:pos_flutter_firebase/features/sales/data/sale_service.dart';
import 'package:pos_flutter_firebase/features/inventory/data/stock_service.dart';

const businessId = 'test_business';
const storeId = 'test_store';
const employeeId = 'test_employee';
const shiftId = 'test_shift';
const testUid = 'test_user';

class OfflineConnectivityService extends ConnectivityService {
  @override
  Future<bool> hasConnection() async => false;
}

Product _product(String id, String name, double price, double stock) {
  return Product(
    id: id,
    name: name,
    categoryId: null,
    categoryName: null,
    sellBy: 'unit',
    price: price,
    cost: 0,
    ref: 'REF-$id',
    trackStock: true,
    stockQuantity: stock,
    lowStockAlertQuantity: 0,
    presentationType: 'shape',
    presentationShape: 'square',
    presentationColor: 0xFF9E9E9E,
    imageUrl: null,
    localImagePath: null,
    active: true,
  );
}

Future<void> _openHiveBoxes() async {
  registerTypeAdapters();
  await Hive.openBox<List>('productStock_v2');
  await Hive.openBox<Map>('syncQueue');
}

void main() {
  late Directory tempDir;

  setUp(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    tempDir = await Directory.systemTemp.createTemp('pos-offline-test-');
    Hive.init(tempDir.path);
    await _openHiveBoxes();
  });

  tearDown(() async {
    await Hive.close();
    if (await tempDir.exists()) await tempDir.delete(recursive: true);
  });

  group('offline stock validation', () {
    test('throws before enqueueing when cached stock is insufficient', () async {
      await LocalDatabase.cacheProductStock(businessId, [
        ProductStock(productId: 'p1', storeId: storeId, stockQuantity: 1.0, lowStockAlertQuantity: 0.0),
      ]);
      final service = SaleService(
        firestore: FakeFirebaseFirestore(),
        connectivityService: OfflineConnectivityService(),
        stockService: StockService(firestore: FakeFirebaseFirestore()),
      );

      expect(
        () => service.createSale(
          businessId: businessId,
          storeId: storeId,
          employeeId: employeeId,
          shiftId: shiftId,
          items: [CartItem(product: _product('p1', 'Cafe', 10, 1), quantity: 2)],
          subtotal: 20,
          discountTotal: 0,
          total: 20,
          paymentMethod: 'cash',
          createdByUid: testUid,
        ),
        throwsA(isA<StateError>()),
      );
      expect(SyncQueue.pendingCount, 0);
    });

    test('enqueueing offline sale decrements cached stock', () async {
      await LocalDatabase.cacheProductStock(businessId, [
        ProductStock(productId: 'p1', storeId: storeId, stockQuantity: 3.0, lowStockAlertQuantity: 0.0),
      ]);
      final service = SaleService(
        firestore: FakeFirebaseFirestore(),
        connectivityService: OfflineConnectivityService(),
        stockService: StockService(firestore: FakeFirebaseFirestore()),
      );

      final folio = await service.createSale(
        businessId: businessId,
        storeId: storeId,
        employeeId: employeeId,
        shiftId: shiftId,
        items: [CartItem(product: _product('p1', 'Cafe', 10, 3), quantity: 2)],
        subtotal: 20,
        discountTotal: 0,
        total: 20,
        paymentMethod: 'cash',
        createdByUid: testUid,
      );

      expect(folio, startsWith('OFFLINE-'));
      expect(SyncQueue.pendingCount, 1);
      final stock = LocalDatabase.getCachedProductStock(businessId)!;
      expect(stock.single.stockQuantity, 1.0);
    });
  });

  group('SyncQueue retry limits', () {
    test('marks operation failed after max retries and stores last error', () async {
      await SyncQueue.enqueue(type: 'broken', data: {'value': 1});
      final id = SyncQueue.getPending().single.id;

      for (var i = 0; i < 5; i++) {
        await SyncQueue.markFailed(id, error: 'boom');
      }

      expect(SyncQueue.pendingCount, 0);
      expect(SyncQueue.failedCount, 1);
      final failed = SyncQueue.getFailed().single;
      expect(failed.retries, 5);
      expect(failed.lastError, 'boom');
      expect(failed.failedAt, isNotNull);
    });
  });

  group('SyncService', () {
    test('completes successful operations', () async {
      await SyncQueue.enqueue(type: 'ok', data: {'value': 1});
      final service = SyncService(
        autoStart: false,
        handlers: {'ok': (_) async {}},
      );

      await service.processQueue();

      expect(SyncQueue.pendingCount, 0);
      expect(SyncQueue.getAll(), isEmpty);
      service.dispose();
    });

    test('does not drop unknown operation types silently', () async {
      await SyncQueue.enqueue(type: 'missingHandler', data: {'value': 1});
      final service = SyncService(autoStart: false, handlers: const {});

      for (var i = 0; i < 5; i++) {
        await service.processQueue();
      }

      expect(SyncQueue.pendingCount, 0);
      expect(SyncQueue.failedCount, 1);
      expect(SyncQueue.getFailed().single.lastError, contains('No hay handler registrado'));
      service.dispose();
    });
  });
}
