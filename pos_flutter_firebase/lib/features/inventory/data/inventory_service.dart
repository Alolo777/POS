import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../shared/models/inventory_movement.dart';
import '../../../shared/models/product.dart';
import '../../../core/offline/local_database.dart';
import '../../../core/offline/sync_queue.dart';
import '../../../core/network/connectivity_service.dart';
import '../domain/inventory_repository.dart';

class InventoryService implements InventoryRepository {
  InventoryService({FirebaseFirestore? firestore, ConnectivityService? connectivityService})
      : _db = firestore ?? FirebaseFirestore.instance,
        _connectivityService = connectivityService ?? ConnectivityService();

  final FirebaseFirestore _db;
  final ConnectivityService _connectivityService;

  Stream<List<InventoryMovement>> watchMovements({required String businessId}) {
    final controller = StreamController<List<InventoryMovement>>.broadcast();

    final cached = LocalDatabase.getCachedInventoryMovements(businessId);
    if (cached != null) {
      controller.add(cached);
    }

    final sub = _db
        .collection('businesses')
        .doc(businessId)
        .collection('inventoryMovements')
        .snapshots()
        .listen(
      (snapshot) {
        final movements = snapshot.docs.map((doc) => InventoryMovement.fromMap(doc.data(), doc.id)).toList();
        movements.sort((a, b) {
          final aDate = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
          final bDate = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
          return bDate.compareTo(aDate);
        });
        LocalDatabase.cacheInventoryMovements(businessId, movements);
        controller.add(movements);
      },
      onError: controller.addError,
    );

    controller.onCancel = () => sub.cancel();
    return controller.stream;
  }

  List<InventoryMovement>? getCachedMovements(String businessId) {
    return LocalDatabase.getCachedInventoryMovements(businessId);
  }

  Future<void> adjustStock({
    required String businessId,
    required String storeId,
    required Product product,
    required double newQuantity,
    required String reason,
    required String employeeId,
  }) async {
    if (!product.trackStock) {
      throw StateError('Este producto no controla inventario');
    }
    if (newQuantity < 0) {
      throw StateError('El inventario no puede ser negativo');
    }
    if (product.sellBy == 'unit' && newQuantity % 1 != 0) {
      throw StateError('Los productos por unidad deben usar cantidades enteras');
    }

    if (await _connectivityService.hasConnection()) {
      final productRef = _db.collection('businesses').doc(businessId).collection('products').doc(product.id);
      final stockRef = productRef.collection('stockByStore').doc(storeId);
      final movementRef = _db.collection('businesses').doc(businessId).collection('inventoryMovements').doc();

      await _db.runTransaction((transaction) async {
        final productSnapshot = await transaction.get(productRef);
        final stockSnapshot = await transaction.get(stockRef);
        if (!productSnapshot.exists) {
          throw StateError('El producto ya no existe');
        }
        final data = stockSnapshot.data() ?? {};
        final previousQuantity = (data['stockQuantity'] as num? ?? data['stock'] as num? ?? 0).toDouble();
        final difference = newQuantity - previousQuantity;

        transaction.set(stockRef, {
          'businessId': businessId,
          'storeId': storeId,
          'productId': product.id,
          'stock': newQuantity.round(),
          'stockQuantity': newQuantity,
          'lowStockAlert': product.lowStockAlertQuantity.round(),
          'lowStockAlertQuantity': product.lowStockAlertQuantity,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        transaction.set(movementRef, {
          'businessId': businessId,
          'storeId': storeId,
          'productId': product.id,
          'productName': product.name,
          'type': 'adjustment',
          'previousQuantity': previousQuantity,
          'newQuantity': newQuantity,
          'difference': difference,
          'reason': reason.trim().isEmpty ? 'Ajuste manual' : reason.trim(),
          'employeeId': employeeId,
          'createdAt': FieldValue.serverTimestamp(),
        });
      });
    } else {
      await SyncQueue.enqueue(type: 'adjustStock', data: {
        'businessId': businessId,
        'storeId': storeId,
        'productId': product.id,
        'newQuantity': newQuantity,
        'reason': reason.trim().isEmpty ? 'Ajuste manual' : reason.trim(),
        'employeeId': employeeId,
      });
    }
  }
}