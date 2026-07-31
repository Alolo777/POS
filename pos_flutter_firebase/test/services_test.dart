import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:pos_flutter_firebase/shared/models/cart_item.dart';
import 'package:pos_flutter_firebase/shared/models/product.dart';
import 'package:pos_flutter_firebase/shared/models/sale.dart';
import 'package:pos_flutter_firebase/core/network/connectivity_service.dart';
import 'package:pos_flutter_firebase/features/sales/data/sale_service.dart';
import 'package:pos_flutter_firebase/features/inventory/data/stock_service.dart';
import 'package:pos_flutter_firebase/features/inventory/data/inventory_service.dart';
import 'package:pos_flutter_firebase/features/shift/data/shift_service.dart';

const businessId = 'test_business';
const storeId = 'test_store';
const employeeId = 'test_employee';
const shiftId = 'test_shift';
const testUid = 'test_user';

Product _product(String id, String name, double price, double stock,
    {bool trackStock = true, String sellBy = 'unit'}) {
  return Product(
    id: id,
    name: name,
    categoryId: null,
    categoryName: null,
    sellBy: sellBy,
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

Future<String> _seedStock(FakeFirebaseFirestore db, String productId, double quantity) async {
  final productRef = db
      .collection('businesses')
      .doc(businessId)
      .collection('products')
      .doc(productId);
  await productRef.set({
    'id': productId,
    'name': 'Product $productId',
    'active': true,
  });
  final ref = productRef
      .collection('stockByStore')
      .doc(storeId);
  await ref.set({
    'businessId': businessId,
    'storeId': storeId,
    'productId': productId,
    'stock': quantity.round(),
    'stockQuantity': quantity,
  });
  return ref.id;
}

Future<void> _seedCounter(FakeFirebaseFirestore db, {int nextSale = 1, int nextRefund = 1}) async {
  await db.collection('businesses').doc(businessId).collection('counters').doc('sales').set({
    'nextSaleNumber': nextSale,
    'nextRefundNumber': nextRefund,
  });
}

void main() {
  late FakeFirebaseFirestore fakeFirestore;
  late SaleService saleService;
  late InventoryService inventoryService;
  late ShiftService shiftService;

  setUp(() {
    fakeFirestore = FakeFirebaseFirestore();
    saleService = SaleService(
      firestore: fakeFirestore,
      connectivityService: ConnectivityService(),
      stockService: StockService(firestore: fakeFirestore),
    );
    inventoryService = InventoryService(
      firestore: fakeFirestore,
      connectivityService: ConnectivityService(),
    );
    shiftService = ShiftService(
      firestore: fakeFirestore,
      connectivityService: ConnectivityService(),
    );
  });

  group('SaleService.createSale', () {
    test('should create a sale and update stock', () async {
      final product = _product('p1', 'Test Product', 10.0, 5.0);
      await _seedStock(fakeFirestore, product.id, 5.0);
      await _seedCounter(fakeFirestore);

      final folio = await saleService.createSale(
        businessId: businessId,
        storeId: storeId,
        employeeId: employeeId,
        shiftId: shiftId,
        items: [CartItem(product: product, quantity: 1.0)],
        subtotal: 10.0,
        discountTotal: 0,
        total: 10.0,
        paymentMethod: 'cash',
        cashReceived: 10.0,
        changeDue: 0,
        createdByUid: testUid,
      );

      expect(folio, 'T-000001');

      final saleSnap = await fakeFirestore
          .collection('businesses')
          .doc(businessId)
          .collection('sales')
          .get();
      expect(saleSnap.docs.length, 1);

      final stockDoc = await fakeFirestore
          .collection('businesses')
          .doc(businessId)
          .collection('products')
          .doc(product.id)
          .collection('stockByStore')
          .doc(storeId)
          .get();
      expect((stockDoc.data()?['stockQuantity'] as num).toDouble(), 4.0);
    });

    test('should throw when stock is insufficient', () async {
      final product = _product('p2', 'Low Stock', 10.0, 0.5);
      await _seedStock(fakeFirestore, product.id, 0.5);
      await _seedCounter(fakeFirestore);

      expect(
        () => saleService.createSale(
          businessId: businessId,
          storeId: storeId,
          employeeId: employeeId,
          shiftId: shiftId,
          items: [CartItem(product: product, quantity: 2.0)],
          subtotal: 20.0,
          discountTotal: 0,
          total: 20.0,
          paymentMethod: 'cash',
          createdByUid: testUid,
        ),
        throwsA(isA<StateError>()),
      );
    });
  });

  group('SaleService.cancelSale', () {
    test('should create a refund without restock', () async {
      final product = _product('p3', 'Refundable', 10.0, 5.0);
      await _seedStock(fakeFirestore, product.id, 5.0);
      await _seedCounter(fakeFirestore);

      final saleDoc = await fakeFirestore
          .collection('businesses')
          .doc(businessId)
          .collection('sales')
          .add({
        'businessId': businessId,
        'storeId': storeId,
        'folio': 'T-000001',
        'status': 'paid',
        'items': [
          {
            'productId': product.id,
            'name': product.name,
            'quantity': 2.0,
            'unitPrice': 10.0,
            'subtotal': 20.0,
            'modifiers': <Map<String, dynamic>>[],
            'discount': 0,
          }
        ],
        'subtotal': 20.0,
        'discountTotal': 0,
        'total': 20.0,
        'paymentMethod': 'cash',
        'shiftId': shiftId,
        'employeeId': employeeId,
        'createdAt': Timestamp.now(),
      });
      final saleData = await saleDoc.get();
      final sale = Sale.fromDoc(saleData);
      final stockBefore = await fakeFirestore
          .collection('businesses')
          .doc(businessId)
          .collection('products')
          .doc(product.id)
          .collection('stockByStore')
          .doc(storeId)
          .get();
      expect((stockBefore.data()?['stockQuantity'] as num).toDouble(), 5.0);

      await saleService.cancelSale(
        businessId: businessId,
        sale: sale,
        returnItems: [
          {
            'productId': product.id,
            'name': product.name,
            'quantity': 1.0,
            'subtotal': 10.0,
          }
        ],
        returnInventory: false,
        reason: 'Cliente devolvio',
      );

      final refundSnap = await fakeFirestore
          .collection('businesses')
          .doc(businessId)
          .collection('sales')
          .where('status', isEqualTo: 'refund')
          .get();
      expect(refundSnap.docs.length, 1);
      expect(refundSnap.docs.first.data()['folio'], 'D-000001');
      expect(refundSnap.docs.first.data()['total'], 10.0);

      final stockAfter = await fakeFirestore
          .collection('businesses')
          .doc(businessId)
          .collection('products')
          .doc(product.id)
          .collection('stockByStore')
          .doc(storeId)
          .get();
      expect((stockAfter.data()?['stockQuantity'] as num).toDouble(), 5.0);

      final saleAfter = await fakeFirestore
          .collection('businesses')
          .doc(businessId)
          .collection('sales')
          .doc(sale.id)
          .get();
      expect(saleAfter.data()?['status'], 'partially_cancelled');
    });

    test('should create a refund with restock', () async {
      final product = _product('p4', 'Restockable', 10.0, 5.0);
      await _seedStock(fakeFirestore, product.id, 5.0);
      await _seedCounter(fakeFirestore);

      final saleDoc = await fakeFirestore
          .collection('businesses')
          .doc(businessId)
          .collection('sales')
          .add({
        'businessId': businessId,
        'storeId': storeId,
        'folio': 'T-000002',
        'status': 'paid',
        'items': [
          {
            'productId': product.id,
            'name': product.name,
            'quantity': 2.0,
            'unitPrice': 10.0,
            'subtotal': 20.0,
            'modifiers': <Map<String, dynamic>>[],
            'discount': 0,
          }
        ],
        'subtotal': 20.0,
        'discountTotal': 0,
        'total': 20.0,
        'paymentMethod': 'cash',
        'shiftId': shiftId,
        'employeeId': employeeId,
        'createdAt': Timestamp.now(),
      });
      final sale = Sale.fromDoc(await saleDoc.get());

      await saleService.cancelSale(
        businessId: businessId,
        sale: sale,
        returnItems: [
          {
            'productId': product.id,
            'name': product.name,
            'quantity': 2.0,
            'subtotal': 20.0,
          }
        ],
        returnInventory: true,
        reason: 'Full return',
      );

      final stockAfter = await fakeFirestore
          .collection('businesses')
          .doc(businessId)
          .collection('products')
          .doc(product.id)
          .collection('stockByStore')
          .doc(storeId)
          .get();
      expect((stockAfter.data()?['stockQuantity'] as num).toDouble(), 7.0);

      final movements = await fakeFirestore
          .collection('businesses')
          .doc(businessId)
          .collection('inventoryMovements')
          .get();
      expect(movements.docs.length, 1);
      expect(movements.docs.first.data()['type'], 'refund');
      expect((movements.docs.first.data()['difference'] as num).toDouble(), 2.0);

      final saleAfter = await fakeFirestore
          .collection('businesses')
          .doc(businessId)
          .collection('sales')
          .doc(sale.id)
          .get();
      expect(saleAfter.data()?['status'], 'cancelled');
    });

    test('should throw for already cancelled sale', () async {
      final product = _product('p5', 'Cancelled', 10.0, 5.0);
      await _seedStock(fakeFirestore, product.id, 5.0);
      await _seedCounter(fakeFirestore);

      final saleDoc = await fakeFirestore
          .collection('businesses')
          .doc(businessId)
          .collection('sales')
          .add({
        'businessId': businessId,
        'storeId': storeId,
        'folio': 'T-000003',
        'status': 'cancelled',
        'items': [
          {
            'productId': product.id,
            'name': product.name,
            'quantity': 1.0,
            'unitPrice': 10.0,
            'subtotal': 10.0,
          }
        ],
        'subtotal': 10.0,
        'discountTotal': 0,
        'total': 10.0,
        'paymentMethod': 'cash',
        'shiftId': shiftId,
        'employeeId': employeeId,
        'createdAt': Timestamp.now(),
      });
      final sale = Sale.fromDoc(await saleDoc.get());

      expect(
        () => saleService.cancelSale(
          businessId: businessId,
          sale: sale,
          returnItems: [
            {
              'productId': product.id,
              'name': product.name,
              'quantity': 1.0,
              'subtotal': 10.0,
            }
          ],
          returnInventory: false,
          reason: 'Already cancelled',
        ),
        throwsA(isA<StateError>()),
      );
    });

    test('should throw for empty returnItems', () async {
      final saleDoc = await fakeFirestore
          .collection('businesses')
          .doc(businessId)
          .collection('sales')
          .add({
        'businessId': businessId,
        'storeId': storeId,
        'folio': 'T-000004',
        'status': 'paid',
        'items': [],
        'subtotal': 0,
        'discountTotal': 0,
        'total': 0,
        'paymentMethod': 'cash',
        'shiftId': shiftId,
        'employeeId': employeeId,
        'createdAt': Timestamp.now(),
      });
      final sale = Sale.fromDoc(await saleDoc.get());

      expect(
        () => saleService.cancelSale(
          businessId: businessId,
          sale: sale,
          returnItems: [],
          returnInventory: false,
          reason: 'No items',
        ),
        throwsA(isA<StateError>()),
      );
    });
  });

  group('InventoryService.adjustStock', () {
    test('should adjust stock and create movement', () async {
      final product = _product('p10', 'Adjustable', 10.0, 5.0);
      await _seedStock(fakeFirestore, product.id, 5.0);

      await inventoryService.adjustStock(
        businessId: businessId,
        storeId: storeId,
        product: product,
        newQuantity: 10.0,
        reason: 'Receiving shipment',
        employeeId: employeeId,
      );

      final stockDoc = await fakeFirestore
          .collection('businesses')
          .doc(businessId)
          .collection('products')
          .doc(product.id)
          .collection('stockByStore')
          .doc(storeId)
          .get();
      expect((stockDoc.data()?['stockQuantity'] as num).toDouble(), 10.0);

      final movements = await fakeFirestore
          .collection('businesses')
          .doc(businessId)
          .collection('inventoryMovements')
          .get();
      expect(movements.docs.length, 1);
      expect(movements.docs.first.data()['type'], 'adjustment');
      expect((movements.docs.first.data()['difference'] as num).toDouble(), 5.0);
      expect(movements.docs.first.data()['reason'], 'Receiving shipment');
    });

    test('should throw for non-trackStock product', () async {
      final product = _product('p11', 'No Track', 10.0, 5.0, trackStock: false);

      expect(
        () => inventoryService.adjustStock(
          businessId: businessId,
          storeId: storeId,
          product: product,
          newQuantity: 10.0,
          reason: 'Test',
          employeeId: employeeId,
        ),
        throwsA(isA<StateError>()),
      );
    });

    test('should throw for negative quantity', () async {
      final product = _product('p12', 'Negative', 10.0, 5.0);
      await _seedStock(fakeFirestore, product.id, 5.0);

      expect(
        () => inventoryService.adjustStock(
          businessId: businessId,
          storeId: storeId,
          product: product,
          newQuantity: -1.0,
          reason: 'Test',
          employeeId: employeeId,
        ),
        throwsA(isA<StateError>()),
      );
    });

    test('should throw for fractional quantity on unit product', () async {
      final product = _product('p13', 'Unit Only', 10.0, 5.0, sellBy: 'unit');
      await _seedStock(fakeFirestore, product.id, 5.0);

      expect(
        () => inventoryService.adjustStock(
          businessId: businessId,
          storeId: storeId,
          product: product,
          newQuantity: 3.5,
          reason: 'Test',
          employeeId: employeeId,
        ),
        throwsA(isA<StateError>()),
      );
    });
  });

  group('ShiftService', () {
    test('should open a shift', () async {
      await shiftService.openShift(
        businessId: businessId,
        storeId: storeId,
        employeeId: employeeId,
        openingCash: 500.0,
      );

      final shifts = await fakeFirestore
          .collection('businesses')
          .doc(businessId)
          .collection('shifts')
          .get();
      expect(shifts.docs.length, 1);
      expect(shifts.docs.first.data()['status'], 'open');
      expect((shifts.docs.first.data()['openingCash'] as num).toDouble(), 500.0);
    });

    test('should throw if shift already open', () async {
      await shiftService.openShift(
        businessId: businessId,
        storeId: storeId,
        employeeId: employeeId,
        openingCash: 500.0,
      );

      expect(
        () => shiftService.openShift(
          businessId: businessId,
          storeId: storeId,
          employeeId: employeeId,
          openingCash: 300.0,
        ),
        throwsA(isA<StateError>()),
      );
    });

    test('should close a shift and calculate totals', () async {
      await shiftService.openShift(
        businessId: businessId,
        storeId: storeId,
        employeeId: employeeId,
        openingCash: 500.0,
      );

      final product = _product('p20', 'Shift Product', 10.0, 100.0);
      await _seedStock(fakeFirestore, product.id, 100.0);
      await _seedCounter(fakeFirestore);

      final openShift = await shiftService.getOpenShift(
        businessId: businessId,
        storeId: storeId,
        employeeId: employeeId,
      );
      expect(openShift, isNotNull);

      await saleService.createSale(
        businessId: businessId,
        storeId: storeId,
        employeeId: employeeId,
        shiftId: openShift!.id,
        items: [CartItem(product: product, quantity: 3.0)],
        subtotal: 30.0,
        discountTotal: 0,
        total: 30.0,
        paymentMethod: 'cash',
        cashReceived: 30.0,
        changeDue: 0,
        createdByUid: testUid,
      );
      await saleService.createSale(
        businessId: businessId,
        storeId: storeId,
        employeeId: employeeId,
        shiftId: openShift.id,
        items: [CartItem(product: product, quantity: 2.0)],
        subtotal: 20.0,
        discountTotal: 0,
        total: 20.0,
        paymentMethod: 'card',
        cashReceived: null,
        changeDue: null,
        createdByUid: testUid,
      );

      await shiftService.closeShift(
        businessId: businessId,
        shift: openShift,
        closingCash: 530.0,
      );

      final closed = await shiftService.getOpenShift(
        businessId: businessId,
        storeId: storeId,
        employeeId: employeeId,
      );
      expect(closed, isNull);

      final shifts = await fakeFirestore
          .collection('businesses')
          .doc(businessId)
          .collection('shifts')
          .get();
      expect(shifts.docs.length, 1);
      final data = shifts.docs.first.data();
      expect(data['status'], 'closed');
      expect((data['cashSales'] as num).toDouble(), 30.0);
      expect((data['cardSales'] as num).toDouble(), 20.0);
      expect((data['totalSales'] as num).toDouble(), 50.0);
      expect((data['expectedCash'] as num).toDouble(), 530.0);
      expect((data['cashDifference'] as num).toDouble(), 0.0);
      expect(data['closingCash'], 530.0);
    });

    test('should add cash movements', () async {
      await shiftService.openShift(
        businessId: businessId,
        storeId: storeId,
        employeeId: employeeId,
        openingCash: 500.0,
      );

      final openShift = await shiftService.getOpenShift(
        businessId: businessId,
        storeId: storeId,
        employeeId: employeeId,
      );
      expect(openShift, isNotNull);

      await shiftService.addCashMovement(
        businessId: businessId,
        shift: openShift!,
        type: 'deposit',
        amount: 200.0,
        comment: 'Bank deposit',
      );
      await shiftService.addCashMovement(
        businessId: businessId,
        shift: openShift,
        type: 'payout',
        amount: 50.0,
        comment: 'Supplies',
      );

      final shiftDoc = await fakeFirestore
          .collection('businesses')
          .doc(businessId)
          .collection('shifts')
          .doc(openShift.id)
          .get();
      expect((shiftDoc.data()?['depositsTotal'] as num).toDouble(), 200.0);
      expect((shiftDoc.data()?['payoutsTotal'] as num).toDouble(), 50.0);
      final movements = shiftDoc.data()?['cashMovements'] as List;
      expect(movements.length, 2);
    });
  });
}
