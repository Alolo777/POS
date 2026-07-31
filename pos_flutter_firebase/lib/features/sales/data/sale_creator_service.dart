import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../shared/models/cart_item.dart';
import '../../../core/offline/sync_queue.dart';
import '../../../core/network/connectivity_service.dart';
import '../../inventory/data/stock_service.dart';

class SaleCreatorService {
  SaleCreatorService({
    required ConnectivityService connectivityService,
    required StockService stockService,
    FirebaseFirestore? firestore,
  })  : _db = firestore ?? FirebaseFirestore.instance,
        _connectivityService = connectivityService,
        _stockService = stockService;

  final FirebaseFirestore _db;
  final ConnectivityService _connectivityService;
  final StockService _stockService;

  FirebaseAuth get _authInstance => FirebaseAuth.instance;

  CollectionReference _salesRef(String businessId) =>
      _db.collection('businesses').doc(businessId).collection('sales');

  DocumentReference _counterRef(String businessId) =>
      _db.collection('businesses').doc(businessId).collection('counters').doc('sales');

  DocumentReference _stockRef(String businessId, String productId, String storeId) =>
      _db.collection('businesses').doc(businessId).collection('products').doc(productId).collection('stockByStore').doc(storeId);

  CollectionReference _movementsRef(String businessId) =>
      _db.collection('businesses').doc(businessId).collection('inventoryMovements');

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
    if (!await _connectivityService.hasConnection()) {
      final cachedStock = _stockService.getCachedStock(businessId);
      for (final item in items) {
        if (item.product.trackStock) {
          final productStock = cachedStock?[item.product.id];
          final cachedStockQty = productStock?.stockQuantity ?? 0.0;
          if (cachedStockQty < item.quantity) {
            throw StateError(
              'Stock insuficiente para ${item.product.name}: disponible $cachedStockQty, requerido ${item.quantity}',
            );
          }
        }
      }

      final offlineFolio = 'OFFLINE-${DateTime.now().millisecondsSinceEpoch}';
      await SyncQueue.enqueue(
        type: 'createSale',
        data: {
          'businessId': businessId,
          'storeId': storeId,
          'employeeId': employeeId,
          'shiftId': shiftId,
          'items': items.map((i) => i.toMap()).toList(),
          'subtotal': subtotal,
          'discountTotal': discountTotal,
          'total': total,
          'paymentMethod': paymentMethod,
          'cashReceived': cashReceived,
          'changeDue': changeDue,
          'folio': offlineFolio,
          'createdAt': DateTime.now().toIso8601String(),
        },
      );

      for (final item in items) {
        if (item.product.trackStock) {
          await _stockService.applyLocalStockDelta(
            businessId: businessId,
            productId: item.product.id,
            delta: -item.quantity,
          );
        }
      }

      return offlineFolio;
    }

    final result = await _db.runTransaction((txn) async {
      final stockSnapshots = <String, double>{};
      for (final item in items) {
        if (item.product.trackStock) {
          final stockDoc = await txn.get(_stockRef(businessId, item.product.id, storeId));
          final currentStock = (stockDoc.data() as Map<String, dynamic>?)?['stockQuantity'] ?? 0.0;
          stockSnapshots[item.product.id] = (currentStock as num).toDouble();
        }
      }

      for (final item in items) {
        if (item.product.trackStock) {
          final currentStock = stockSnapshots[item.product.id]!;
          if (currentStock < item.quantity) {
            throw StateError('Stock insuficiente para ${item.product.name}: disponible $currentStock, requerido ${item.quantity}');
          }
        }
      }

      final counterDoc = await txn.get(_counterRef(businessId));
      final currentNumber = (counterDoc.data() as Map<String, dynamic>?)?['nextSaleNumber'] ?? 1;
      final folio = 'T-${(currentNumber as int).toString().padLeft(6, '0')}';

      final uid = createdByUid ?? _authInstance.currentUser?.uid ?? 'unknown';

      for (final item in items) {
        if (item.product.trackStock) {
          final stockRef = _stockRef(businessId, item.product.id, storeId);
          final newStock = stockSnapshots[item.product.id]! - item.quantity;
          txn.set(stockRef, {
            'stockQuantity': newStock,
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));

          txn.set(_movementsRef(businessId).doc(), {
            'businessId': businessId,
            'productId': item.product.id,
            'productName': item.product.name,
            'storeId': storeId,
            'type': 'sale',
            'quantity': -item.quantity,
            'previousStock': stockSnapshots[item.product.id],
            'newStock': newStock,
            'saleFolio': folio,
            'employeeId': employeeId,
            'createdAt': FieldValue.serverTimestamp(),
          });
        }
      }

      txn.set(_counterRef(businessId), {
        'nextSaleNumber': currentNumber + 1,
      }, SetOptions(merge: true));

      final saleData = {
        'businessId': businessId,
        'storeId': storeId,
        'employeeId': employeeId,
        'shiftId': shiftId,
        'folio': folio,
        'items': items.map((i) => i.toMap()).toList(),
        'subtotal': subtotal,
        'discountTotal': discountTotal,
        'total': total,
        'paymentMethod': paymentMethod,
        'cashReceived': cashReceived,
        'changeDue': changeDue,
        'status': 'active',
        'createdByUid': uid,
        'clientCreatedAt': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
      };

      txn.set(_salesRef(businessId).doc(), saleData);

      return folio;
    });

    return result;
  }
}
