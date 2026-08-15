import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:pos_flutter_firebase/shared/models/cart_item.dart';
import 'package:pos_flutter_firebase/shared/models/product.dart';
import 'package:pos_flutter_firebase/shared/models/sale.dart';
import 'package:pos_flutter_firebase/core/network/connectivity_service.dart';
import 'package:pos_flutter_firebase/features/sales/data/sale_service.dart';
import 'package:pos_flutter_firebase/features/inventory/data/stock_service.dart';

const businessId = 'test_business';
const storeId = 'test_store';
const employeeId = 'test_employee';
const shiftId = 'test_shift';
const testUid = 'test_user';

Product _createProduct(String id, String name, double price, double stock, {bool trackStock = true}) {
  return Product(
    id: id,
    name: name,
    categoryId: null,
    categoryName: null,
    sellBy: 'unit',
    price: price,
    cost: 0,
    ref: 'REF-$id',
    trackStock: trackStock,
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

Product _createWholeChicken(double stock, {int? chickenCount}) {
  return Product(
    id: 'whole',
    name: 'Pollo Entero',
    categoryId: null,
    categoryName: null,
    sellBy: 'weight',
    price: 50.0,
    cost: 0,
    ref: 'REF-whole',
    trackStock: true,
    stockQuantity: stock,
    lowStockAlertQuantity: 0,
    presentationType: 'shape',
    presentationShape: 'square',
    presentationColor: 0xFF9E9E9E,
    imageUrl: null,
    localImagePath: null,
    active: true,
    chickenCount: chickenCount,
  );
}

void main() {
  late FakeFirebaseFirestore fakeFirestore;
  late SaleService saleService;

  setUp(() {
    fakeFirestore = FakeFirebaseFirestore();
    saleService = SaleService(
      firestore: fakeFirestore,
      connectivityService: ConnectivityService(),
      stockService: StockService(firestore: fakeFirestore),
    );
  });

  group('SaleService.createSale', () {
    test('should create a sale and update stock', () async {
      final product = _createProduct('p1', 'Test Product', 10.0, 5.0);
      final stockRef = fakeFirestore
          .collection('businesses')
          .doc(businessId)
          .collection('products')
          .doc(product.id)
          .collection('stockByStore')
          .doc(storeId);
      await stockRef.set({
        'businessId': businessId,
        'storeId': storeId,
        'productId': product.id,
        'stock': 5,
        'stockQuantity': 5.0,
      });

      final counterRef = fakeFirestore
          .collection('businesses')
          .doc(businessId)
          .collection('counters')
          .doc('sales');
      await counterRef.set({'nextSaleNumber': 1});

      final items = [CartItem(product: product, quantity: 1.0)];
      final folio = await saleService.createSale(
        businessId: businessId,
        storeId: storeId,
        employeeId: employeeId,
        shiftId: shiftId,
        items: items,
        subtotal: 10.0,
        discountTotal: 0,
        total: 10.0,
        paymentMethod: 'cash',
        cashReceived: 10.0,
        changeDue: 0,
        createdByUid: testUid,
      );

      expect(folio, 'T-000001');

      final saleSnapshot = await fakeFirestore
          .collection('businesses')
          .doc(businessId)
          .collection('sales')
          .get();
      expect(saleSnapshot.docs.length, 1);

      final updatedStock = await stockRef.get();
      expect((updatedStock.data()?['stockQuantity'] as num).toDouble(), 4.0);
    });

    test('should throw when stock is insufficient', () async {
      final product = _createProduct('p2', 'Low Stock', 10.0, 0.5);
      final stockRef = fakeFirestore
          .collection('businesses')
          .doc(businessId)
          .collection('products')
          .doc(product.id)
          .collection('stockByStore')
          .doc(storeId);
      await stockRef.set({
        'businessId': businessId,
        'storeId': storeId,
        'productId': product.id,
        'stock': 0,
        'stockQuantity': 0.5,
      });

      final counterRef = fakeFirestore
          .collection('businesses')
          .doc(businessId)
          .collection('counters')
          .doc('sales');
      await counterRef.set({'nextSaleNumber': 1});

      final items = [CartItem(product: product, quantity: 2.0)];

      expect(
        () => saleService.createSale(
          businessId: businessId,
          storeId: storeId,
          employeeId: employeeId,
          shiftId: shiftId,
          items: items,
          subtotal: 20.0,
          discountTotal: 0,
          total: 20.0,
          paymentMethod: 'cash',
          createdByUid: testUid,
        ),
        throwsA(isA<StateError>()),
      );
    });

    test('decrements chickenCount when selling whole chicken', () async {
      final product = _createWholeChicken(15.0, chickenCount: 5);
      final stockRef = fakeFirestore
          .collection('businesses')
          .doc(businessId)
          .collection('products')
          .doc(product.id)
          .collection('stockByStore')
          .doc(storeId);
      await stockRef.set({
        'businessId': businessId,
        'storeId': storeId,
        'productId': product.id,
        'stock': 15,
        'stockQuantity': 15.0,
        'chickenCount': 5,
      });

      final counterRef = fakeFirestore
          .collection('businesses')
          .doc(businessId)
          .collection('counters')
          .doc('sales');
      await counterRef.set({'nextSaleNumber': 1});

      final items = [
        CartItem(product: product, quantity: 3.0, chickenCount: 2),
      ];

      final folio = await saleService.createSale(
        businessId: businessId,
        storeId: storeId,
        employeeId: employeeId,
        shiftId: shiftId,
        items: items,
        subtotal: 150.0,
        discountTotal: 0,
        total: 150.0,
        paymentMethod: 'cash',
        createdByUid: testUid,
      );

      expect(folio, 'T-000001');

      final saleSnapshot = await fakeFirestore
          .collection('businesses')
          .doc(businessId)
          .collection('sales')
          .get();
      final savedItems =
          (saleSnapshot.docs.single.data()['items'] as List<dynamic>);
      expect((savedItems.single as Map<String, dynamic>)['chickenCount'], 2);

      final updatedStock = await stockRef.get();
      expect((updatedStock.data()?['stockQuantity'] as num).toDouble(), 12.0);
      expect(updatedStock.data()?['chickenCount'], 3);
    });

    test('throws when chickenCount is insufficient', () async {
      final product = _createWholeChicken(15.0, chickenCount: 5);
      final stockRef = fakeFirestore
          .collection('businesses')
          .doc(businessId)
          .collection('products')
          .doc(product.id)
          .collection('stockByStore')
          .doc(storeId);
      await stockRef.set({
        'businessId': businessId,
        'storeId': storeId,
        'productId': product.id,
        'stock': 15,
        'stockQuantity': 15.0,
        'chickenCount': 1,
      });

      final counterRef = fakeFirestore
          .collection('businesses')
          .doc(businessId)
          .collection('counters')
          .doc('sales');
      await counterRef.set({'nextSaleNumber': 1});

      final items = [
        CartItem(product: product, quantity: 3.0, chickenCount: 2),
      ];

      expect(
        () => saleService.createSale(
          businessId: businessId,
          storeId: storeId,
          employeeId: employeeId,
          shiftId: shiftId,
          items: items,
          subtotal: 150.0,
          discountTotal: 0,
          total: 150.0,
          paymentMethod: 'cash',
          createdByUid: testUid,
        ),
        throwsA(isA<StateError>()),
      );

      final updatedStock = await stockRef.get();
      expect((updatedStock.data()?['stockQuantity'] as num).toDouble(), 15.0);
      expect(updatedStock.data()?['chickenCount'], 1);
    });

    test('applies piece swaps stock deltas when selling whole chicken', () async {
      final product = _createWholeChicken(15.0, chickenCount: 5);

      Future<void> seedStock(String productId, double stock, {int? chickenCount}) {
        return fakeFirestore
            .collection('businesses')
            .doc(businessId)
            .collection('products')
            .doc(productId)
            .collection('stockByStore')
            .doc(storeId)
            .set({
          'businessId': businessId,
          'storeId': storeId,
          'productId': productId,
          'stockQuantity': stock,
          if (chickenCount != null) 'chickenCount': chickenCount,
        });
      }

      await seedStock(product.id, 15.0, chickenCount: 5);
      await seedStock('pechuga', 3.0);
      await seedStock('maciza', 1.0);

      await fakeFirestore
          .collection('businesses')
          .doc(businessId)
          .collection('counters')
          .doc('sales')
          .set({'nextSaleNumber': 1});

      final items = [
        CartItem(
          product: product,
          quantity: 3.0,
          chickenCount: 2,
          pieceSwaps: const [
            PieceSwap(productId: 'pechuga', productName: 'Pechuga', weight: 1.5, direction: 'out'),
            PieceSwap(productId: 'maciza', productName: 'Maciza', weight: 0.5, direction: 'in'),
          ],
        ),
      ];

      await saleService.createSale(
        businessId: businessId,
        storeId: storeId,
        employeeId: employeeId,
        shiftId: shiftId,
        items: items,
        subtotal: 150.0,
        discountTotal: 0,
        total: 150.0,
        paymentMethod: 'cash',
        createdByUid: testUid,
      );

      final pechugaStock = await fakeFirestore
          .collection('businesses')
          .doc(businessId)
          .collection('products')
          .doc('pechuga')
          .collection('stockByStore')
          .doc(storeId)
          .get();
      expect((pechugaStock.data()?['stockQuantity'] as num).toDouble(), 1.5);

      final macizaStock = await fakeFirestore
          .collection('businesses')
          .doc(businessId)
          .collection('products')
          .doc('maciza')
          .collection('stockByStore')
          .doc(storeId)
          .get();
      expect((macizaStock.data()?['stockQuantity'] as num).toDouble(), 1.5);

      final movements = await fakeFirestore
          .collection('businesses')
          .doc(businessId)
          .collection('inventoryMovements')
          .get();
      final swapMovements = movements.docs.where((d) => d.data()['type'] == 'swap').toList();
      expect(swapMovements.length, 2);
      expect(swapMovements.map((d) => d.data()['productId']).toSet(), {'pechuga', 'maciza'});

      final savedItems =
          (await fakeFirestore.collection('businesses').doc(businessId).collection('sales').get())
              .docs
              .single
              .data()['items'] as List<dynamic>;
      final savedSwaps = ((savedItems.single as Map<String, dynamic>)['pieceSwaps'] as List<dynamic>);
      expect(savedSwaps.length, 2);
    });

    test('throws when swap out exceeds available stock', () async {
      final product = _createWholeChicken(15.0, chickenCount: 5);

      await fakeFirestore
          .collection('businesses')
          .doc(businessId)
          .collection('products')
          .doc(product.id)
          .collection('stockByStore')
          .doc(storeId)
          .set({
        'businessId': businessId,
        'storeId': storeId,
        'productId': product.id,
        'stockQuantity': 15.0,
        'chickenCount': 5,
      });
      await fakeFirestore
          .collection('businesses')
          .doc(businessId)
          .collection('products')
          .doc('pechuga')
          .collection('stockByStore')
          .doc(storeId)
          .set({
        'businessId': businessId,
        'storeId': storeId,
        'productId': 'pechuga',
        'stockQuantity': 1.0,
      });
      await fakeFirestore
          .collection('businesses')
          .doc(businessId)
          .collection('counters')
          .doc('sales')
          .set({'nextSaleNumber': 1});

      final items = [
        CartItem(
          product: product,
          quantity: 3.0,
          chickenCount: 2,
          pieceSwaps: const [
            PieceSwap(productId: 'pechuga', productName: 'Pechuga', weight: 1.5, direction: 'out'),
          ],
        ),
      ];

      expect(
        () => saleService.createSale(
          businessId: businessId,
          storeId: storeId,
          employeeId: employeeId,
          shiftId: shiftId,
          items: items,
          subtotal: 150.0,
          discountTotal: 0,
          total: 150.0,
          paymentMethod: 'cash',
          createdByUid: testUid,
        ),
        throwsA(isA<StateError>()),
      );

      final pechugaStock = await fakeFirestore
          .collection('businesses')
          .doc(businessId)
          .collection('products')
          .doc('pechuga')
          .collection('stockByStore')
          .doc(storeId)
          .get();
      expect((pechugaStock.data()?['stockQuantity'] as num).toDouble(), 1.0);
    });
  });

  group('SaleService.cancelSale', () {
    test('restores chickenCount on whole chicken refund', () async {
      final product = _createWholeChicken(15.0, chickenCount: 5);
      final productRef = fakeFirestore
          .collection('businesses')
          .doc(businessId)
          .collection('products')
          .doc(product.id);
      await productRef.set({'id': product.id, 'name': 'Pollo Entero', 'active': true});
      final stockRef = productRef.collection('stockByStore').doc(storeId);
      await stockRef.set({
        'businessId': businessId,
        'storeId': storeId,
        'productId': product.id,
        'stock': 15,
        'stockQuantity': 15.0,
        'chickenCount': 5,
      });

      final counterRef = fakeFirestore
          .collection('businesses')
          .doc(businessId)
          .collection('counters')
          .doc('sales');
      await counterRef.set({'nextSaleNumber': 1, 'nextRefundNumber': 1});

      final items = [
        CartItem(product: product, quantity: 3.0, chickenCount: 2),
      ];
      await saleService.createSale(
        businessId: businessId,
        storeId: storeId,
        employeeId: employeeId,
        shiftId: shiftId,
        items: items,
        subtotal: 150.0,
        discountTotal: 0,
        total: 150.0,
        paymentMethod: 'cash',
        createdByUid: testUid,
      );

      final saleDoc = (await fakeFirestore
              .collection('businesses')
              .doc(businessId)
              .collection('sales')
              .get())
          .docs
          .single;
      final sale = Sale.fromDoc(saleDoc);

      final refundFolio = await saleService.cancelSale(
        businessId: businessId,
        sale: sale,
        returnItems: [
          {
            'productId': product.id,
            'name': 'Pollo Entero',
            'quantity': 3.0,
            'subtotal': 150.0,
            'chickenCount': 2,
          },
        ],
        returnInventory: true,
        reason: 'Devolución de prueba',
      );

      expect(refundFolio, 'D-000001');

      final updatedStock = await stockRef.get();
      expect((updatedStock.data()?['stockQuantity'] as num).toDouble(), 15.0);
      expect(updatedStock.data()?['chickenCount'], 5);
    });

    test('reverses piece swaps on whole chicken refund', () async {
      final product = _createWholeChicken(15.0, chickenCount: 5);

      Future<void> seedStock(String productId, double stock, {int? chickenCount}) {
        return fakeFirestore
            .collection('businesses')
            .doc(businessId)
            .collection('products')
            .doc(productId)
            .collection('stockByStore')
            .doc(storeId)
            .set({
          'businessId': businessId,
          'storeId': storeId,
          'productId': productId,
          'stockQuantity': stock,
          if (chickenCount != null) 'chickenCount': chickenCount,
        });
      }

      await fakeFirestore
          .collection('businesses')
          .doc(businessId)
          .collection('products')
          .doc(product.id)
          .set({'id': product.id, 'name': 'Pollo Entero', 'active': true});
      await seedStock(product.id, 15.0, chickenCount: 5);
      await seedStock('pechuga', 3.0);
      await seedStock('maciza', 1.0);

      await fakeFirestore
          .collection('businesses')
          .doc(businessId)
          .collection('counters')
          .doc('sales')
          .set({'nextSaleNumber': 1, 'nextRefundNumber': 1});

      final items = [
        CartItem(
          product: product,
          quantity: 3.0,
          chickenCount: 2,
          pieceSwaps: const [
            PieceSwap(productId: 'pechuga', productName: 'Pechuga', weight: 1.5, direction: 'out'),
            PieceSwap(productId: 'maciza', productName: 'Maciza', weight: 0.5, direction: 'in'),
          ],
        ),
      ];
      await saleService.createSale(
        businessId: businessId,
        storeId: storeId,
        employeeId: employeeId,
        shiftId: shiftId,
        items: items,
        subtotal: 150.0,
        discountTotal: 0,
        total: 150.0,
        paymentMethod: 'cash',
        createdByUid: testUid,
      );

      final saleDoc = (await fakeFirestore
              .collection('businesses')
              .doc(businessId)
              .collection('sales')
              .get())
          .docs
          .single;
      final sale = Sale.fromDoc(saleDoc);

      await saleService.cancelSale(
        businessId: businessId,
        sale: sale,
        returnItems: [
          {
            'productId': product.id,
            'name': 'Pollo Entero',
            'quantity': 3.0,
            'subtotal': 150.0,
            'chickenCount': 2,
            'pieceSwaps': [
              {'productId': 'pechuga', 'productName': 'Pechuga', 'delta': 1.5},
              {'productId': 'maciza', 'productName': 'Maciza', 'delta': -0.5},
            ],
          },
        ],
        returnInventory: true,
        reason: 'Devolución de prueba',
      );

      final pechugaStock = await fakeFirestore
          .collection('businesses')
          .doc(businessId)
          .collection('products')
          .doc('pechuga')
          .collection('stockByStore')
          .doc(storeId)
          .get();
      expect((pechugaStock.data()?['stockQuantity'] as num).toDouble(), 3.0);

      final macizaStock = await fakeFirestore
          .collection('businesses')
          .doc(businessId)
          .collection('products')
          .doc('maciza')
          .collection('stockByStore')
          .doc(storeId)
          .get();
      expect((macizaStock.data()?['stockQuantity'] as num).toDouble(), 1.0);
    });
  });
}
