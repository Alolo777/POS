import 'package:cloud_firestore/cloud_firestore.dart';

import 'sync_service.dart';

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

final _firestore = FirebaseFirestore.instance;

String? _optString(Map<String, dynamic> data, String key) => data[key] as String?;
String _str(Map<String, dynamic> data, String key) => data[key] as String;
double _dbl(Map<String, dynamic> data, String key) => (data[key] as num).toDouble();
int _int(Map<String, dynamic> data, String key) => (data[key] as num).toInt();
bool _bool(Map<String, dynamic> data, String key) => data[key] as bool;

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
  final shiftId = _str(data, 'shiftId');

  final folioRef = _firestore.collection('businesses').doc(businessId).collection('config').doc('folioCounter');
  final folioResult = await folioRef.get();
  final currentFolio = (folioResult.data()?['current'] as num? ?? 0).toInt() + 1;

  final saleRef = _firestore.collection('businesses').doc(businessId).collection('sales').doc();
  await saleRef.set({
    'businessId': businessId,
    'storeId': storeId,
    'employeeId': _str(data, 'employeeId'),
    'shiftId': shiftId,
    'folio': 'T-$currentFolio',
    'items': data['items'],
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
    'clientCreatedAt': DateTime.now().toIso8601String(),
  });

  await folioRef.set({'current': currentFolio}, SetOptions(merge: true));

  final items = data['items'] as List<dynamic>;
  final movementsRef = _firestore.collection('businesses').doc(businessId).collection('inventoryMovements');
  for (final item in items) {
    final itemMap = item as Map<String, dynamic>;
    final productId = itemMap['productId'] as String?;
    final quantity = (itemMap['quantity'] as num?)?.toDouble() ?? 0;
    if (productId != null && quantity > 0) {
      final stockRef = _firestore
          .collection('businesses').doc(businessId)
          .collection('products').doc(productId)
          .collection('stockByStore').doc(storeId);
      final stockDoc = await stockRef.get();
      final previousStock = (stockDoc.data()?['stockQuantity'] as num? ?? 0).toDouble();
      final newStock = previousStock - quantity;
      await stockRef.set({
        'stockQuantity': newStock,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      await movementsRef.add({
        'businessId': businessId,
        'storeId': storeId,
        'productId': productId,
        'productName': itemMap['name'] ?? '',
        'type': 'sale',
        'quantity': -quantity,
        'previousQuantity': previousStock,
        'newQuantity': newStock,
        'difference': -quantity,
        'reason': 'Venta T-$currentFolio',
        'saleFolio': 'T-$currentFolio',
        'employeeId': _str(data, 'employeeId'),
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
  }
}

Future<void> _handleCancelSale(Map<String, dynamic> data) async {
  final businessId = _str(data, 'businessId');
  final saleId = _str(data, 'saleId');
  final storeId = _str(data, 'storeId');
  final returnItems = data['returnItems'] as List<dynamic>;
  final returnInventory = _bool(data, 'returnInventory');

  final saleDoc = await _firestore.collection('businesses').doc(businessId).collection('sales').doc(saleId).get();
  final originalItems = (saleDoc.data()?['items'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? [];

  final updatedItems = originalItems.map((item) {
    final returnedItem = returnItems.firstWhere(
      (r) => (r as Map<String, dynamic>)['productId'] == item['productId'],
      orElse: () => <String, dynamic>{},
    );
    if (returnedItem is Map<String, dynamic> && returnedItem.isNotEmpty) {
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
        .fold<double>(0, (sum, r) => sum + ((r as Map<String, dynamic>)['quantity'] as num? ?? 0).toDouble());
    if (alreadyReturned + newReturn < originalQty) {
      isFullReturn = false;
      break;
    }
  }

  final newStatus = isFullReturn ? 'cancelled' : 'partially_cancelled';

  await _firestore.collection('businesses').doc(businessId).collection('sales').doc(saleId).update({
    'status': newStatus,
    'items': updatedItems,
    'cancelReason': _str(data, 'reason'),
    'cancelledAt': FieldValue.serverTimestamp(),
  });

  final refundRef = _firestore.collection('businesses').doc(businessId).collection('sales').doc();
  final refundTotal = returnItems.fold<double>(0, (acc, item) {
    final itemMap = item as Map<String, dynamic>;
    return acc + (itemMap['subtotal'] as num? ?? 0).toDouble();
  });
  await refundRef.set({
    'businessId': businessId,
    'storeId': storeId,
    'employeeId': _str(data, 'employeeId'),
    'shiftId': data['shiftId'],
    'folio': 'REFUND-${saleId.substring(0, 6)}',
    'items': returnItems,
    'total': refundTotal,
    'paymentMethod': 'refund',
    'type': 'refund',
    'status': 'refund',
    'originalSaleId': saleId,
    'createdAt': FieldValue.serverTimestamp(),
    'clientCreatedAt': DateTime.now().toIso8601String(),
  });

  if (returnInventory) {
    final movementsRef = _firestore.collection('businesses').doc(businessId).collection('inventoryMovements');
    for (final item in returnItems) {
      final itemMap = item as Map<String, dynamic>;
      final productId = itemMap['productId'] as String?;
      final quantity = (itemMap['quantity'] as num?)?.toDouble() ?? 0;
      if (productId != null && quantity > 0) {
        final stockRef = _firestore
            .collection('businesses').doc(businessId)
            .collection('products').doc(productId)
            .collection('stockByStore').doc(storeId);
        final stockDoc = await stockRef.get();
        final previousStock = (stockDoc.data()?['stockQuantity'] as num? ?? 0).toDouble();
        final newStock = previousStock + quantity;
        await stockRef.set({
          'stockQuantity': newStock,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        await movementsRef.add({
          'businessId': businessId,
          'storeId': storeId,
          'productId': productId,
          'productName': itemMap['name'] ?? '',
          'type': 'refund',
          'previousQuantity': previousStock,
          'newQuantity': newStock,
          'difference': quantity,
          'reason': 'Devolución ${_str(data, 'refundId')}',
          'employeeId': _str(data, 'refundEmployeeId'),
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
    }
  }
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
  await _firestore.collection('businesses').doc(businessId).collection('shifts').doc(shiftId)
      .collection('cashMovements').add({
    'type': _str(data, 'type'),
    'amount': _dbl(data, 'amount'),
    'comment': _str(data, 'comment'),
    'createdAt': FieldValue.serverTimestamp(),
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
    if (saleData['isRefund'] == true) {
      if (saleData['paymentMethod'] == 'refund' || saleData['paymentMethod'] == 'cash') {
        cashRefunds += (saleData['total'] as num?)?.toDouble() ?? 0;
      }
    } else {
      totalSales += (saleData['total'] as num?)?.toDouble() ?? 0;
      if (saleData['paymentMethod'] == 'cash') cashSales += (saleData['total'] as num?)?.toDouble() ?? 0;
      if (saleData['paymentMethod'] == 'card') cardSales += (saleData['total'] as num?)?.toDouble() ?? 0;
    }
  }
  final movementsSnap = await _firestore.collection('businesses').doc(businessId).collection('shifts').doc(shiftId)
      .collection('cashMovements').get();
  double deposits = 0, withdrawals = 0;
  for (final doc in movementsSnap.docs) {
    final m = doc.data();
    if (m['type'] == 'deposit') deposits += (m['amount'] as num?)?.toDouble() ?? 0;
    if (m['type'] == 'withdrawal') withdrawals += (m['amount'] as num?)?.toDouble() ?? 0;
  }

  final shiftDoc = await _firestore.collection('businesses').doc(businessId).collection('shifts').doc(shiftId).get();
  final openingCash = (shiftDoc.data()?['openingCash'] as num?)?.toDouble() ?? 0;
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
