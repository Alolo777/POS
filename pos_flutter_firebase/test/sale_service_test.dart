import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import '../lib/models/cart_item.dart';
import '../lib/models/product.dart';
import '../lib/services/connectivity_service.dart';
import '../lib/services/sale_service.dart';

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
    stock: stock.toInt(),
    stockQuantity: stock,
    lowStockAlert: 0,
    lowStockAlertQuantity: 0,
    presentationType: 'shape',
    presentationShape: 'square',
    presentationColor: 0xFF9E9E9E,
    imageUrl: null,
    localImagePath: null,
    active: true,
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
  });
}
