import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:meta/meta.dart';

import 'sync_service.dart';

FirebaseFirestore _firestore = FirebaseFirestore.instance;

/// Solo para pruebas: permite reemplazar la instancia de Firestore que usan los
/// handlers de sincronización sin tocar el resto del código de la app.
@visibleForTesting
void overrideSyncFirestore(FirebaseFirestore firestore) => _firestore = firestore;

Map<String, SyncHandler> createSyncHandlers() {
  return {
    'addProduct': _handleAddProduct,
    'updateProduct': _handleUpdateProduct,
    'deactivateProduct': _handleDeactivateProduct,
    'createSale': _handleCreateSale,
    'cancelSale': _handleCancelSale,
    'openShift': _handleOpenShift,
    'addCashMovement': _handleAddCashMovement,
    'closeShift': _handleCloseShift,
    'addCategory': _handleAddCategory,
    'updateCategory': _handleUpdateCategory,
    'deactivateCategory': _handleDeactivateCategory,
    'addDiscount': _handleAddDiscount,
    'updateDiscount': _handleUpdateDiscount,
    'deactivateDiscount': _handleDeactivateDiscount,
    'addEmployee': _handleAddEmployee,
    'updateEmployee': _handleUpdateEmployee,
    'deactivateEmployee': _handleDeactivateEmployee,
    'addModifier': _handleAddModifier,
    'updateModifier': _handleUpdateModifier,
    'deactivateModifier': _handleDeactivateModifier,
    'adjustStock': _handleAdjustStock,
    'saveOpenTicket': _handleSaveOpenTicket,
    'closeOpenTicket': _handleCloseOpenTicket,
    'cancelOpenTicket': _handleCancelOpenTicket,
    'updateBusiness': _handleUpdateBusiness,
    'addStore': _handleAddStore,
    'updateStore': _handleUpdateStore,
  };
}

String? _optString(Map<String, dynamic> data, String key) => data[key] as String?;
String _str(Map<String, dynamic> data, String key) => data[key] as String;
double _dbl(Map<String, dynamic> data, String key) => (data[key] as num).toDouble();
int _int(Map<String, dynamic> data, String key) => (data[key] as num).toInt();
bool _bool(Map<String, dynamic> data, String key) => data[key] as bool;

/// Convierte el timestamp del cliente (enviado como String ISO en la cola
/// offline) a un [Timestamp] de Firestore, para que `clientCreatedAt` sea
/// siempre del mismo tipo en línea y offline.
Timestamp _clientTimestamp(dynamic value) {
  if (value is Timestamp) return value;
  if (value is String) {
    final parsed = DateTime.tryParse(value);
    if (parsed != null) return Timestamp.fromDate(parsed);
  }
  return Timestamp.now();
}

Future<void> _handleAddProduct(Map<String, dynamic> data) async {
  final businessId = _str(data, 'businessId');
  final productRef = _firestore.collection('businesses').doc(businessId).collection('products').doc();
  final trackStock = _bool(data, 'trackStock');
  final stockQuantity = _dbl(data, 'stockQuantity');
  final lowStockAlertQuantity = _dbl(data, 'lowStockAlertQuantity');
  await productRef.set({
    'businessId': businessId,
    'name': _str(data, 'name'),
    'description': '',
    'sku': _str(data, 'ref'),
    'barcode': '',
    'categoryId': data['categoryId'],
    'categoryName': data['categoryName'],
    'sellBy': _str(data, 'sellBy'),
    'imageUrl': null,
    'localImagePath': data['localImagePath'],
    'price': _dbl(data, 'price'),
    'cost': _dbl(data, 'cost'),
    'ref': _str(data, 'ref'),
    'trackStock': trackStock,
    'stock': trackStock ? stockQuantity.round() : 0,
    'stockQuantity': trackStock ? stockQuantity : 0,
    'lowStockAlert': trackStock ? lowStockAlertQuantity.round() : 0,
    'lowStockAlertQuantity': trackStock ? lowStockAlertQuantity : 0,
    'presentationType': _str(data, 'presentationType'),
    'presentationShape': _str(data, 'presentationShape'),
    'presentationColor': _int(data, 'presentationColor'),
    'active': true,
    'createdAt': FieldValue.serverTimestamp(),
    'updatedAt': FieldValue.serverTimestamp(),
  });
  final storeId = data['storeId'];
  if (storeId != null && trackStock) {
    await productRef.collection('stockByStore').doc(storeId as String).set({
      'businessId': businessId,
      'storeId': storeId,
      'productId': productRef.id,
      'stock': stockQuantity.round(),
      'stockQuantity': stockQuantity,
      'lowStockAlert': lowStockAlertQuantity.round(),
      'lowStockAlertQuantity': lowStockAlertQuantity,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}

Future<void> _handleUpdateProduct(Map<String, dynamic> data) async {
  final businessId = _str(data, 'businessId');
  final productId = _str(data, 'productId');
  final ref = _str(data, 'ref');
  final oldRef = _str(data, 'oldRef');
  await _firestore.collection('businesses').doc(businessId).collection('products').doc(productId).update({
    'name': _str(data, 'name'),
    'categoryId': data['categoryId'],
    'categoryName': data['categoryName'],
    'sellBy': _str(data, 'sellBy'),
    'price': _dbl(data, 'price'),
    'cost': _dbl(data, 'cost'),
    'ref': ref,
    'trackStock': _bool(data, 'trackStock'),
    'stockQuantity': _dbl(data, 'stockQuantity'),
    'lowStockAlertQuantity': _dbl(data, 'lowStockAlertQuantity'),
    'presentationType': _str(data, 'presentationType'),
    'presentationShape': _str(data, 'presentationShape'),
    'presentationColor': _int(data, 'presentationColor'),
    'localImagePath': data['localImagePath'],
  });
  if (ref != oldRef) {
    final existing = await _firestore.collection('businesses').doc(businessId).collection('products')
        .where('ref', isEqualTo: ref).where(FieldPath.documentId, isNotEqualTo: productId).limit(1).get();
    if (existing.docs.isNotEmpty) {
      await _firestore.collection('businesses').doc(businessId).collection('products').doc(productId).update({'ref': '${ref}_$productId'});
    }
  }

  final storeId = data['storeId'];
  final trackStock = _bool(data, 'trackStock');
  final stockQuantity = _dbl(data, 'stockQuantity');
  final lowStockAlertQuantity = _dbl(data, 'lowStockAlertQuantity');
  if (storeId != null && trackStock) {
    await _firestore
        .collection('businesses').doc(businessId)
        .collection('products').doc(productId)
        .collection('stockByStore').doc(storeId as String)
        .set({
      'businessId': businessId,
      'storeId': storeId,
      'productId': productId,
      'stock': stockQuantity.round(),
      'stockQuantity': stockQuantity,
      'lowStockAlert': lowStockAlertQuantity.round(),
      'lowStockAlertQuantity': lowStockAlertQuantity,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}

Future<void> _handleDeactivateProduct(Map<String, dynamic> data) async {
  final businessId = _str(data, 'businessId');
  final productId = _str(data, 'productId');
  await _firestore.collection('businesses').doc(businessId).collection('products').doc(productId).update({'active': false});
}

Future<void> _handleCreateSale(Map<String, dynamic> data) async {
  final businessId = _str(data, 'businessId');
  final storeId = _str(data, 'storeId');
  final employeeId = _str(data, 'employeeId');
  final shiftId = _str(data, 'shiftId');
  final items = data['items'] as List<dynamic>;
  final clientOpId = data['clientOpId'] as String?;
  final clientCreatedAt = _clientTimestamp(data['createdAt']);

  await _firestore.runTransaction((txn) async {
    final salesRef = _firestore.collection('businesses').doc(businessId).collection('sales');
    final saleRef =
        (clientOpId != null && clientOpId.isNotEmpty) ? salesRef.doc(clientOpId) : salesRef.doc();
    // Idempotencia: si la venta ya se sincronizó, no se vuelve a aplicar.
    if ((await txn.get(saleRef)).exists) return;

    final counterRef = _firestore
        .collection('businesses').doc(businessId)
        .collection('counters').doc('sales');
    final counterDoc = await txn.get(counterRef);
    final currentNumber = counterDoc.data()?['nextSaleNumber'] ?? 1;
    final folio = 'T-${(currentNumber as int).toString().padLeft(6, '0')}';

    DocumentReference stockRef(String productId) => _firestore
        .collection('businesses').doc(businessId)
        .collection('products').doc(productId)
        .collection('stockByStore').doc(storeId);
    final movementsRef = _firestore
        .collection('businesses').doc(businessId)
        .collection('inventoryMovements');

    final stockSnapshots = <String, double>{};
    final chickenSnapshots = <String, int>{};
    final swapStockSnapshots = <String, double>{};
    final swapDeltas = <String, ({String name, double delta})>{};

    for (final raw in items) {
      final item = raw as Map<String, dynamic>;
      final productId = item['productId'] as String?;
      final quantity = (item['quantity'] as num? ?? 0).toDouble();
      if (productId == null || productId.isEmpty || quantity <= 0) continue;

      final stockDoc = await txn.get(stockRef(productId));
      final stockData = stockDoc.data() as Map<String, dynamic>?;
      final currentStock = ((stockData?['stockQuantity'] ?? 0.0) as num).toDouble();
      stockSnapshots[productId] = currentStock;
      if (currentStock < quantity) {
        throw StateError('Stock insuficiente para ${item['name']}: disponible $currentStock');
      }
      final chickenCount = item['chickenCount'] as int?;
      if (chickenCount != null) {
        final currentChickens = stockData?['chickenCount'] as int? ?? 0;
        if (currentChickens < chickenCount) {
          throw StateError('No hay suficientes pollos para ${item['name']}: disponibles $currentChickens');
        }
        chickenSnapshots[productId] = currentChickens;
      }

      final swapsData = item['pieceSwaps'];
      if (swapsData is! List) continue;
      for (final swapData in swapsData) {
        final swap = swapData as Map<String, dynamic>;
        final swapProductId = swap['productId'] as String?;
        final swapName = swap['productName'] as String? ?? '';
        final weight = (swap['weight'] as num? ?? 0).toDouble();
        final isOut = (swap['direction'] as String? ?? 'out') == 'out';
        if (swapProductId == null || swapProductId.isEmpty || weight <= 0) continue;
        if (!swapStockSnapshots.containsKey(swapProductId)) {
          final swapDoc = await txn.get(stockRef(swapProductId));
          swapStockSnapshots[swapProductId] =
              ((swapDoc.data() as Map<String, dynamic>?)?['stockQuantity'] ?? 0.0).toDouble();
        }
        final current = swapDeltas[swapProductId];
        swapDeltas[swapProductId] = (
          name: swapName,
          delta: (current?.delta ?? 0) + (isOut ? -weight : weight),
        );
      }
    }

    for (final MapEntry(key: productId, value: entry) in swapDeltas.entries) {
      final currentStock = swapStockSnapshots[productId]!;
      if (currentStock + entry.delta < -0.000001) {
        throw StateError(
          'Stock insuficiente para intercambio de ${entry.name}: disponible $currentStock',
        );
      }
    }

    for (final raw in items) {
      final item = raw as Map<String, dynamic>;
      final productId = item['productId'] as String?;
      final quantity = (item['quantity'] as num? ?? 0).toDouble();
      if (productId == null || productId.isEmpty || quantity <= 0) continue;

      final previousStock = stockSnapshots[productId]!;
      final newStock = previousStock - quantity;
      final stockUpdate = <String, dynamic>{
        'stockQuantity': newStock,
        'updatedAt': FieldValue.serverTimestamp(),
      };
      final chickenCount = item['chickenCount'] as int?;
      if (chickenCount != null) {
        stockUpdate['chickenCount'] = chickenSnapshots[productId]! - chickenCount;
      }
      txn.set(stockRef(productId), stockUpdate, SetOptions(merge: true));
      txn.set(movementsRef.doc(), {
        'businessId': businessId,
        'storeId': storeId,
        'productId': productId,
        'productName': item['name'] ?? '',
        'type': 'sale',
        'quantity': -quantity,
        'previousQuantity': previousStock,
        'newQuantity': newStock,
        'difference': -quantity,
        'reason': 'Venta $folio',
        'saleFolio': folio,
        'employeeId': employeeId,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }

    for (final MapEntry(key: productId, value: entry) in swapDeltas.entries) {
      final previousStock = swapStockSnapshots[productId]!;
      final newStock = previousStock + entry.delta;
      txn.set(stockRef(productId), {
        'stockQuantity': newStock,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      txn.set(movementsRef.doc(), {
        'businessId': businessId,
        'storeId': storeId,
        'productId': productId,
        'productName': entry.name,
        'type': 'swap',
        'quantity': entry.delta,
        'previousQuantity': previousStock,
        'newQuantity': newStock,
        'difference': entry.delta,
        'reason': entry.delta < 0
            ? 'Intercambio $folio (${entry.name} entregada)'
            : 'Intercambio $folio (${entry.name} devuelta)',
        'saleFolio': folio,
        'employeeId': employeeId,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }

    txn.set(counterRef, {'nextSaleNumber': currentNumber + 1}, SetOptions(merge: true));

    txn.set(saleRef, {
      'businessId': businessId,
      'storeId': storeId,
      'employeeId': employeeId,
      'shiftId': shiftId,
      'folio': folio,
      'items': items,
      'subtotal': _dbl(data, 'subtotal'),
      'discountTotal': _dbl(data, 'discountTotal'),
      'total': _dbl(data, 'total'),
      'paymentMethod': _str(data, 'paymentMethod'),
      'cashReceived': data['cashReceived'],
      'changeDue': data['changeDue'],
      'createdByUid': data['createdByUid'],
      'type': 'sale',
      'status': 'completed',
      'createdAt': FieldValue.serverTimestamp(),
      'clientCreatedAt': clientCreatedAt,
      'offlineFolio': data['folio'],
    });
  });
}

Future<void> _handleCancelSale(Map<String, dynamic> data) async {
  final businessId = _str(data, 'businessId');
  final saleId = _str(data, 'saleId');
  final storeId = _str(data, 'storeId');
  final returnItems = data['returnItems'] as List<dynamic>;
  final returnInventory = _bool(data, 'returnInventory');
  final reason = _optString(data, 'reason') ?? '';
  final refundId = _optString(data, 'refundId') ?? '';
  final refundEmployeeId = _optString(data, 'refundEmployeeId');
  final refundShiftId = _optString(data, 'refundShiftId');
  final clientOpId = data['clientOpId'] as String?;
  final clientCreatedAt = _clientTimestamp(data['createdAt']);

  await _firestore.runTransaction((txn) async {
    final salesRef = _firestore.collection('businesses').doc(businessId).collection('sales');
    final saleRef = salesRef.doc(saleId);
    final refundRef = salesRef.doc(
      (clientOpId != null && clientOpId.isNotEmpty)
          ? clientOpId
          : 'REFUND-${saleId.substring(0, 6)}',
    );
    // Idempotencia: si la devolución ya se sincronizó, no se vuelve a aplicar.
    if ((await txn.get(refundRef)).exists) return;

    final saleDoc = await txn.get(saleRef);
    if (!saleDoc.exists) return;
    final saleData = saleDoc.data() as Map<String, dynamic>;
    final originalItems = (saleData['items'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? [];

    final updatedItems = originalItems.map((item) {
      Map<String, dynamic> returnedItem = const {};
      for (final r in returnItems) {
        final m = r as Map<String, dynamic>;
        if (m['productId'] == item['productId']) {
          returnedItem = m;
          break;
        }
      }
      if (returnedItem.isNotEmpty) {
        final returnedQty = (returnedItem['quantity'] as num? ?? 0).toDouble();
        return {
          ...item,
          'returnedQuantity': (item['returnedQuantity'] as num? ?? 0).toDouble() + returnedQty,
        };
      }
      return item;
    }).toList();

    bool isFullReturn = true;
    for (final original in originalItems) {
      final productId = original['productId'];
      final originalQty = (original['quantity'] as num).toDouble();
      final alreadyReturned = (original['returnedQuantity'] as num? ?? 0).toDouble();
      final newReturn = returnItems
          .where((r) => (r as Map<String, dynamic>)['productId'] == productId)
          .fold<double>(0, (acc, r) => acc + ((r as Map<String, dynamic>)['quantity'] as num? ?? 0).toDouble());
      if (alreadyReturned + newReturn < originalQty) {
        isFullReturn = false;
        break;
      }
    }
    final newStatus = isFullReturn ? 'cancelled' : 'partially_cancelled';

    final counterRef = _firestore.collection('businesses').doc(businessId).collection('counters').doc('sales');
    final counterDoc = await txn.get(counterRef);
    final currentRefundNumber = counterDoc.data()?['nextRefundNumber'] ?? 1;
    final refundFolio = 'D-${(currentRefundNumber as int).toString().padLeft(6, '0')}';

    final movementsRef = _firestore.collection('businesses').doc(businessId).collection('inventoryMovements');
    DocumentReference stockRef(String productId) => _firestore
        .collection('businesses').doc(businessId)
        .collection('products').doc(productId)
        .collection('stockByStore').doc(storeId);

    final stockSnapshots = <String, double>{};
    final chickenSnapshots = <String, int>{};
    final swapStockSnapshots = <String, double>{};
    final swapDeltas = <String, ({String name, double delta})>{};

    if (returnInventory) {
      for (final raw in returnItems) {
        final item = raw as Map<String, dynamic>;
        final productId = item['productId'] as String?;
        final quantity = (item['quantity'] as num? ?? 0).toDouble();
        if (productId == null || productId.isEmpty || quantity <= 0) continue;
        final stockDoc = await txn.get(stockRef(productId));
        final stockData = stockDoc.data() as Map<String, dynamic>?;
        stockSnapshots[productId] = ((stockData?['stockQuantity'] ?? 0.0) as num).toDouble();
        final chickenCount = item['chickenCount'] as int?;
        if (chickenCount != null) {
          chickenSnapshots[productId] = (stockData?['chickenCount'] as int? ?? 0) + chickenCount;
        }
      }

      for (final raw in returnItems) {
        final item = raw as Map<String, dynamic>;
        final swapsData = item['pieceSwaps'];
        if (swapsData is! List) continue;
        for (final swapData in swapsData) {
          final swapMap = swapData as Map<String, dynamic>;
          final swapProductId = swapMap['productId'] as String? ?? '';
          final delta = (swapMap['delta'] as num? ?? 0).toDouble();
          if (swapProductId.isEmpty || delta == 0) continue;
          if (!swapStockSnapshots.containsKey(swapProductId)) {
            final stockDoc = await txn.get(stockRef(swapProductId));
            swapStockSnapshots[swapProductId] =
                ((stockDoc.data() as Map<String, dynamic>?)?['stockQuantity'] ?? 0.0).toDouble();
          }
          final current = swapDeltas[swapProductId];
          swapDeltas[swapProductId] = (
            name: swapMap['productName'] as String? ?? '',
            delta: (current?.delta ?? 0) + delta,
          );
        }
      }
    }

    txn.update(saleRef, {
      'status': newStatus,
      'items': updatedItems,
      'cancelReason': reason,
      'cancelledAt': FieldValue.serverTimestamp(),
    });

    final refundTotal = returnItems.fold<double>(0, (acc, item) {
      return acc + ((item as Map<String, dynamic>)['subtotal'] as num? ?? 0).toDouble();
    });

    txn.set(refundRef, {
      'businessId': businessId,
      'storeId': storeId,
      'employeeId': refundEmployeeId ?? saleData['employeeId'] ?? '',
      'shiftId': refundShiftId ?? saleData['shiftId'] ?? '',
      'folio': refundFolio,
      'originalSaleId': saleId,
      'originalFolio': saleData['folio'] ?? '',
      'type': 'refund',
      'items': returnItems,
      'subtotal': refundTotal,
      'total': refundTotal,
      'paymentMethod': saleData['paymentMethod'] ?? 'cash',
      'status': 'refund',
      'reason': reason,
      'createdAt': FieldValue.serverTimestamp(),
      'clientCreatedAt': clientCreatedAt,
    });

    txn.set(counterRef, {
      'nextRefundNumber': currentRefundNumber + 1,
    }, SetOptions(merge: true));

    if (returnInventory) {
      for (final raw in returnItems) {
        final item = raw as Map<String, dynamic>;
        final productId = item['productId'] as String?;
        final quantity = (item['quantity'] as num? ?? 0).toDouble();
        final chickenCount = item['chickenCount'] as int?;
        if (productId == null || productId.isEmpty || quantity <= 0) continue;

        final previousStock = stockSnapshots[productId]!;
        final newStock = previousStock + quantity;
        final stockUpdate = <String, dynamic>{
          'stockQuantity': newStock,
          'updatedAt': FieldValue.serverTimestamp(),
        };
        if (chickenCount != null) {
          stockUpdate['chickenCount'] = chickenSnapshots[productId]!;
        }
        txn.set(stockRef(productId), stockUpdate, SetOptions(merge: true));
        txn.set(movementsRef.doc(), {
          'businessId': businessId,
          'storeId': storeId,
          'productId': productId,
          'productName': item['name'] ?? '',
          'type': 'refund',
          'previousQuantity': previousStock,
          'newQuantity': newStock,
          'difference': quantity,
          'reason': 'Devolución $refundId',
          'employeeId': refundEmployeeId ?? '',
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      for (final MapEntry(key: swapProductId, value: entry) in swapDeltas.entries) {
        final swapPrevious = swapStockSnapshots[swapProductId]!;
        final swapNew = swapPrevious + entry.delta;
        txn.set(stockRef(swapProductId), {
          'stockQuantity': swapNew,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        txn.set(movementsRef.doc(), {
          'businessId': businessId,
          'storeId': storeId,
          'productId': swapProductId,
          'productName': entry.name,
          'type': 'swap',
          'previousQuantity': swapPrevious,
          'newQuantity': swapNew,
          'difference': entry.delta,
          'reason': entry.delta > 0
              ? 'Devolución $refundId (${entry.name}: regresa pieza entregada)'
              : 'Devolución $refundId (${entry.name}: se retira pieza devuelta)',
          'employeeId': refundEmployeeId ?? '',
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
    }
  });
}

Future<void> _handleOpenShift(Map<String, dynamic> data) async {
  final businessId = _str(data, 'businessId');
  final storeId = _str(data, 'storeId');
  await _firestore.collection('businesses').doc(businessId).collection('shifts').add({
    'businessId': businessId,
    'storeId': storeId,
    'employeeId': _str(data, 'employeeId'),
    'openingCash': _dbl(data, 'openingCash'),
    'totalSales': 0,
    'cashSales': 0,
    'cardSales': 0,
    'cashRefunds': 0,
    'expectedCash': _dbl(data, 'openingCash'),
    'openedAt': FieldValue.serverTimestamp(),
    'status': 'open',
  });
}

Future<void> _handleAddCashMovement(Map<String, dynamic> data) async {
  final businessId = _str(data, 'businessId');
  final shiftId = _str(data, 'shiftId');
  final type = _str(data, 'type');
  final amount = _dbl(data, 'amount');
  final movement = {
    'type': type,
    'amount': amount,
    'comment': _optString(data, 'comment')?.trim() ?? '',
    'createdAt': Timestamp.now(),
  };
  // Mismo formato que el flujo en línea: array en el doc del shift + totales.
  await _firestore.collection('businesses').doc(businessId).collection('shifts').doc(shiftId).update({
    'cashMovements': FieldValue.arrayUnion([movement]),
    if (type == 'deposit') 'depositsTotal': FieldValue.increment(amount),
    if (type == 'payout') 'payoutsTotal': FieldValue.increment(amount),
    'updatedAt': FieldValue.serverTimestamp(),
  });
}

Future<void> _handleCloseShift(Map<String, dynamic> data) async {
  final businessId = _str(data, 'businessId');
  final shiftId = _str(data, 'shiftId');
  final closingCash = _dbl(data, 'closingCash');

  final salesSnap = await _firestore.collection('businesses').doc(businessId).collection('sales')
      .where('shiftId', isEqualTo: shiftId).get();
  double totalSales = 0, cashSales = 0, cardSales = 0, cashRefunds = 0;
  for (final doc in salesSnap.docs) {
    final saleData = doc.data();
    final isRefund = saleData['type'] == 'refund' ||
        saleData['status'] == 'refund' ||
        saleData['isRefund'] == true ||
        saleData['refund'] == true;
    if (isRefund) {
      if (saleData['paymentMethod'] == 'cash') {
        cashRefunds += (saleData['total'] as num?)?.toDouble() ?? 0;
      }
    } else {
      totalSales += (saleData['total'] as num?)?.toDouble() ?? 0;
      if (saleData['paymentMethod'] == 'cash') cashSales += (saleData['total'] as num?)?.toDouble() ?? 0;
      if (saleData['paymentMethod'] == 'card') cardSales += (saleData['total'] as num?)?.toDouble() ?? 0;
    }
  }

  final shiftDoc = await _firestore.collection('businesses').doc(businessId).collection('shifts').doc(shiftId).get();
  final shiftData = shiftDoc.data() ?? {};
  final openingCash = (shiftData['openingCash'] as num?)?.toDouble() ?? 0;
  double deposits = (shiftData['depositsTotal'] as num?)?.toDouble() ?? 0;
  double withdrawals = (shiftData['payoutsTotal'] as num?)?.toDouble() ?? 0;
  if (deposits == 0 && withdrawals == 0) {
    final movements = (shiftData['cashMovements'] as List<dynamic>?) ?? const [];
    for (final raw in movements) {
      final m = raw as Map<String, dynamic>;
      if (m['type'] == 'deposit') deposits += (m['amount'] as num?)?.toDouble() ?? 0;
      if (m['type'] == 'payout') withdrawals += (m['amount'] as num?)?.toDouble() ?? 0;
    }
  }
  if (deposits == 0 && withdrawals == 0) {
    final movementsSnap = await _firestore.collection('businesses').doc(businessId).collection('shifts').doc(shiftId)
        .collection('cashMovements').get();
    for (final doc in movementsSnap.docs) {
      final m = doc.data();
      if (m['type'] == 'deposit') deposits += (m['amount'] as num?)?.toDouble() ?? 0;
      if (m['type'] == 'withdrawal') withdrawals += (m['amount'] as num?)?.toDouble() ?? 0;
    }
  }

  final expectedCash = openingCash + cashSales - cashRefunds + deposits - withdrawals;
  final cashDifference = closingCash - expectedCash;

  await _firestore.collection('businesses').doc(businessId).collection('shifts').doc(shiftId).update({
    'totalSales': totalSales,
    'cashSales': cashSales,
    'cardSales': cardSales,
    'cashRefunds': cashRefunds,
    'expectedCash': expectedCash,
    'closingCash': closingCash,
    'cashDifference': cashDifference,
    'closedAt': FieldValue.serverTimestamp(),
    'status': 'closed',
  });
}

Future<void> _handleAddCategory(Map<String, dynamic> data) async {
  final businessId = _str(data, 'businessId');
  final tempId = _str(data, 'tempId');
  final docRef = _firestore.collection('businesses').doc(businessId).collection('categories').doc(tempId);
  final existing = await docRef.get();
  if (existing.exists) return;
  await docRef.set({
    'name': _str(data, 'name'),
    'color': _int(data, 'color'),
    'active': true,
    'createdAt': FieldValue.serverTimestamp(),
  });
}

Future<void> _handleUpdateCategory(Map<String, dynamic> data) async {
  final businessId = _str(data, 'businessId');
  await _firestore.collection('businesses').doc(businessId).collection('categories').doc(_str(data, 'categoryId')).update({
    'name': _str(data, 'name'),
    'color': _int(data, 'color'),
  });
}

Future<void> _handleDeactivateCategory(Map<String, dynamic> data) async {
  final businessId = _str(data, 'businessId');
  await _firestore.collection('businesses').doc(businessId).collection('categories').doc(_str(data, 'categoryId')).update({'active': false});
}

Future<void> _handleAddDiscount(Map<String, dynamic> data) async {
  final businessId = _str(data, 'businessId');
  final tempId = _str(data, 'tempId');
  final docRef = _firestore.collection('businesses').doc(businessId).collection('discounts').doc(tempId);
  final existing = await docRef.get();
  if (existing.exists) return;
  await docRef.set({
    'name': _str(data, 'name'),
    'type': _str(data, 'type'),
    'value': _dbl(data, 'value'),
    'active': true,
    'createdAt': FieldValue.serverTimestamp(),
  });
}

Future<void> _handleUpdateDiscount(Map<String, dynamic> data) async {
  final businessId = _str(data, 'businessId');
  await _firestore.collection('businesses').doc(businessId).collection('discounts').doc(_str(data, 'discountId')).update({
    'name': _str(data, 'name'),
    'type': _str(data, 'type'),
    'value': _dbl(data, 'value'),
  });
}

Future<void> _handleDeactivateDiscount(Map<String, dynamic> data) async {
  final businessId = _str(data, 'businessId');
  await _firestore.collection('businesses').doc(businessId).collection('discounts').doc(_str(data, 'discountId')).update({'active': false});
}

Future<void> _handleAddEmployee(Map<String, dynamic> data) async {
  final businessId = _str(data, 'businessId');
  await _firestore.collection('businesses').doc(businessId).collection('employees').add({
    'name': _str(data, 'name'),
    'email': _str(data, 'email'),
    'role': _str(data, 'role'),
    'pin': _str(data, 'pin'),
    'storeIds': data['storeIds'],
    'permissions': data['permissions'],
    'active': true,
    'createdAt': FieldValue.serverTimestamp(),
  });
}

Future<void> _handleUpdateEmployee(Map<String, dynamic> data) async {
  final businessId = _str(data, 'businessId');
  final updates = <String, dynamic>{
    'role': _str(data, 'role'),
    'storeIds': data['storeIds'],
    'permissions': data['permissions'],
    'active': _bool(data, 'active'),
  };
  if (data.containsKey('pin')) updates['pin'] = _str(data, 'pin');
  await _firestore.collection('businesses').doc(businessId).collection('employees').doc(_str(data, 'employeeId')).update(updates);
}

Future<void> _handleDeactivateEmployee(Map<String, dynamic> data) async {
  final businessId = _str(data, 'businessId');
  await _firestore.collection('businesses').doc(businessId).collection('employees').doc(_str(data, 'employeeId')).update({
    'active': false,
  });
}

Future<void> _handleAddModifier(Map<String, dynamic> data) async {
  final businessId = _str(data, 'businessId');
  final tempId = _str(data, 'tempId');
  final docRef = _firestore.collection('businesses').doc(businessId).collection('modifiers').doc(tempId);
  final existing = await docRef.get();
  if (existing.exists) return;
  await docRef.set({
    'name': _str(data, 'name'),
    'price': _dbl(data, 'price'),
    'active': true,
    'createdAt': FieldValue.serverTimestamp(),
  });
}

Future<void> _handleUpdateModifier(Map<String, dynamic> data) async {
  final businessId = _str(data, 'businessId');
  await _firestore.collection('businesses').doc(businessId).collection('modifiers').doc(_str(data, 'modifierId')).update({
    'name': _str(data, 'name'),
    'price': _dbl(data, 'price'),
  });
}

Future<void> _handleDeactivateModifier(Map<String, dynamic> data) async {
  final businessId = _str(data, 'businessId');
  await _firestore.collection('businesses').doc(businessId).collection('modifiers').doc(_str(data, 'modifierId')).update({'active': false});
}

Future<void> _handleAdjustStock(Map<String, dynamic> data) async {
  final businessId = _str(data, 'businessId');
  final storeId = _str(data, 'storeId');
  final productId = _str(data, 'productId');
  final stockRef = _firestore
      .collection('businesses').doc(businessId)
      .collection('products').doc(productId)
      .collection('stockByStore').doc(storeId);
  final stockDoc = await stockRef.get();
  final previousStock = (stockDoc.data()?['stockQuantity'] as num? ?? 0).toDouble();
  final newQuantity = _dbl(data, 'newQuantity');
  await stockRef.set({'stockQuantity': newQuantity, 'updatedAt': FieldValue.serverTimestamp()}, SetOptions(merge: true));
  await _firestore.collection('businesses').doc(businessId).collection('inventoryMovements').add({
    'businessId': businessId,
    'storeId': storeId,
    'productId': productId,
    'type': 'adjustment',
    'previousQuantity': previousStock,
    'newQuantity': newQuantity,
    'difference': newQuantity - previousStock,
    'reason': _str(data, 'reason'),
    'employeeId': data['employeeId'],
    'createdAt': FieldValue.serverTimestamp(),
  });
}

Future<void> _handleSaveOpenTicket(Map<String, dynamic> data) async {
  final businessId = _str(data, 'businessId');
  final tempId = _optString(data, 'tempId');
  final ticketId = _optString(data, 'ticketId') ?? tempId;
  if (ticketId == null) return;
  final docRef = _firestore.collection('businesses').doc(businessId).collection('openTickets').doc(ticketId);
  final existing = await docRef.get();
  if (existing.exists) return;
  await docRef.set({
    'businessId': businessId,
    'storeId': _str(data, 'storeId'),
    'employeeId': _str(data, 'employeeId'),
    'name': _str(data, 'name'),
    'items': data['items'],
    'total': _dbl(data, 'total'),
    'status': 'open',
    'createdAt': FieldValue.serverTimestamp(),
  });
}

Future<void> _handleCloseOpenTicket(Map<String, dynamic> data) async {
  final businessId = _str(data, 'businessId');
  await _firestore.collection('businesses').doc(businessId).collection('openTickets').doc(_str(data, 'ticketId')).update({'status': 'closed'});
}

Future<void> _handleCancelOpenTicket(Map<String, dynamic> data) async {
  final businessId = _str(data, 'businessId');
  await _firestore.collection('businesses').doc(businessId).collection('openTickets').doc(_str(data, 'ticketId')).update({'status': 'cancelled'});
}

Future<void> _handleUpdateBusiness(Map<String, dynamic> data) async {
  final businessId = _str(data, 'businessId');
  await _firestore.collection('businesses').doc(businessId).update({
    'name': _str(data, 'name'),
    'currency': _str(data, 'currency'),
    'timezone': _str(data, 'timezone'),
  });
}

Future<void> _handleAddStore(Map<String, dynamic> data) async {
  final businessId = _str(data, 'businessId');
  await _firestore.collection('businesses').doc(businessId).collection('stores').add({
    'businessId': businessId,
    'name': _str(data, 'name'),
    'address': _str(data, 'address'),
    'phone': _str(data, 'phone'),
    'active': true,
    'createdAt': FieldValue.serverTimestamp(),
  });
}

Future<void> _handleUpdateStore(Map<String, dynamic> data) async {
  final businessId = _str(data, 'businessId');
  await _firestore.collection('businesses').doc(businessId).collection('stores').doc(_str(data, 'storeId')).update({
    'name': _str(data, 'name'),
    'address': _str(data, 'address'),
    'phone': _str(data, 'phone'),
    'active': _bool(data, 'active'),
  });
}
