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
          if (item.chickenCount != null) {
            final cachedChickens = productStock?.chickenCount ?? 0;
            if (cachedChickens < item.chickenCount!) {
              throw StateError(
                'No hay suficientes pollos para ${item.product.name}: '
                'disponibles $cachedChickens, requeridos ${item.chickenCount}',
              );
            }
          }
        }
      }

      final swapOutNeeded = <String, ({String name, double needed})>{};
      for (final item in items) {
        for (final swap in item.pieceSwaps) {
          final entry = swapOutNeeded[swap.productId];
          if (swap.isOut) {
            swapOutNeeded[swap.productId] = (
              name: swap.productName,
              needed: (entry?.needed ?? 0) + swap.weight,
            );
          }
        }
      }
      for (final MapEntry(key: productId, value: entry) in swapOutNeeded.entries) {
        final available = cachedStock?[productId]?.stockQuantity ?? 0.0;
        if (available < entry.needed) {
          throw StateError(
            'Stock insuficiente para intercambio de ${entry.name}: '
            'disponible $available, requerido ${entry.needed}',
          );
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
          final chickenCount = item.chickenCount;
          await _stockService.applyLocalStockDelta(
            businessId: businessId,
            productId: item.product.id,
            delta: -item.quantity,
            chickenDelta: chickenCount == null ? null : -chickenCount,
          );
        }
      }
      for (final item in items) {
        for (final swap in item.pieceSwaps) {
          await _stockService.applyLocalStockDelta(
            businessId: businessId,
            productId: swap.productId,
            delta: swap.isOut ? -swap.weight : swap.weight,
          );
        }
      }

      return offlineFolio;
    }

    final result = await _db.runTransaction((txn) async {
      final stockSnapshots = <String, double>{};
      final chickenSnapshots = <String, int>{};
      for (final item in items) {
        if (item.product.trackStock) {
          final stockDoc = await txn.get(_stockRef(businessId, item.product.id, storeId));
          final stockData = stockDoc.data() as Map<String, dynamic>?;
          final currentStock = (stockData?['stockQuantity'] ?? 0.0);
          stockSnapshots[item.product.id] = (currentStock as num).toDouble();
          if (item.chickenCount != null) {
            final currentChickens = stockData?['chickenCount'] as int? ?? 0;
            if (currentChickens < item.chickenCount!) {
              throw StateError(
                'No hay suficientes pollos para ${item.product.name}: '
                'disponibles $currentChickens, requeridos ${item.chickenCount}',
              );
            }
            chickenSnapshots[item.product.id] = currentChickens;
          }
        }
      }

      final swapStockSnapshots = <String, double>{};
      for (final item in items) {
        for (final swap in item.pieceSwaps) {
          if (!swapStockSnapshots.containsKey(swap.productId)) {
            final stockDoc = await txn.get(_stockRef(businessId, swap.productId, storeId));
            final stockData = stockDoc.data() as Map<String, dynamic>?;
            swapStockSnapshots[swap.productId] =
                ((stockData?['stockQuantity'] ?? 0.0) as num).toDouble();
          }
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

      final swapDeltas = <String, ({String name, double delta})>{};
      for (final item in items) {
        for (final swap in item.pieceSwaps) {
          final current = swapDeltas[swap.productId];
          final delta = swap.isOut ? -swap.weight : swap.weight;
          swapDeltas[swap.productId] = (
            name: swap.productName,
            delta: (current?.delta ?? 0) + delta,
          );
        }
      }
      for (final MapEntry(key: productId, value: entry) in swapDeltas.entries) {
        final currentStock = swapStockSnapshots[productId]!;
        if (currentStock + entry.delta < -0.000001) {
          throw StateError(
            'Stock insuficiente para intercambio de ${entry.name}: '
            'disponible $currentStock',
          );
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
          final stockUpdate = <String, dynamic>{
            'stockQuantity': newStock,
            'updatedAt': FieldValue.serverTimestamp(),
          };
          if (item.chickenCount != null) {
            stockUpdate['chickenCount'] = chickenSnapshots[item.product.id]! - item.chickenCount!;
          }
          txn.set(stockRef, stockUpdate, SetOptions(merge: true));

          txn.set(_movementsRef(businessId).doc(), {
            'businessId': businessId,
            'productId': item.product.id,
            'productName': item.product.name,
            'storeId': storeId,
            'type': 'sale',
            'quantity': -item.quantity,
            'previousQuantity': stockSnapshots[item.product.id],
            'newQuantity': newStock,
            'previousStock': stockSnapshots[item.product.id],
            'newStock': newStock,
            'difference': -item.quantity,
            'reason': item.chickenCount != null
                ? 'Venta $folio (${item.chickenCount} pollos)'
                : 'Venta $folio',
            'saleFolio': folio,
            'employeeId': employeeId,
            'createdAt': FieldValue.serverTimestamp(),
          });
        }
      }

      for (final MapEntry(key: productId, value: entry) in swapDeltas.entries) {
        final previous = swapStockSnapshots[productId]!;
        final newStock = previous + entry.delta;
        txn.set(_stockRef(businessId, productId, storeId), {
          'stockQuantity': newStock,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        txn.set(_movementsRef(businessId).doc(), {
          'businessId': businessId,
          'productId': productId,
          'productName': entry.name,
          'storeId': storeId,
          'type': 'swap',
          'quantity': entry.delta,
          'previousQuantity': previous,
          'newQuantity': newStock,
          'previousStock': previous,
          'newStock': newStock,
          'difference': entry.delta,
          'reason': entry.delta < 0
              ? 'Intercambio $folio (${entry.name} entregada)'
              : 'Intercambio $folio (${entry.name} devuelta)',
          'saleFolio': folio,
          'employeeId': employeeId,
          'createdAt': FieldValue.serverTimestamp(),
        });
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
