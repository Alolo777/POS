import 'dart:io';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:pos_flutter_firebase/shared/models/cart_item.dart';
import 'package:pos_flutter_firebase/shared/models/product.dart';
import 'package:pos_flutter_firebase/shared/models/product_stock.dart';
import 'package:pos_flutter_firebase/core/adapters/type_adapters.dart';
import 'package:pos_flutter_firebase/core/offline/local_database.dart';
import 'package:pos_flutter_firebase/core/offline/sync_handlers.dart';
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

  group('SyncQueue recovery', () {
    test('resets operations stuck in syncing back to pending', () async {
      await SyncQueue.enqueue(type: 'createSale', data: {'x': 1});
      final id = SyncQueue.getPending().single.id;
      await SyncQueue.markSyncing(id);

      expect(SyncQueue.getPending(), isEmpty);

      await SyncQueue.recoverStuckOps();

      expect(SyncQueue.pendingCount, 1);
      expect(SyncQueue.getPending().single.id, id);
    });

    test('keeps pending and failed operations untouched', () async {
      await SyncQueue.enqueue(type: 'a', data: {'v': 1});
      await SyncQueue.enqueue(type: 'b', data: {'v': 2});
      final pendingId = SyncQueue.getPending().first.id;
      final failedId = SyncQueue.getPending().last.id;
      for (var i = 0; i < 5; i++) {
        await SyncQueue.markFailed(failedId, error: 'boom');
      }

      await SyncQueue.recoverStuckOps();

      expect(SyncQueue.getPending().single.id, pendingId);
      expect(SyncQueue.getFailed().single.id, failedId);
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

  group('sync idempotency', () {
    test('createSale handler applied twice creates one sale and one stock decrement', () async {
      final firestore = FakeFirebaseFirestore();
      overrideSyncFirestore(firestore);

      await firestore.collection('businesses').doc(businessId)
          .collection('products').doc('p1')
          .collection('stockByStore').doc(storeId)
          .set({'stockQuantity': 10.0});

      final handlers = createSyncHandlers();
      final data = {
        'businessId': businessId,
        'storeId': storeId,
        'employeeId': employeeId,
        'shiftId': shiftId,
        'items': [
          {
            'productId': 'p1',
            'name': 'Cafe',
            'quantity': 2.0,
            'subtotal': 20.0,
            'sellBy': 'unit',
            'pieceSwaps': <Map<String, dynamic>>[],
          },
        ],
        'subtotal': 20.0,
        'discountTotal': 0.0,
        'total': 20.0,
        'paymentMethod': 'cash',
        'cashReceived': 20.0,
        'changeDue': 0.0,
        'createdByUid': testUid,
        'folio': 'OFFLINE-123',
        'createdAt': DateTime.now().toIso8601String(),
        'clientOpId': 'op-1',
      };

      await handlers['createSale']!(data);
      await handlers['createSale']!(data);

      final sales = await firestore
          .collection('businesses').doc(businessId).collection('sales').get();
      expect(sales.docs.length, 1);

      final stock = await firestore.collection('businesses').doc(businessId)
          .collection('products').doc('p1').collection('stockByStore').doc(storeId).get();
      expect(stock.data()!['stockQuantity'], 8.0);

      final movements = await firestore.collection('businesses').doc(businessId)
          .collection('inventoryMovements').get();
      expect(movements.docs.length, 1);

      final counter = await firestore.collection('businesses').doc(businessId)
          .collection('counters').doc('sales').get();
      expect(counter.data()!['nextSaleNumber'], 2);
    });

    test('cancelSale handler applied twice creates one refund and restores stock once', () async {
      final firestore = FakeFirebaseFirestore();
      overrideSyncFirestore(firestore);

      await firestore.collection('businesses').doc(businessId)
          .collection('products').doc('p1')
          .collection('stockByStore').doc(storeId)
          .set({'stockQuantity': 8.0});
      await firestore.collection('businesses').doc(businessId)
          .collection('sales').doc('sale-1')
          .set({
            'businessId': businessId,
            'storeId': storeId,
            'employeeId': employeeId,
            'shiftId': shiftId,
            'folio': 'T-000001',
            'items': [
              {
                'productId': 'p1',
                'name': 'Cafe',
                'quantity': 2.0,
                'subtotal': 20.0,
                'sellBy': 'unit',
                'pieceSwaps': <Map<String, dynamic>>[],
              },
            ],
            'total': 20.0,
            'paymentMethod': 'cash',
            'status': 'completed',
            'type': 'sale',
          });

      final handlers = createSyncHandlers();
      final data = {
        'businessId': businessId,
        'saleId': 'sale-1',
        'storeId': storeId,
        'returnItems': [
          {
            'productId': 'p1',
            'name': 'Cafe',
            'quantity': 2.0,
            'subtotal': 20.0,
            'sellBy': 'unit',
            'pieceSwaps': <Map<String, dynamic>>[],
          },
        ],
        'returnInventory': true,
        'reason': 'test',
        'refundEmployeeId': employeeId,
        'refundShiftId': shiftId,
        'refundId': 'OFFLINE-REFUND-1',
        'createdAt': DateTime.now().toIso8601String(),
        'clientOpId': 'refund-op-1',
      };

      await handlers['cancelSale']!(data);
      await handlers['cancelSale']!(data);

      final sales = await firestore
          .collection('businesses').doc(businessId).collection('sales').get();
      expect(sales.docs.length, 2);
      final refunds = sales.docs.where((d) => d.data()['type'] == 'refund');
      expect(refunds.length, 1);

      final stock = await firestore.collection('businesses').doc(businessId)
          .collection('products').doc('p1').collection('stockByStore').doc(storeId).get();
      expect(stock.data()!['stockQuantity'], 10.0);

      final original = await firestore.collection('businesses').doc(businessId)
          .collection('sales').doc('sale-1').get();
      expect(original.data()!['status'], 'cancelled');
    });
  });

  group('sync adjustStock handler', () {
    test('applies adjustment transactionally with movement', () async {
      final firestore = FakeFirebaseFirestore();
      overrideSyncFirestore(firestore);

      await firestore.collection('businesses').doc(businessId)
          .collection('products').doc('p1').set({'name': 'Pollo', 'businessId': businessId});
      await firestore.collection('businesses').doc(businessId)
          .collection('products').doc('p1').collection('stockByStore').doc(storeId)
          .set({'stockQuantity': 5.0, 'stock': 5});

      final handlers = createSyncHandlers();
      final data = {
        'businessId': businessId,
        'storeId': storeId,
        'productId': 'p1',
        'newQuantity': 8.0,
        'reason': 'Conteo',
        'employeeId': employeeId,
      };

      await handlers['adjustStock']!(data);

      final stock = await firestore.collection('businesses').doc(businessId)
          .collection('products').doc('p1').collection('stockByStore').doc(storeId).get();
      expect(stock.data()!['stockQuantity'], 8.0);
      expect(stock.data()!['stock'], 8);

      final movements = await firestore.collection('businesses').doc(businessId)
          .collection('inventoryMovements').get();
      expect(movements.docs.length, 1);
      final m = movements.docs.single.data();
      expect(m['type'], 'adjustment');
      expect(m['previousQuantity'], 5.0);
      expect(m['newQuantity'], 8.0);
      expect(m['difference'], 3.0);
      expect(m['productName'], 'Pollo');
      expect(m['reason'], 'Conteo');
    });

    test('applies sequential adjustments reading latest stock', () async {
      final firestore = FakeFirebaseFirestore();
      overrideSyncFirestore(firestore);

      await firestore.collection('businesses').doc(businessId)
          .collection('products').doc('p1').set({'name': 'Pollo', 'businessId': businessId});
      await firestore.collection('businesses').doc(businessId)
          .collection('products').doc('p1').collection('stockByStore').doc(storeId)
          .set({'stockQuantity': 10.0});

      final handlers = createSyncHandlers();
      final data = {
        'businessId': businessId,
        'storeId': storeId,
        'productId': 'p1',
        'newQuantity': 15.0,
        'reason': 'Ajuste manual',
        'employeeId': employeeId,
      };

      await handlers['adjustStock']!(data);
      data['newQuantity'] = 12.0;
      await handlers['adjustStock']!(data);

      final movements = await firestore.collection('businesses').doc(businessId)
          .collection('inventoryMovements').get();
      expect(movements.docs.length, 2);
      final ordered = movements.docs.map((d) => d.data()).toList()
        ..sort((a, b) => (a['previousQuantity'] as num).compareTo((b['previousQuantity'] as num)));
      expect(ordered[0]['previousQuantity'], 10.0);
      expect(ordered[0]['newQuantity'], 15.0);
      expect(ordered[1]['previousQuantity'], 15.0);
      expect(ordered[1]['newQuantity'], 12.0);
    });
  });
}
