import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/cart_item.dart';
import '../models/sale.dart';
import 'connectivity_service.dart';

class SaleService {
  SaleService({FirebaseFirestore? firestore, ConnectivityService? connectivityService})
      : _db = firestore ?? FirebaseFirestore.instance,
        _connectivityService = connectivityService ?? ConnectivityService();

  final FirebaseFirestore _db;
  final ConnectivityService _connectivityService;
  FirebaseAuth? _auth;

  FirebaseAuth get _authInstance => _auth ??= FirebaseAuth.instance;

  Future<String> createSale({
    required String businessId,
    required String storeId,
    required String employeeId,
    required String shiftId,
    required List<CartItem> items,
    required double subtotal,
    required double discountTotal,
    required double total,
    required String paymentMethod,
    double? cashReceived,
    double? changeDue,
    String? createdByUid,
  }) async {
    String uid;
    if (createdByUid != null) {
      uid = createdByUid;
    } else {
      final user = _authInstance.currentUser;
      if (user == null) {
        throw StateError('No hay usuario autenticado');
      }
      uid = user.uid;
    }

    await _connectivityService.requireConnection('Cobrar venta');

    var createdFolio = '';

    await _db.runTransaction((transaction) async {
      final stockItems = items.where((item) => item.product.trackStock).toList();
      final stockRefs = stockItems
          .map(
            (item) => _db
                .collection('businesses')
                .doc(businessId)
                .collection('products')
                .doc(item.product.id)
                .collection('stockByStore')
                .doc(storeId),
          )
          .toList();
      final stockSnapshots = <DocumentSnapshot<Map<String, dynamic>>>[];
      final counterRef = _db
          .collection('businesses')
          .doc(businessId)
          .collection('counters')
          .doc('sales');

      for (final stockRef in stockRefs) {
        stockSnapshots.add(await transaction.get(stockRef));
      }
      final counterSnapshot = await transaction.get(counterRef);
      final nextSaleNumber = (counterSnapshot.data()?['nextSaleNumber'] as num? ?? 1).toInt();
      final folio = 'T-${nextSaleNumber.toString().padLeft(6, '0')}';
      createdFolio = folio;

      for (var index = 0; index < stockItems.length; index++) {
        final item = stockItems[index];
        final stockRef = stockRefs[index];
        final stockSnapshot = stockSnapshots[index];
        final data = stockSnapshot.data() ?? {};
        final currentStock = (data['stockQuantity'] as num? ?? data['stock'] as num? ?? 0).toDouble();

        if (currentStock + 0.000001 < item.quantity) {
          throw StateError('Stock insuficiente para ${item.product.name}');
        }

        final nextStock = currentStock - item.quantity;
        transaction.set(stockRef, {
          'businessId': businessId,
          'storeId': storeId,
          'productId': item.product.id,
          'stock': nextStock.round(),
          'stockQuantity': nextStock,
          'lowStockAlert': item.product.lowStockAlertQuantity.round(),
          'lowStockAlertQuantity': item.product.lowStockAlertQuantity,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        final movementRef = _db.collection('businesses').doc(businessId).collection('inventoryMovements').doc();
        transaction.set(movementRef, {
          'businessId': businessId,
          'storeId': storeId,
          'productId': item.product.id,
          'productName': item.product.name,
          'type': 'sale',
          'previousQuantity': currentStock,
          'newQuantity': nextStock,
          'difference': -item.quantity,
          'reason': 'Venta folio $folio',
          'employeeId': employeeId,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      final saleRef = _db.collection('businesses').doc(businessId).collection('sales').doc();
      transaction.set(saleRef, {
        'businessId': businessId,
        'folio': folio,
        'storeId': storeId,
        'employeeId': employeeId,
        'shiftId': shiftId,
        'createdByUid': uid,
        'items': items.map((item) => item.toMap()).toList(),
        'subtotal': subtotal,
        'discountTotal': discountTotal,
        'taxTotal': 0,
        'total': total,
        'paymentMethod': paymentMethod,
        'cashReceived': cashReceived,
        'changeDue': changeDue,
        'type': 'sale',
        'refund': false,
        'refundIds': [],
        'status': 'paid',
        'createdAt': FieldValue.serverTimestamp(),
        'clientCreatedAt': Timestamp.now(),
      });

      transaction.set(counterRef, {
        'nextSaleNumber': nextSaleNumber + 1,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    });

    return createdFolio;
  }

  Stream<List<Sale>> watchSales({
    required String businessId,
    required String storeId,
  }) {
    return _db
        .collection('businesses')
        .doc(businessId)
        .collection('sales')
        .snapshots()
        .map((snapshot) {
      final sales = snapshot.docs
          .map(Sale.fromDoc)
          .where((sale) => sale.storeId == storeId)
          .toList();
      sales.sort((a, b) {
        final aDate = a.createdAt ?? a.clientCreatedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bDate = b.createdAt ?? b.clientCreatedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return bDate.compareTo(aDate);
      });
      return sales;
    });
  }

  Stream<List<Sale>> watchBusinessSales({required String businessId}) {
    return _db.collection('businesses').doc(businessId).collection('sales').snapshots().map((snapshot) {
      final sales = snapshot.docs.map(Sale.fromDoc).toList();
      sales.sort((a, b) {
        final aDate = a.createdAt ?? a.clientCreatedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bDate = b.createdAt ?? b.clientCreatedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return bDate.compareTo(aDate);
      });
      return sales;
    });
  }

  Future<String> cancelSale({
    required String businessId,
    required Sale sale,
    required List<Map<String, dynamic>> returnItems,
    required bool returnInventory,
    required String reason,
    String? refundShiftId,
    String? refundEmployeeId,
  }) async {
    await _connectivityService.requireConnection('Cancelar venta');
    if (returnItems.isEmpty) {
      throw StateError('Selecciona al menos un producto para devolver');
    }

    final salesRef = _db.collection('businesses').doc(businessId).collection('sales');
    final saleRef = salesRef.doc(sale.id);
    final refundRef = salesRef.doc();
    final productRefs = <DocumentReference<Map<String, dynamic>>>[];
    final restockItems = <Map<String, dynamic>>[];
    final counterRef = _db
        .collection('businesses')
        .doc(businessId)
        .collection('counters')
        .doc('sales');

    if (returnInventory) {
      for (final item in returnItems) {
        final productId = item['productId'] as String? ?? '';
        if (productId.isEmpty) continue;
        restockItems.add(item);
        productRefs.add(
          _db.collection('businesses').doc(businessId).collection('products').doc(productId),
        );
      }
    }

    await _db.runTransaction((transaction) async {
      final saleSnapshot = await transaction.get(saleRef);
      final counterSnapshot = await transaction.get(counterRef);
      final productSnapshots = <DocumentSnapshot<Map<String, dynamic>>>[];
      final stockRefs = productRefs.map((productRef) => productRef.collection('stockByStore').doc(sale.storeId)).toList();
      final stockSnapshots = <DocumentSnapshot<Map<String, dynamic>>>[];
      for (final productRef in productRefs) {
        productSnapshots.add(await transaction.get(productRef));
      }
      for (final stockRef in stockRefs) {
        stockSnapshots.add(await transaction.get(stockRef));
      }

      final saleData = saleSnapshot.data() ?? {};
      if (!saleSnapshot.exists || saleData['status'] == 'cancelled' || saleData['status'] == 'refund') {
        throw StateError('Esta venta ya fue cancelada o no existe');
      }

      final nextRefundNumber = (counterSnapshot.data()?['nextRefundNumber'] as num? ?? 1).toInt();
      final refundFolio = 'D-${nextRefundNumber.toString().padLeft(6, '0')}';

      for (var index = 0; index < productRefs.length; index++) {
        final productSnapshot = productSnapshots[index];
        if (!productSnapshot.exists) continue;
        final item = restockItems[index];
        final quantity = (item['quantity'] as num? ?? 0).toDouble();
        if (quantity <= 0) continue;

        final stockRef = stockRefs[index];
        final stockSnapshot = stockSnapshots[index];
        final stockData = stockSnapshot.data() ?? {};
        final currentStoreStock = (stockData['stockQuantity'] as num? ?? stockData['stock'] as num? ?? 0).toDouble();
        final nextStoreStock = currentStoreStock + quantity;
        transaction.set(stockRef, {
          'businessId': businessId,
          'storeId': sale.storeId,
          'productId': item['productId'],
          'stock': nextStoreStock.round(),
          'stockQuantity': nextStoreStock,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        final movementRef = _db.collection('businesses').doc(businessId).collection('inventoryMovements').doc();
        transaction.set(movementRef, {
          'businessId': businessId,
          'storeId': sale.storeId,
          'productId': item['productId'],
          'productName': item['name'] ?? '',
          'type': 'refund',
          'previousQuantity': currentStoreStock,
          'newQuantity': nextStoreStock,
          'difference': quantity,
          'reason': 'Devolucion $refundFolio - $reason',
          'employeeId': refundEmployeeId ?? sale.employeeId,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      final previousReturnedItems = List<Map<String, dynamic>>.from(
        (saleData['returnedItems'] as List? ?? const []).map(
          (item) => Map<String, dynamic>.from(item as Map? ?? const {}),
        ),
      );
      _validateReturnQuantities(sale.items, previousReturnedItems, returnItems);
      final mergedReturnedItems = [...previousReturnedItems, ...returnItems];
      final isFullReturn = _isFullReturn(sale.items, mergedReturnedItems);
      final refundSubtotal = _refundSubtotal(returnItems);
      final refundDiscount = sale.subtotal <= 0 ? 0 : sale.discountTotal * (refundSubtotal / sale.subtotal);
      final refundTotal = (refundSubtotal - refundDiscount).clamp(0, double.infinity);
      final now = Timestamp.now();

      transaction.set(refundRef, {
        'businessId': sale.businessId,
        'folio': refundFolio,
        'storeId': sale.storeId,
        'employeeId': refundEmployeeId ?? sale.employeeId,
        'shiftId': refundShiftId ?? sale.shiftId,
        'originalSaleId': sale.id,
        'items': returnItems,
        'subtotal': refundSubtotal,
        'discountTotal': refundDiscount,
        'taxTotal': 0,
        'total': refundTotal,
        'paymentMethod': sale.paymentMethod,
        'cashReceived': null,
        'changeDue': null,
        'status': 'refund',
        'type': 'refund',
        'refund': true,
        'folioType': 'refund',
        'cancelReason': reason.trim().isEmpty ? 'Sin motivo especificado' : reason.trim(),
        'inventoryReturned': returnInventory,
        'refundCreatedFrom': 'receipts_screen',
        'createdAt': FieldValue.serverTimestamp(),
        'clientCreatedAt': now,
      });

      transaction.set(counterRef, {
        'nextRefundNumber': nextRefundNumber + 1,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      transaction.update(saleRef, {
        'status': isFullReturn ? 'cancelled' : 'partially_cancelled',
        'cancelReason': reason.trim().isEmpty ? 'Sin motivo especificado' : reason.trim(),
        'inventoryReturned': returnInventory,
        'returnedItems': mergedReturnedItems,
        'refundIds': FieldValue.arrayUnion([refundRef.id]),
        'lastRefundId': refundRef.id,
        'cancelledAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });

    return refundRef.id;
  }

  Future<bool> refundExists({
    required String businessId,
    required String refundId,
  }) async {
    final doc = await _db.collection('businesses').doc(businessId).collection('sales').doc(refundId).get();
    return doc.exists;
  }

  double _refundSubtotal(List<Map<String, dynamic>> returnItems) {
    return returnItems.fold<double>(0, (total, item) => total + (item['subtotal'] as num? ?? 0).toDouble());
  }

  bool _isFullReturn(List<Map<String, dynamic>> originalItems, List<Map<String, dynamic>> returnedItems) {
    for (final item in originalItems) {
      final productId = item['productId'] as String? ?? '';
      final originalQuantity = (item['quantity'] as num? ?? 0).toDouble();
      final returnedQuantity = returnedItems
          .where((returnedItem) => returnedItem['productId'] == productId)
          .fold<double>(0, (total, returnedItem) => total + (returnedItem['quantity'] as num? ?? 0).toDouble());
      if (returnedQuantity + 0.000001 < originalQuantity) {
        return false;
      }
    }
    return true;
  }

  void _validateReturnQuantities(
    List<Map<String, dynamic>> originalItems,
    List<Map<String, dynamic>> previousReturnedItems,
    List<Map<String, dynamic>> newReturnItems,
  ) {
    for (final returnItem in newReturnItems) {
      final productId = returnItem['productId'] as String? ?? '';
      final originalQuantity = originalItems
          .where((item) => item['productId'] == productId)
          .fold<double>(0, (total, item) => total + (item['quantity'] as num? ?? 0).toDouble());
      final previousReturnedQuantity = previousReturnedItems
          .where((item) => item['productId'] == productId)
          .fold<double>(0, (total, item) => total + (item['quantity'] as num? ?? 0).toDouble());
      final newReturnQuantity = newReturnItems
          .where((item) => item['productId'] == productId)
          .fold<double>(0, (total, item) => total + (item['quantity'] as num? ?? 0).toDouble());

      if (newReturnQuantity <= 0 || previousReturnedQuantity + newReturnQuantity > originalQuantity + 0.000001) {
        throw StateError('La cantidad a devolver supera lo disponible');
      }
    }
  }
}
