import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../shared/models/sale.dart';
import '../../../core/offline/sync_queue.dart';
import '../../../core/network/connectivity_service.dart';
import '../../inventory/data/stock_service.dart';

class SaleRefundService {
  SaleRefundService({
    required ConnectivityService connectivityService,
    required StockService stockService,
    FirebaseFirestore? firestore,
  })  : _db = firestore ?? FirebaseFirestore.instance,
        _connectivityService = connectivityService,
        _stockService = stockService;

  final FirebaseFirestore _db;
  final ConnectivityService _connectivityService;
  final StockService _stockService;

  CollectionReference _salesRef(String businessId) =>
      _db.collection('businesses').doc(businessId).collection('sales');

  DocumentReference _counterRef(String businessId) =>
      _db.collection('businesses').doc(businessId).collection('counters').doc('sales');

  DocumentReference _stockRef(String businessId, String productId, String storeId) =>
      _db.collection('businesses').doc(businessId).collection('products').doc(productId).collection('stockByStore').doc(storeId);

  CollectionReference _movementsRef(String businessId) =>
      _db.collection('businesses').doc(businessId).collection('inventoryMovements');

  Future<String> cancelSale({
    required String businessId,
    required Sale sale,
    required List<Map<String, dynamic>> returnItems,
    required bool returnInventory,
    required String reason,
    String? refundShiftId,
    String? refundEmployeeId,
  }) async {
    if (returnItems.isEmpty) {
      throw StateError('No hay ítems para devolver');
    }

    _validateReturnQuantities(
      originalItems: sale.items,
      newReturnItems: returnItems,
    );

    if (!await _connectivityService.hasConnection()) {
      final offlineRefundId = 'OFFLINE-REFUND-${DateTime.now().millisecondsSinceEpoch}';
      await SyncQueue.enqueue(
        type: 'cancelSale',
        data: {
          'businessId': businessId,
          'saleId': sale.id,
          'storeId': sale.storeId,
          'returnItems': returnItems,
          'returnInventory': returnInventory,
          'reason': reason,
          'refundShiftId': refundShiftId,
          'refundEmployeeId': refundEmployeeId,
          'refundId': offlineRefundId,
          'createdAt': DateTime.now().toIso8601String(),
        },
      );

      if (returnInventory) {
        for (final item in returnItems) {
          final productId = item['productId'] as String;
          final quantity = (item['quantity'] as num).toDouble();
          final chickenCount = item['chickenCount'] as int?;
          await _stockService.applyLocalStockDelta(
            businessId: businessId,
            productId: productId,
            delta: quantity,
            chickenDelta: chickenCount,
          );
          final swapsData = item['pieceSwaps'];
          if (swapsData is List) {
            for (final swapData in swapsData) {
              final swapMap = swapData as Map<String, dynamic>;
              final swapProductId = swapMap['productId'] as String? ?? '';
              final delta = (swapMap['delta'] as num? ?? 0).toDouble();
              if (swapProductId.isEmpty || delta == 0) continue;
              await _stockService.applyLocalStockDelta(
                businessId: businessId,
                productId: swapProductId,
                delta: delta,
              );
            }
          }
        }
      }

      return offlineRefundId;
    }

    final result = await _db.runTransaction((txn) async {
      final saleDoc = await txn.get(_salesRef(businessId).doc(sale.id));
      if (!saleDoc.exists) throw StateError('Venta no encontrada');
      final saleData = saleDoc.data() as Map<String, dynamic>;
      if (saleData['status'] == 'cancelled') throw StateError('La venta ya fue cancelada');

      final counterDoc = await txn.get(_counterRef(businessId));
      final currentRefundNumber = (counterDoc.data() as Map<String, dynamic>?)?['nextRefundNumber'] ?? 1;
      final refundFolio = 'D-${(currentRefundNumber as int).toString().padLeft(6, '0')}';
      final nextRefundNumber = currentRefundNumber + 1;

      final stockSnapshots = <String, double>{};
      final chickenSnapshots = <String, int>{};
      final swapDeltas = <String, ({String name, double delta})>{};
      if (returnInventory) {
        for (final item in returnItems) {
          final productId = item['productId'] as String;
          final productDoc = await txn.get(
            _db.collection('businesses').doc(businessId).collection('products').doc(productId),
          );
          if (!productDoc.exists) continue;

          final stockRef = _stockRef(businessId, productId, sale.storeId);
          final stockDoc = await txn.get(stockRef);
          final stockData = stockDoc.data() as Map<String, dynamic>?;
          final currentStock = (stockData?['stockQuantity'] ?? 0.0);
          final newStock = (currentStock as num).toDouble() + (item['quantity'] as num).toDouble();
          stockSnapshots[productId] = newStock;
          final chickenCount = item['chickenCount'] as int?;
          if (chickenCount != null) {
            final currentChickens = stockData?['chickenCount'] as int? ?? 0;
            chickenSnapshots[productId] = currentChickens + chickenCount;
          }

          final swapsData = item['pieceSwaps'];
          if (swapsData is List) {
            for (final swapData in swapsData) {
              final swapMap = swapData as Map<String, dynamic>;
              final swapProductId = swapMap['productId'] as String? ?? '';
              final delta = (swapMap['delta'] as num? ?? 0).toDouble();
              if (swapProductId.isEmpty || delta == 0) continue;
              final current = swapDeltas[swapProductId];
              swapDeltas[swapProductId] = (
                name: swapMap['productName'] as String? ?? '',
                delta: (current?.delta ?? 0) + delta,
              );
            }
          }
        }
        for (final productId in swapDeltas.keys) {
          final stockDoc = await txn.get(_stockRef(businessId, productId, sale.storeId));
          final stockData = stockDoc.data() as Map<String, dynamic>?;
          final currentStock = (stockData?['stockQuantity'] ?? 0.0);
          stockSnapshots[productId] = (currentStock as num).toDouble() + swapDeltas[productId]!.delta;
        }
      }

      txn.set(_counterRef(businessId), {
        'nextRefundNumber': nextRefundNumber,
      }, SetOptions(merge: true));

      final refundSubtotal = _refundSubtotal(returnItems);
      final isFullReturn = _isFullReturn(sale.items, returnItems);
      final newStatus = isFullReturn ? 'cancelled' : 'partially_cancelled';

      if (returnInventory) {
        for (final item in returnItems) {
          final productId = item['productId'] as String;
          final newStock = stockSnapshots[productId];
          if (newStock == null) continue;

          final quantity = (item['quantity'] as num).toDouble();
          final previousStock = newStock - quantity;

          final stockUpdate = <String, dynamic>{
            'stockQuantity': newStock,
            'updatedAt': FieldValue.serverTimestamp(),
          };
          if (item['chickenCount'] != null) {
            stockUpdate['chickenCount'] = chickenSnapshots[productId]!;
          }

          txn.set(_stockRef(businessId, productId, sale.storeId), stockUpdate, SetOptions(merge: true));

          txn.set(_movementsRef(businessId).doc(), {
            'businessId': businessId,
            'productId': productId,
            'productName': item['name'] ?? '',
            'storeId': sale.storeId,
            'type': 'refund',
            'difference': quantity,
            'previousQuantity': previousStock,
            'newQuantity': newStock,
            'previousStock': previousStock,
            'newStock': newStock,
            'reason': 'Devolución $refundFolio',
            'saleFolio': sale.folio,
            'refundFolio': refundFolio,
            'employeeId': refundEmployeeId,
            'createdAt': FieldValue.serverTimestamp(),
          });
        }

        for (final MapEntry(key: swapProductId, value: swapEntry) in swapDeltas.entries) {
          final newStock = stockSnapshots[swapProductId];
          if (newStock == null) continue;
          final previousStock = newStock - swapEntry.delta;
          txn.set(_stockRef(businessId, swapProductId, sale.storeId), {
            'stockQuantity': newStock,
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
          txn.set(_movementsRef(businessId).doc(), {
            'businessId': businessId,
            'productId': swapProductId,
            'productName': swapEntry.name,
            'storeId': sale.storeId,
            'type': 'swap',
            'difference': swapEntry.delta,
            'previousQuantity': previousStock,
            'newQuantity': newStock,
            'previousStock': previousStock,
            'newStock': newStock,
            'reason': swapEntry.delta > 0
                ? 'Devolución $refundFolio (${swapEntry.name}: regresa pieza entregada)'
                : 'Devolución $refundFolio (${swapEntry.name}: se retira pieza devuelta)',
            'saleFolio': sale.folio,
            'refundFolio': refundFolio,
            'employeeId': refundEmployeeId,
            'createdAt': FieldValue.serverTimestamp(),
          });
        }
      }

      final refundData = {
        'businessId': businessId,
        'storeId': sale.storeId,
        'employeeId': refundEmployeeId,
        'shiftId': refundShiftId,
        'folio': refundFolio,
        'originalSaleId': sale.id,
        'originalFolio': sale.folio,
        'type': 'refund',
        'items': returnItems,
        'subtotal': refundSubtotal,
        'total': refundSubtotal,
        'paymentMethod': sale.paymentMethod,
        'status': 'refund',
        'reason': reason,
        'createdAt': FieldValue.serverTimestamp(),
        'clientCreatedAt': FieldValue.serverTimestamp(),
      };

      txn.set(_salesRef(businessId).doc(), refundData);

      final updatedItems = sale.items.map((item) {
        final returnedItem = returnItems.firstWhere(
          (r) => r['productId'] == item['productId'],
          orElse: () => {},
        );
        if (returnedItem.isNotEmpty) {
          final returnedQty = (returnedItem['quantity'] as num? ?? 0).toDouble();
          return {
            ...item,
            'returnedQuantity': (item['returnedQuantity'] as num? ?? 0).toDouble() + returnedQty,
          };
        }
        return item;
      }).toList();

      txn.update(_salesRef(businessId).doc(sale.id), {
        'status': newStatus,
        'items': updatedItems,
        'cancelledAt': FieldValue.serverTimestamp(),
      });

      return refundFolio;
    });

    return result;
  }

  Future<bool> refundExists({
    required String businessId,
    required String refundId,
  }) async {
    if (refundId.startsWith('OFFLINE-')) return false;
    final snapshot = await _salesRef(businessId)
        .where('folio', isEqualTo: refundId)
        .where('type', isEqualTo: 'refund')
        .limit(1)
        .get();
    return snapshot.docs.isNotEmpty;
  }

  double _refundSubtotal(List<Map<String, dynamic>> returnItems) {
    return returnItems.fold<double>(0, (sum, item) {
      return sum + ((item['subtotal'] as num?) ?? 0).toDouble();
    });
  }

  bool _isFullReturn(
    List<Map<String, dynamic>> originalItems,
    List<Map<String, dynamic>> returnedItems,
  ) {
    for (final original in originalItems) {
      final productId = original['productId'];
      final originalQty = (original['quantity'] as num).toDouble();
      final alreadyReturned = (original['returnedQuantity'] as num? ?? 0).toDouble();
      final newReturn = returnedItems
          .where((r) => r['productId'] == productId)
          .fold<double>(0, (sum, r) => sum + ((r['quantity'] as num?) ?? 0).toDouble());
      if (alreadyReturned + newReturn < originalQty) return false;
    }
    return true;
  }

  void _validateReturnQuantities({
    required List<Map<String, dynamic>> originalItems,
    required List<Map<String, dynamic>> newReturnItems,
  }) {
    for (final returnItem in newReturnItems) {
      final productId = returnItem['productId'];
      final returnQty = (returnItem['quantity'] as num).toDouble();
      final original = originalItems.firstWhere(
        (o) => o['productId'] == productId,
        orElse: () => throw StateError('Producto $productId no encontrado en la venta original'),
      );
      final originalQty = (original['quantity'] as num).toDouble();
      final alreadyReturned = (original['returnedQuantity'] as num? ?? 0).toDouble();
      final available = originalQty - alreadyReturned;
      if (returnQty > available) {
        throw StateError(
          'Cantidad a devolver ($returnQty) excede la disponible ($available) para el producto $productId',
        );
      }
    }
  }
}
