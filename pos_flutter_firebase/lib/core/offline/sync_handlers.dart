import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:meta/meta.dart';

import 'package:pos_flutter_firebase/features/butcher/data/butcher_stock_service.dart';

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
    'setStorePrice': _handleSetStorePrice,
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
    'poultryReceiving': _handlePoultryReceiving,
    'sendTransfer': _handleSendTransfer,
    'confirmTransfer': _handleConfirmTransfer,
    'cancelTransfer': _handleCancelTransfer,
    'butcherEntry': _handleButcherEntry,
    'butcherCancelEntry': _handleButcherCancelEntry,
    'butchering': _handleButchering,
    'butcherCancelButchering': _handleButcherCancelButchering,
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
      if (data['storePrice'] != null) 'price': data['storePrice'],
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
      if (data['storePrice'] != null) 'price': data['storePrice'],
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
  final newQuantity = _dbl(data, 'newQuantity');
  final reason = _optString(data, 'reason');
  final trimmedReason = (reason == null || reason.trim().isEmpty) ? 'Ajuste manual' : reason.trim();

  final productRef = _firestore
      .collection('businesses').doc(businessId)
      .collection('products').doc(productId);
  final stockRef = productRef.collection('stockByStore').doc(storeId);
  final movementRef = _firestore
      .collection('businesses').doc(businessId)
      .collection('inventoryMovements').doc();

  await _firestore.runTransaction((txn) async {
    final productDoc = await txn.get(productRef);
    if (!productDoc.exists) {
      throw StateError('El producto ya no existe');
    }
    final stockDoc = await txn.get(stockRef);
    final stockData = stockDoc.data() as Map<String, dynamic>?;
    final previousStock = ((stockData?['stockQuantity'] ?? 0.0) as num).toDouble();
    final difference = newQuantity - previousStock;

    txn.set(stockRef, {
      'businessId': businessId,
      'storeId': storeId,
      'productId': productId,
      'stock': newQuantity.round(),
      'stockQuantity': newQuantity,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    txn.set(movementRef, {
      'businessId': businessId,
      'storeId': storeId,
      'productId': productId,
      'productName': productDoc.data()?['name'] ?? '',
      'type': 'adjustment',
      'previousQuantity': previousStock,
      'newQuantity': newQuantity,
      'difference': difference,
      'reason': trimmedReason,
      'employeeId': data['employeeId'],
      'createdAt': FieldValue.serverTimestamp(),
    });
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

Future<void> _handleSetStorePrice(Map<String, dynamic> data) async {
  final businessId = _str(data, 'businessId');
  final storeId = _str(data, 'storeId');
  final productId = _str(data, 'productId');
  final price = data['price'];
  await _firestore
      .collection('businesses').doc(businessId)
      .collection('products').doc(productId)
      .collection('stockByStore').doc(storeId)
      .set({'price': price}, SetOptions(merge: true));
}

/// Resuelve o crea el producto "Pollo Entero" (misma lógica que
/// PoultryService). Solo corre en contexto en línea (durante el sync).
Future<String> _ensureWholeProduct(String businessId, String storeId) async {
  final productsRef = _firestore.collection('businesses').doc(businessId).collection('products');
  final configRef = _firestore.collection('businesses').doc(businessId).collection('config').doc('poultry');

  final configDoc = await configRef.get();
  final existingId = configDoc.data()?['wholeProductId'] as String?;
  if (existingId != null) {
    final productDoc = await productsRef.doc(existingId).get();
    if (productDoc.exists) return existingId;
  }

  final query = await productsRef
      .where('name', isEqualTo: 'Pollo Entero')
      .where('active', isEqualTo: true)
      .limit(1)
      .get();
  if (query.docs.isNotEmpty) {
    final id = query.docs.first.id;
    await configRef.set({'wholeProductId': id}, SetOptions(merge: true));
    return id;
  }

  final ref = 'PO${DateTime.now().millisecondsSinceEpoch.toString().substring(0, 8)}';
  final productRef = productsRef.doc();
  await productRef.set({
    'businessId': businessId,
    'name': 'Pollo Entero',
    'description': 'Pollos enteros recibidos por destazar',
    'sku': ref,
    'barcode': '',
    'categoryId': null,
    'categoryName': null,
    'sellBy': 'weight',
    'imageUrl': null,
    'localImagePath': null,
    'price': 0.0,
    'cost': 0.0,
    'ref': ref,
    'trackStock': true,
    'stock': 0,
    'stockQuantity': 0.0,
    'lowStockAlert': 0,
    'lowStockAlertQuantity': 0.0,
    'presentationType': 'shape',
    'presentationShape': 'square',
    'presentationColor': 0xFF868E96,
    'active': true,
    'createdAt': FieldValue.serverTimestamp(),
    'updatedAt': FieldValue.serverTimestamp(),
  });
  await productRef.collection('stockByStore').doc(storeId).set({
    'businessId': businessId,
    'storeId': storeId,
    'productId': productRef.id,
    'stock': 0,
    'stockQuantity': 0.0,
    'chickenCount': 0,
    'lowStockAlert': 0,
    'lowStockAlertQuantity': 0.0,
    'createdAt': FieldValue.serverTimestamp(),
    'updatedAt': FieldValue.serverTimestamp(),
  });
  await configRef.set({'wholeProductId': productRef.id}, SetOptions(merge: true));
  return productRef.id;
}

Future<void> _handlePoultryReceiving(Map<String, dynamic> data) async {
  final businessId = _str(data, 'businessId');
  final storeId = _str(data, 'storeId');
  final clientOpId = data['clientOpId'] as String?;
  final totalChickens = _int(data, 'totalChickens');
  final totalWeightKg = _dbl(data, 'totalWeightKg');
  final createdAt = _clientTimestamp(data['createdAt']);

  final wholeProductId = await _ensureWholeProduct(businessId, storeId);
  final receivingRef = _firestore.collection('businesses').doc(businessId)
      .collection('poultryReceivings')
      .doc((clientOpId != null && clientOpId.isNotEmpty) ? clientOpId : '');
  final stockRef = _firestore.collection('businesses').doc(businessId)
      .collection('products').doc(wholeProductId)
      .collection('stockByStore').doc(storeId);
  final movementsRef = _firestore.collection('businesses').doc(businessId)
      .collection('inventoryMovements');

  final existingStockDoc = await stockRef.get();
  if (!existingStockDoc.exists) {
    await stockRef.set({
      'businessId': businessId,
      'storeId': storeId,
      'productId': wholeProductId,
      'stockQuantity': 0,
      'chickenCount': 0,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  await _firestore.runTransaction((txn) async {
    final existingReceipt = (clientOpId != null && clientOpId.isNotEmpty)
        ? await txn.get(receivingRef)
        : null;
    // Idempotencia: si la recepción ya se sincronizó, no se vuelve a aplicar.
    if (existingReceipt != null && existingReceipt.exists) return;

    final stockDoc = await txn.get(stockRef);
    final stockData = stockDoc.data() as Map<String, dynamic>?;
    final previousStock = (stockData?['stockQuantity'] as num? ?? 0).toDouble();
    final previousCount = stockData?['chickenCount'] as int? ?? 0;
    final newStock = previousStock + totalWeightKg;
    final newCount = previousCount + totalChickens;

    txn.set(stockRef, {
      'businessId': businessId,
      'storeId': storeId,
      'productId': wholeProductId,
      'stockQuantity': newStock,
      'chickenCount': newCount,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    txn.set(receivingRef, {
      'businessId': businessId,
      'storeId': storeId,
      'employeeId': _optString(data, 'employeeId') ?? '',
      'employeeName': _optString(data, 'employeeName') ?? '',
      'createdAt': createdAt,
      'totalChickens': totalChickens,
      'totalWeightKg': totalWeightKg,
      'avgWeightKg': _dbl(data, 'avgWeightKg'),
      'status': 'completed',
    });

    txn.set(movementsRef.doc(), {
      'businessId': businessId,
      'storeId': storeId,
      'productId': wholeProductId,
      'productName': 'Pollo Entero',
      'type': 'receiving',
      'previousQuantity': previousStock,
      'newQuantity': newStock,
      'difference': totalWeightKg,
      'reason': 'Recepción de $totalChickens pollos',
      'employeeId': _optString(data, 'employeeId') ?? '',
      'createdAt': createdAt,
    });
  });
}

Future<void> _handleSendTransfer(Map<String, dynamic> data) async {
  final businessId = _str(data, 'businessId');
  final clientOpId = data['clientOpId'] as String?;
  final transferMap = Map<String, dynamic>.from(data)
    ..remove('clientOpId')
    ..remove('createdAt')
    ..['createdAt'] = FieldValue.serverTimestamp();

  final transfersRef = _firestore.collection('businesses').doc(businessId).collection('transfers');
  final ref = (clientOpId != null && clientOpId.isNotEmpty)
      ? transfersRef.doc(clientOpId)
      : transfersRef.doc();
  if (clientOpId != null && clientOpId.isNotEmpty) {
    final existing = await ref.get();
    if (existing.exists) return;
  }
  await ref.set(transferMap);
}

Future<void> _handleCancelTransfer(Map<String, dynamic> data) async {
  final businessId = _str(data, 'businessId');
  final transferId = _str(data, 'transferId');
  final ref = _firestore.collection('businesses').doc(businessId).collection('transfers').doc(transferId);
  final snapshot = await ref.get();
  if (!snapshot.exists) return;
  if ((snapshot.data()?['status'] as String?) == 'cancelled') return;
  await ref.update({'status': 'cancelled'});
}

Future<void> _handleConfirmTransfer(Map<String, dynamic> data) async {
  final businessId = _str(data, 'businessId');
  final transferId = _str(data, 'transferId');
  final toEmployeeId = _optString(data, 'toEmployeeId') ?? '';
  final listRaw = data['updatedItems'] as List<dynamic>;
  final updatedItems = listRaw.map((e) {
    final m = Map<String, dynamic>.from(e as Map);
    final confirmed = m['confirmedQuantity'];
    return (
      productId: m['productId'] as String,
      productName: (m['productName'] as String?) ?? '',
      sentQuantity: ((m['sentQuantity'] as num?) ?? 0).toDouble(),
      confirmedQuantity: confirmed is num ? confirmed.toDouble() : null,
    );
  }).toList();
  final filteredItems =
      updatedItems.where((i) => i.confirmedQuantity != null && i.confirmedQuantity! > 0).toList();

  final transferRef = _firestore.collection('businesses').doc(businessId).collection('transfers').doc(transferId);
  if (filteredItems.isEmpty) {
    final snapshot = await transferRef.get();
    if (snapshot.exists && (snapshot.data()?['status'] as String?) != 'cancelled') {
      await transferRef.update({'status': 'cancelled'});
    }
    return;
  }

  final movementsRef = _firestore.collection('businesses').doc(businessId).collection('inventoryMovements');
  await _firestore.runTransaction((txn) async {
    final transferSnap = await txn.get(transferRef);
    if (!transferSnap.exists) return;
    final transferData = transferSnap.data() as Map<String, dynamic>;
    // Idempotencia: solo se confirma un traspaso que siga en 'sent'.
    if (transferData['status'] != 'sent') return;

    final fromStoreId = (transferData['fromStoreId'] as String?) ?? '';
    final toStoreId = (transferData['toStoreId'] as String?) ?? '';
    final fromStoreName = (transferData['fromStoreName'] as String?) ?? '';
    final toStoreName = (transferData['toStoreName'] as String?) ?? '';
    final fromEmployeeId = (transferData['fromEmployeeId'] as String?) ?? '';

    DocumentReference itemStockRef(String productId, String storeId) => _firestore
        .collection('businesses').doc(businessId)
        .collection('products').doc(productId)
        .collection('stockByStore').doc(storeId);

    final stockSnapshots = <String, double>{};
    for (final item in filteredItems) {
      final fromDoc = await txn.get(itemStockRef(item.productId, fromStoreId));
      stockSnapshots['from_${item.productId}'] =
          (((fromDoc.data() as Map<String, dynamic>?)?['stockQuantity'] ?? 0.0) as num).toDouble();
      final toDoc = await txn.get(itemStockRef(item.productId, toStoreId));
      stockSnapshots['to_${item.productId}'] =
          (((toDoc.data() as Map<String, dynamic>?)?['stockQuantity'] ?? 0.0) as num).toDouble();
    }

    for (final item in filteredItems) {
      final qty = item.confirmedQuantity!;
      final fromQty = stockSnapshots['from_${item.productId}'] ?? 0;
      final newFromQty = (fromQty - qty).clamp(0.0, double.infinity);
      txn.set(itemStockRef(item.productId, fromStoreId), {
        'stockQuantity': newFromQty,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      final toQty = stockSnapshots['to_${item.productId}'] ?? 0;
      final newToQty = toQty + qty;
      txn.set(itemStockRef(item.productId, toStoreId), {
        'businessId': businessId,
        'storeId': toStoreId,
        'productId': item.productId,
        'stockQuantity': newToQty,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      txn.set(movementsRef.doc(), {
        'businessId': businessId,
        'storeId': fromStoreId,
        'fromStoreId': fromStoreId,
        'toStoreId': toStoreId,
        'fromStoreName': fromStoreName,
        'toStoreName': toStoreName,
        'productId': item.productId,
        'productName': item.productName,
        'type': 'transfer',
        'previousQuantity': fromQty,
        'newQuantity': newFromQty,
        'difference': newFromQty - fromQty,
        'reason': 'Traspaso enviado',
        'employeeId': fromEmployeeId,
        'createdAt': FieldValue.serverTimestamp(),
      });

      txn.set(movementsRef.doc(), {
        'businessId': businessId,
        'storeId': toStoreId,
        'fromStoreId': fromStoreId,
        'toStoreId': toStoreId,
        'fromStoreName': fromStoreName,
        'toStoreName': toStoreName,
        'productId': item.productId,
        'productName': item.productName,
        'type': 'transfer',
        'previousQuantity': toQty,
        'newQuantity': newToQty,
        'difference': qty,
        'reason': 'Traspaso recibido',
        'employeeId': toEmployeeId,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }

    txn.update(transferRef, {
      'status': 'confirmed',
      'toEmployeeId': toEmployeeId,
      'confirmedAt': FieldValue.serverTimestamp(),
      'items': listRaw,
    });
  });
}

Future<void> _handleButcherEntry(Map<String, dynamic> data) async {
  final businessId = _str(data, 'businessId');
  final storeId = _str(data, 'storeId');
  final employeeId = _optString(data, 'employeeId') ?? '';
  final type = _optString(data, 'type') ?? 'chicken';
  final sourceStoreId = _optString(data, 'sourceStoreId');
  final clientOpId = data['clientOpId'] as String?;
  final createdAt = _clientTimestamp(data['createdAt']);

  final receiptsRef = _firestore.collection('businesses').doc(businessId).collection('butcherReceipts');
  final receiptRef = (clientOpId != null && clientOpId.isNotEmpty)
      ? receiptsRef.doc(clientOpId)
      : receiptsRef.doc();
  if (clientOpId != null && clientOpId.isNotEmpty) {
    final existing = await receiptRef.get();
    if (existing.exists) return;
  }

  await receiptRef.set({
    'type': type,
    'storeId': storeId,
    'employeeId': employeeId,
    if (type == 'chicken') 'chickenCount': _int(data, 'chickenCount'),
    if (type == 'chicken') 'avgWeight': _dbl(data, 'avgWeight'),
    'totalWeight': _dbl(data, 'totalWeight'),
    'yields': data['yields'],
    'sourceStoreId': sourceStoreId,
    'status': 'active',
    'consumedSections': [],
    'createdAt': createdAt,
  });

  final stockSvc = ButcherStockService(firestore: _firestore);
  final yieldRecords = (data['yields'] as List<dynamic>)
      .map((raw) {
        final m = Map<String, dynamic>.from(raw as Map);
        return (
          name: m['name'] as String,
          weight: ((m['weight'] as num?) ?? 0).toDouble(),
          percentage: ((m['percentage'] as num?) ?? 0).toDouble(),
        );
      })
      .toList();

  await stockSvc.addStockFromYields(businessId: businessId, storeId: storeId, yields: yieldRecords);
  if (sourceStoreId != null) {
    await stockSvc.subtractStockFromYields(businessId: businessId, storeId: sourceStoreId, yields: yieldRecords);
  }
}

Future<void> _handleButcherCancelEntry(Map<String, dynamic> data) async {
  final businessId = _str(data, 'businessId');
  final receiptId = _str(data, 'receiptId');
  final reason = _optString(data, 'reason') ?? '';
  final cancelledBy = _optString(data, 'cancelledBy') ?? '';

  final receiptsRef = _firestore.collection('businesses').doc(businessId).collection('butcherReceipts');
  final doc = await receiptsRef.doc(receiptId).get();
  if (!doc.exists) return;
  final detail = doc.data() as Map<String, dynamic>;
  if (detail['status'] == 'cancelled') return;

  final storeId = detail['storeId'] as String;
  final sourceStoreId = detail['sourceStoreId'] as String?;
  final yields = ((detail['yields'] as List<dynamic>?) ?? []).map((raw) {
    final m = Map<String, dynamic>.from(raw as Map);
    return (
      name: m['name'] as String,
      weight: ((m['weight'] as num?) ?? 0).toDouble(),
      percentage: ((m['percentage'] as num?) ?? 0).toDouble(),
    );
  }).toList();

  final stockSvc = ButcherStockService(firestore: _firestore);
  await stockSvc.subtractStockFromYields(businessId: businessId, storeId: storeId, yields: yields);
  if (sourceStoreId != null) {
    await stockSvc.addStockFromYields(businessId: businessId, storeId: sourceStoreId, yields: yields);
  }

  await receiptsRef.doc(receiptId).update({
    'status': 'cancelled',
    'cancelReason': reason,
    'cancelledBy': cancelledBy,
    'cancelledAt': FieldValue.serverTimestamp(),
  });
}

Future<void> _handleButchering(Map<String, dynamic> data) async {
  final businessId = _str(data, 'businessId');
  final storeId = _str(data, 'storeId');
  final employeeId = _optString(data, 'employeeId') ?? '';
  final employeeName = _optString(data, 'employeeName') ?? '';
  final chickenCount = _int(data, 'chickenCount');
  final exactWeightKg = _dbl(data, 'exactWeightKg');
  final wholeProductId = _str(data, 'wholeProductId');
  final clientOpId = data['clientOpId'] as String?;
  final createdAt = _clientTimestamp(data['createdAt']);

  final sections = (data['sections'] as List<dynamic>)
      .map((e) => Map<String, dynamic>.from(e as Map))
      .toList();
  final totalActualKg = sections.fold<double>(0, (acc, s) => acc + ((s['actualKg'] as num? ?? 0).toDouble()));
  final totalExpectedKg = sections.fold<double>(0, (acc, s) => acc + ((s['expectedKg'] as num? ?? 0).toDouble()));
  final mermaKg = (totalExpectedKg - totalActualKg).clamp(0.0, double.infinity);
  final mermaPercent = totalExpectedKg > 0 ? (mermaKg / totalExpectedKg) * 100 : 0.0;

  final productsRef = _firestore.collection('businesses').doc(businessId).collection('products');
  final sectionProductIds = <String, String>{};
  final sectionNames = <String, String>{};
  for (final section in sections) {
    final name = section['sectionName'] as String;
    if (((section['actualKg'] as num?) ?? 0).toDouble() <= 0) continue;
    final products = await productsRef
        .where('name', isEqualTo: name)
        .where('active', isEqualTo: true)
        .limit(1)
        .get();
    if (products.docs.isNotEmpty) {
      sectionProductIds[name] = products.docs.first.id;
      sectionNames[name] = products.docs.first.get('name') as String? ?? name;
    } else {
      throw StateError('Producto para sección "$name" no encontrado.');
    }
  }

  final butcheringRef = _firestore.collection('businesses').doc(businessId).collection('butchering');
  final recordRef = (clientOpId != null && clientOpId.isNotEmpty)
      ? butcheringRef.doc(clientOpId)
      : butcheringRef.doc();
  final movementsRef = _firestore.collection('businesses').doc(businessId).collection('inventoryMovements');
  final wholeStockRef = productsRef.doc(wholeProductId).collection('stockByStore').doc(storeId);

  final existingStockDoc = await wholeStockRef.get();
  if (!existingStockDoc.exists) {
    await wholeStockRef.set({
      'businessId': businessId,
      'storeId': storeId,
      'productId': wholeProductId,
      'stockQuantity': 0,
      'chickenCount': 0,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  double? finalWholeStock;
  int? finalChickenCount;

  await _firestore.runTransaction((txn) async {
    final existingRec = (clientOpId != null && clientOpId.isNotEmpty)
        ? await txn.get(recordRef)
        : null;
    // Idempotencia: si el destazado ya se sincronizó, no se vuelve a aplicar.
    if (existingRec != null && existingRec.exists) return;

    final wholeStockDoc = await txn.get(wholeStockRef);
    final wholeData = wholeStockDoc.data() as Map<String, dynamic>?;
    final currentWholeStock = (wholeData?['stockQuantity'] as num? ?? 0).toDouble();
    final currentChickenCount = wholeData?['chickenCount'] as int? ?? 0;

    final sectionStocks = <String, ({String productId, String productName, double currentStock, double actualKg})>{};
    for (final section in sections) {
      final name = section['sectionName'] as String;
      final actualKg = ((section['actualKg'] as num?) ?? 0).toDouble();
      if (actualKg <= 0) continue;
      final productId = sectionProductIds[name];
      if (productId == null) continue;
      final sectionRef = productsRef.doc(productId).collection('stockByStore').doc(storeId);
      final sectionDoc = await txn.get(sectionRef);
      final sectionData = sectionDoc.data() as Map<String, dynamic>?;
      sectionStocks[name] = (
        productId: productId,
        productName: sectionNames[name] ?? name,
        currentStock: ((sectionData?['stockQuantity'] as num?) ?? 0).toDouble(),
        actualKg: actualKg,
      );
    }

    if (currentWholeStock < exactWeightKg) {
      throw StateError(
        'Stock insuficiente de pollo entero: disponible ${currentWholeStock.toStringAsFixed(2)} kg, '
        'requerido ${exactWeightKg.toStringAsFixed(2)} kg',
      );
    }
    if (currentChickenCount < chickenCount) {
      throw StateError(
        'No hay suficientes pollos enteros: disponibles $currentChickenCount, requeridos $chickenCount',
      );
    }

    final newWholeStock = currentWholeStock - exactWeightKg;
    final newChickenCount = currentChickenCount - chickenCount;
    finalWholeStock = newWholeStock;
    finalChickenCount = newChickenCount;

    txn.set(recordRef, {
      'businessId': businessId,
      'storeId': storeId,
      'employeeId': employeeId,
      'employeeName': employeeName,
      'createdAt': createdAt,
      'chickenCount': chickenCount,
      'exactWeightKg': exactWeightKg,
      'totalExpectedKg': totalExpectedKg,
      'totalActualKg': totalActualKg,
      'sections': sections,
      'mermaKg': mermaKg,
      'mermaPercent': mermaPercent,
      'status': 'active',
    });

    txn.set(wholeStockRef, {
      'businessId': businessId,
      'storeId': storeId,
      'productId': wholeProductId,
      'stockQuantity': newWholeStock,
      'chickenCount': newChickenCount,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    txn.set(movementsRef.doc(), {
      'businessId': businessId,
      'storeId': storeId,
      'productId': wholeProductId,
      'productName': 'Pollo Entero',
      'type': 'butchering',
      'previousQuantity': currentWholeStock,
      'newQuantity': newWholeStock,
      'difference': -exactWeightKg,
      'reason': 'Destazado $chickenCount pollos',
      'employeeId': employeeId,
      'createdAt': createdAt,
    });

    for (final entry in sectionStocks.entries) {
      final section = entry.value;
      final newSectionStock = section.currentStock + section.actualKg;
      txn.set(productsRef.doc(section.productId).collection('stockByStore').doc(storeId), {
        'businessId': businessId,
        'storeId': storeId,
        'productId': section.productId,
        'stockQuantity': newSectionStock,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      txn.set(movementsRef.doc(), {
        'businessId': businessId,
        'storeId': storeId,
        'productId': section.productId,
        'productName': section.productName,
        'type': 'butchering',
        'previousQuantity': section.currentStock,
        'newQuantity': newSectionStock,
        'difference': section.actualKg,
        'reason': 'Destazado - sección ${entry.key}',
        'employeeId': employeeId,
        'createdAt': createdAt,
      });
    }
  });

  if (finalWholeStock != null && finalChickenCount != null) {
    String? type;
    if (finalChickenCount == 0 && finalWholeStock! > 0.5) {
      type = 'excess_kg';
    } else if (finalWholeStock! <= 0.01 && finalChickenCount! > 0) {
      type = 'excess_chickens';
    }
    if (type != null) {
      await _firestore.collection('businesses').doc(businessId).collection('butcherAnomalies').doc().set({
        'businessId': businessId,
        'storeId': storeId,
        'employeeId': employeeId,
        'employeeName': employeeName,
        'createdAt': createdAt,
        'type': type,
        'remainingKg': finalWholeStock,
        'remainingChickens': finalChickenCount,
        'butcheredKg': exactWeightKg,
        'butcheredChickens': chickenCount,
      });
    }
  }
}

Future<void> _handleButcherCancelButchering(Map<String, dynamic> data) async {
  final businessId = _str(data, 'businessId');
  final recordId = _str(data, 'recordId');
  final reason = _optString(data, 'reason') ?? '';
  final cancelledBy = _optString(data, 'cancelledBy') ?? '';

  final butcheringRef = _firestore.collection('businesses').doc(businessId).collection('butchering');
  final doc = await butcheringRef.doc(recordId).get();
  if (!doc.exists) return;
  final record = doc.data() as Map<String, dynamic>;
  if (record['status'] == 'cancelled') return;

  final storeId = record['storeId'] as String;
  final chickenCount = ((record['chickenCount'] as num?) ?? 0).toInt();
  final exactWeightKg = ((record['exactWeightKg'] as num?) ?? 0).toDouble();
  final productsRef = _firestore.collection('businesses').doc(businessId).collection('products');

  final batch = _firestore.batch();
  batch.update(butcheringRef.doc(recordId), {
    'status': 'cancelled',
    'cancelReason': reason,
    'cancelledBy': cancelledBy,
    'cancelledAt': FieldValue.serverTimestamp(),
  });

  final configDoc = await _firestore.collection('businesses').doc(businessId).collection('config').doc('poultry').get();
  final wholeProductId = configDoc.data()?['wholeProductId'] as String?;
  if (wholeProductId != null) {
    batch.set(productsRef.doc(wholeProductId).collection('stockByStore').doc(storeId), {
      'businessId': businessId,
      'storeId': storeId,
      'productId': wholeProductId,
      'stockQuantity': FieldValue.increment(exactWeightKg),
      'chickenCount': FieldValue.increment(chickenCount),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  final sections = (record['sections'] as List<dynamic>?) ?? [];
  for (final raw in sections) {
    final section = Map<String, dynamic>.from(raw as Map);
    final name = section['sectionName'] as String;
    final actualKg = ((section['actualKg'] as num?) ?? 0).toDouble();
    if (actualKg <= 0) continue;
    final products = await productsRef
        .where('name', isEqualTo: name)
        .where('active', isEqualTo: true)
        .limit(1)
        .get();
    if (products.docs.isEmpty) continue;
    batch.set(productsRef.doc(products.docs.first.id).collection('stockByStore').doc(storeId), {
      'businessId': businessId,
      'storeId': storeId,
      'productId': products.docs.first.id,
      'stockQuantity': FieldValue.increment(-actualKg),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  await batch.commit();
}
