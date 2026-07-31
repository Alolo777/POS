import 'dart:io';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:pos_flutter_firebase/shared/models/product.dart';
import 'package:pos_flutter_firebase/core/adapters/type_adapters.dart';
import 'package:pos_flutter_firebase/core/offline/local_database.dart';
import 'package:pos_flutter_firebase/core/offline/sync_queue.dart';
import 'package:pos_flutter_firebase/core/network/connectivity_service.dart';
import 'package:pos_flutter_firebase/features/products/data/product_service.dart';

const businessId = 'test_business';
const storeId = 'test_store';

class OfflineConnectivity extends ConnectivityService {
  @override
  Future<bool> hasConnection() async => false;
}

void main() {
  late Directory tempDir;

  setUp(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    tempDir = await Directory.systemTemp.createTemp('pos-product-test-');
    Hive.init(tempDir.path);
    registerTypeAdapters();
    await Hive.openBox<List>('products_v2');
    await Hive.openBox<List>('productStock_v2');
    await Hive.openBox<Map>('syncQueue');
  });

  tearDown(() async {
    await Hive.close();
    if (await tempDir.exists()) await tempDir.delete(recursive: true);
  });

  group('ProductService.addProduct (online)', () {
    test('online: creates product and stock documents', () async {
      final db = FakeFirebaseFirestore();
      final service = ProductService(firestore: db, connectivityService: ConnectivityService());

      await service.addProduct(
        businessId: businessId,
        storeId: storeId,
        name: 'Cafe Americano',
        categoryId: 'cat1',
        categoryName: 'Bebidas',
        sellBy: 'unit',
        price: 35.0,
        cost: 15.0,
        ref: '000001',
        trackStock: true,
        stockQuantity: 50.0,
        lowStockAlertQuantity: 10.0,
        presentationType: 'shape',
        presentationShape: 'circle',
        presentationColor: 0xFF795548,
      );

      final products = await db
          .collection('businesses').doc(businessId)
          .collection('products').get();
      expect(products.docs.length, 1);

      final data = products.docs.first.data();
      expect(data['name'], 'Cafe Americano');
      expect(data['price'], 35.0);
      expect(data['cost'], 15.0);
      expect(data['ref'], '000001');
      expect(data['active'], true);

      final stocks = await db
          .collection('businesses').doc(businessId)
          .collection('products').doc(products.docs.first.id)
          .collection('stockByStore').get();
      expect(stocks.docs.length, 1);
      expect(stocks.docs.first.data()['stockQuantity'], 50.0);
    });

    test('online: creates REF lock and updates counter', () async {
      final db = FakeFirebaseFirestore();
      final service = ProductService(firestore: db, connectivityService: ConnectivityService());

      await db.collection('businesses').doc(businessId)
          .collection('counters').doc('products')
          .set({'nextRefNumber': 1});

      await service.addProduct(
        businessId: businessId,
        storeId: storeId,
        name: 'Producto',
        categoryId: null,
        categoryName: null,
        sellBy: 'unit',
        price: 10.0,
        cost: 5.0,
        ref: '000001',
        trackStock: false,
        stockQuantity: 0,
        lowStockAlertQuantity: 0,
        presentationType: 'shape',
        presentationShape: 'square',
        presentationColor: 0xFF9E9E9E,
      );

      final refLock = await db
          .collection('businesses').doc(businessId)
          .collection('productRefs').doc('000001').get();
      expect(refLock.exists, true);

      final counter = await db
          .collection('businesses').doc(businessId)
          .collection('counters').doc('products').get();
      expect(counter.data()?['nextRefNumber'], 2);
    });

    test('online: throws on duplicate REF', () async {
      final db = FakeFirebaseFirestore();
      final service = ProductService(firestore: db, connectivityService: ConnectivityService());

      await db.collection('businesses').doc(businessId)
          .collection('productRefs').doc('000001')
          .set({'productId': 'existing', 'ref': '000001'});

      expect(
        () => service.addProduct(
          businessId: businessId,
          storeId: storeId,
          name: 'Duplicado',
          categoryId: null,
          categoryName: null,
          sellBy: 'unit',
          price: 10.0,
          cost: 5.0,
          ref: '000001',
          trackStock: false,
          stockQuantity: 0,
          lowStockAlertQuantity: 0,
          presentationType: 'shape',
          presentationShape: 'square',
          presentationColor: 0xFF9E9E9E,
        ),
        throwsA(isA<StateError>()),
      );
    });
  });

  group('ProductService.addProduct (offline)', () {
    test('offline: enqueues operation when there is no connection', () async {
      final db = FakeFirebaseFirestore();
      final service = ProductService(firestore: db, connectivityService: OfflineConnectivity());

      await service.addProduct(
        businessId: businessId,
        storeId: storeId,
        name: 'Cafe Offline',
        categoryId: null,
        categoryName: null,
        sellBy: 'unit',
        price: 30.0,
        cost: 12.0,
        ref: '000002',
        trackStock: true,
        stockQuantity: 20.0,
        lowStockAlertQuantity: 5.0,
        presentationType: 'shape',
        presentationShape: 'circle',
        presentationColor: 0xFF795548,
      );

      expect(SyncQueue.pendingCount, 1);
      final pending = SyncQueue.getPending().single;
      expect(pending.type, 'addProduct');
      expect(pending.data['name'], 'Cafe Offline');
    });
  });

  group('ProductService.addProduct (validation)', () {
    test('throws on empty name', () async {
      final service = ProductService(
        firestore: FakeFirebaseFirestore(),
        connectivityService: ConnectivityService(),
      );

      expect(
        () => service.addProduct(
          businessId: businessId,
          storeId: storeId,
          name: '  ',
          categoryId: null,
          categoryName: null,
          sellBy: 'unit',
          price: 10.0,
          cost: 5.0,
          ref: '000003',
          trackStock: false,
          stockQuantity: 0,
          lowStockAlertQuantity: 0,
          presentationType: 'shape',
          presentationShape: 'square',
          presentationColor: 0xFF9E9E9E,
        ),
        throwsA(isA<StateError>()),
      );
    });

    test('throws on empty REF', () async {
      final service = ProductService(
        firestore: FakeFirebaseFirestore(),
        connectivityService: ConnectivityService(),
      );

      expect(
        () => service.addProduct(
          businessId: businessId,
          storeId: storeId,
          name: 'Test',
          categoryId: null,
          categoryName: null,
          sellBy: 'unit',
          price: 10.0,
          cost: 5.0,
          ref: '  ',
          trackStock: false,
          stockQuantity: 0,
          lowStockAlertQuantity: 0,
          presentationType: 'shape',
          presentationShape: 'square',
          presentationColor: 0xFF9E9E9E,
        ),
        throwsA(isA<StateError>()),
      );
    });

    test('throws on negative price', () async {
      final service = ProductService(
        firestore: FakeFirebaseFirestore(),
        connectivityService: ConnectivityService(),
      );

      expect(
        () => service.addProduct(
          businessId: businessId,
          storeId: storeId,
          name: 'Test',
          categoryId: null,
          categoryName: null,
          sellBy: 'unit',
          price: -1.0,
          cost: 5.0,
          ref: '000005',
          trackStock: false,
          stockQuantity: 0,
          lowStockAlertQuantity: 0,
          presentationType: 'shape',
          presentationShape: 'square',
          presentationColor: 0xFF9E9E9E,
        ),
        throwsA(isA<StateError>()),
      );
    });

    test('throws on fractional quantity for unit product', () async {
      final service = ProductService(
        firestore: FakeFirebaseFirestore(),
        connectivityService: ConnectivityService(),
      );

      expect(
        () => service.addProduct(
          businessId: businessId,
          storeId: storeId,
          name: 'Test',
          categoryId: null,
          categoryName: null,
          sellBy: 'unit',
          price: 10.0,
          cost: 5.0,
          ref: '000006',
          trackStock: true,
          stockQuantity: 2.5,
          lowStockAlertQuantity: 1.0,
          presentationType: 'shape',
          presentationShape: 'square',
          presentationColor: 0xFF9E9E9E,
        ),
        throwsA(isA<StateError>()),
      );
    });
  });

  group('ProductService.updateProduct (online)', () {
    test('online: updates product fields', () async {
      final db = FakeFirebaseFirestore();
      final service = ProductService(firestore: db, connectivityService: ConnectivityService());

      final productRef = db
          .collection('businesses').doc(businessId)
          .collection('products').doc('p1');

      await productRef.set({
        'name': 'Original',
        'price': 10.0,
        'cost': 5.0,
        'ref': '000010',
        'trackStock': false,
        'active': true,
      });

      final product = Product(
        id: 'p1',
        name: 'Original',
        categoryId: null,
        categoryName: null,
        sellBy: 'unit',
        price: 10.0,
        cost: 5.0,
        ref: '000010',
        trackStock: false,
        stockQuantity: 0,
        lowStockAlertQuantity: 0,
        presentationType: 'shape',
        presentationShape: 'square',
        presentationColor: 0xFF9E9E9E,
        imageUrl: null,
        localImagePath: null,
        active: true,
      );

      await service.updateProduct(
        businessId: businessId,
        storeId: storeId,
        product: product,
        name: 'Updated',
        categoryId: 'cat2',
        categoryName: 'Nueva Cat',
        sellBy: 'weight',
        price: 15.0,
        cost: 8.0,
        ref: '000010',
        trackStock: true,
        stockQuantity: 100.0,
        lowStockAlertQuantity: 20.0,
        presentationType: 'shape',
        presentationShape: 'circle',
        presentationColor: 0xFF000000,
      );

      final updated = await productRef.get();
      expect(updated.data()?['name'], 'Updated');
      expect(updated.data()?['price'], 15.0);
      expect(updated.data()?['cost'], 8.0);
    });

    test('online: updates stock when trackStock changes', () async {
      final db = FakeFirebaseFirestore();
      final service = ProductService(firestore: db, connectivityService: ConnectivityService());

      final productRef = db
          .collection('businesses').doc(businessId)
          .collection('products').doc('p2');
      final stockRef = productRef.collection('stockByStore').doc(storeId);

      await productRef.set({
        'name': 'Product',
        'price': 10.0,
        'cost': 5.0,
        'ref': '000020',
        'trackStock': true,
        'active': true,
        'stockQuantity': 10.0,
      });
      await stockRef.set({
        'businessId': businessId,
        'storeId': storeId,
        'productId': 'p2',
        'stockQuantity': 10.0,
      });
      await db.collection('businesses').doc(businessId)
          .collection('counters').doc('products')
          .set({'nextRefNumber': 1});

      final product = Product(
        id: 'p2',
        name: 'Product',
        categoryId: null,
        categoryName: null,
        sellBy: 'unit',
        price: 10.0,
        cost: 5.0,
        ref: '000020',
        trackStock: true,
        stockQuantity: 10.0,
        lowStockAlertQuantity: 2.0,
        presentationType: 'shape',
        presentationShape: 'square',
        presentationColor: 0xFF9E9E9E,
        imageUrl: null,
        localImagePath: null,
        active: true,
      );

      await service.updateProduct(
        businessId: businessId,
        storeId: storeId,
        product: product,
        name: 'Updated Product',
        categoryId: null,
        categoryName: null,
        sellBy: 'unit',
        price: 15.0,
        cost: 7.0,
        ref: '000020',
        trackStock: true,
        stockQuantity: 25.0,
        lowStockAlertQuantity: 5.0,
        presentationType: 'shape',
        presentationShape: 'square',
        presentationColor: 0xFF9E9E9E,
      );

      final updated = await productRef.get();
      expect(updated.data()?['name'], 'Updated Product');
      expect(updated.data()?['price'], 15.0);
      expect(updated.data()?['cost'], 7.0);

      final stock = await stockRef.get();
      expect(stock.data()?['stockQuantity'], 25.0);
    });
  });

  group('ProductService.updateProduct (offline)', () {
    test('offline: enqueues update operation', () async {
      final db = FakeFirebaseFirestore();
      final service = ProductService(firestore: db, connectivityService: OfflineConnectivity());

      await db.collection('businesses').doc(businessId)
          .collection('products').doc('p3').set({
        'name': 'Old',
        'price': 5.0,
        'cost': 2.0,
        'ref': '000030',
        'active': true,
      });

      final product = Product(
        id: 'p3',
        name: 'Old',
        categoryId: null,
        categoryName: null,
        sellBy: 'unit',
        price: 5.0,
        cost: 2.0,
        ref: '000030',
        trackStock: false,
        stockQuantity: 0,
        lowStockAlertQuantity: 0,
        presentationType: 'shape',
        presentationShape: 'square',
        presentationColor: 0xFF9E9E9E,
        imageUrl: null,
        localImagePath: null,
        active: true,
      );

      await service.updateProduct(
        businessId: businessId,
        storeId: storeId,
        product: product,
        name: 'Updated Offline',
        categoryId: null,
        categoryName: null,
        sellBy: 'unit',
        price: 8.0,
        cost: 3.0,
        ref: '000030',
        trackStock: false,
        stockQuantity: 0,
        lowStockAlertQuantity: 0,
        presentationType: 'shape',
        presentationShape: 'square',
        presentationColor: 0xFF9E9E9E,
      );

      expect(SyncQueue.pendingCount, 1);
      expect(SyncQueue.getPending().single.type, 'updateProduct');
    });
  });

  group('ProductService.deactivateProduct', () {
    test('online: deactivates product and removes ref lock', () async {
      final db = FakeFirebaseFirestore();
      final service = ProductService(firestore: db, connectivityService: ConnectivityService());

      final productRef = db
          .collection('businesses').doc(businessId)
          .collection('products').doc('p10');

      await productRef.set({
        'name': 'ToDelete',
        'active': true,
        'ref': '000100',
      });

      await db.collection('businesses').doc(businessId)
          .collection('productRefs').doc('000100')
          .set({'productId': 'p10', 'ref': '000100'});

      final product = Product(
        id: 'p10',
        name: 'ToDelete',
        categoryId: null,
        categoryName: null,
        sellBy: 'unit',
        price: 0,
        cost: 0,
        ref: '000100',
        trackStock: false,
        stockQuantity: 0,
        lowStockAlertQuantity: 0,
        presentationType: 'shape',
        presentationShape: 'square',
        presentationColor: 0xFF9E9E9E,
        imageUrl: null,
        localImagePath: null,
        active: true,
      );

      await service.deactivateProduct(businessId: businessId, product: product);

      final updated = await productRef.get();
      expect(updated.data()?['active'], false);

      final refLock = await db
          .collection('businesses').doc(businessId)
          .collection('productRefs').doc('000100').get();
      expect(refLock.exists, false);
    });

    test('offline: enqueues deactivate operation', () async {
      final db = FakeFirebaseFirestore();
      final service = ProductService(firestore: db, connectivityService: OfflineConnectivity());

      final product = Product(
        id: 'p11',
        name: 'Offline Delete',
        categoryId: null,
        categoryName: null,
        sellBy: 'unit',
        price: 0,
        cost: 0,
        ref: '000101',
        trackStock: false,
        stockQuantity: 0,
        lowStockAlertQuantity: 0,
        presentationType: 'shape',
        presentationShape: 'square',
        presentationColor: 0xFF9E9E9E,
        imageUrl: null,
        localImagePath: null,
        active: true,
      );

      await service.deactivateProduct(businessId: businessId, product: product);

      expect(SyncQueue.pendingCount, 1);
      expect(SyncQueue.getPending().single.type, 'deactivateProduct');
    });
  });

  group('ProductService.getSuggestedRef', () {
    test('online: returns next ref number from counter', () async {
      final db = FakeFirebaseFirestore();
      final service = ProductService(firestore: db, connectivityService: ConnectivityService());

      await db.collection('businesses').doc(businessId)
          .collection('counters').doc('products')
          .set({'nextRefNumber': 42});

      final ref = await service.getSuggestedRef(businessId: businessId);
      expect(ref, '000042');
    });

    test('offline: returns next ref from cached products', () async {
      final service = ProductService(
        firestore: FakeFirebaseFirestore(),
        connectivityService: OfflineConnectivity(),
      );

      await LocalDatabase.cacheProducts(businessId, [
        Product(
          id: 'p1', name: 'A', categoryId: null, categoryName: null,
          sellBy: 'unit', price: 10, cost: 5, ref: '000001',
          trackStock: false, stockQuantity: 0, lowStockAlertQuantity: 0,
          presentationType: 'shape', presentationShape: 'square',
          presentationColor: 0xFF9E9E9E, imageUrl: null, localImagePath: null,
          active: true,
        ),
        Product(
          id: 'p2', name: 'B', categoryId: null, categoryName: null,
          sellBy: 'unit', price: 20, cost: 10, ref: '000005',
          trackStock: false, stockQuantity: 0, lowStockAlertQuantity: 0,
          presentationType: 'shape', presentationShape: 'square',
          presentationColor: 0xFF9E9E9E, imageUrl: null, localImagePath: null,
          active: true,
        ),
      ]);

      final ref = await service.getSuggestedRef(businessId: businessId);
      expect(ref, '000006');
    });

    test('offline: returns 000001 when no cached products', () async {
      final service = ProductService(
        firestore: FakeFirebaseFirestore(),
        connectivityService: OfflineConnectivity(),
      );

      final ref = await service.getSuggestedRef(businessId: businessId);
      expect(ref, '000001');
    });
  });
}
