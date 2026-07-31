import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../shared/models/discount.dart';
import '../../../core/offline/local_database.dart';
import '../../../core/offline/sync_queue.dart';
import '../../../core/network/connectivity_service.dart';
import '../domain/discount_repository.dart';

class DiscountService implements DiscountRepository {
  DiscountService({FirebaseFirestore? firestore, ConnectivityService? connectivityService})
      : _db = firestore ?? FirebaseFirestore.instance,
        _connectivityService = connectivityService ?? ConnectivityService();

  final FirebaseFirestore _db;
  final ConnectivityService _connectivityService;

  Stream<List<Discount>> watchDiscounts({required String businessId}) {
    return _db
        .collection('businesses')
        .doc(businessId)
        .collection('discounts')
        .where('active', isEqualTo: true)
        .snapshots()
        .map((snapshot) {
      final discounts = snapshot.docs.map(Discount.fromDoc).toList();
      discounts.sort((a, b) => a.name.compareTo(b.name));
      LocalDatabase.cacheDiscounts(businessId, discounts);
      return discounts;
    });
  }

  List<Discount>? getCachedDiscounts(String businessId) {
    return LocalDatabase.getCachedDiscounts(businessId);
  }

  Future<String> addDiscount({
    required String businessId,
    required String name,
    required String type,
    required double value,
  }) async {
    final trimmedName = name.trim();
    if (trimmedName.isEmpty) {
      throw StateError('El nombre del descuento es obligatorio');
    }
    if (type != 'percentage' && type != 'fixed') {
      throw StateError('El tipo debe ser percentage o fixed');
    }
    if (value <= 0) {
      throw StateError('El valor debe ser mayor a cero');
    }
    if (type == 'percentage' && value > 100) {
      throw StateError('El porcentaje no puede superar 100');
    }

    if (await _connectivityService.hasConnection()) {
      final doc = await _db.collection('businesses').doc(businessId).collection('discounts').add({
        'businessId': businessId,
        'name': trimmedName,
        'type': type,
        'value': value,
        'active': true,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return doc.id;
    } else {
      final tempId = 'temp_${DateTime.now().millisecondsSinceEpoch}';
      await SyncQueue.enqueue(type: 'addDiscount', data: {
        'businessId': businessId,
        'name': trimmedName,
        'type': type,
        'value': value,
        'tempId': tempId,
      });
      return tempId;
    }
  }

  Future<void> updateDiscount({
    required String businessId,
    required String discountId,
    required String name,
    required String type,
    required double value,
  }) async {
    final trimmedName = name.trim();
    if (trimmedName.isEmpty) {
      throw StateError('El nombre del descuento es obligatorio');
    }
    if (type != 'percentage' && type != 'fixed') {
      throw StateError('El tipo debe ser percentage o fixed');
    }
    if (value <= 0) {
      throw StateError('El valor debe ser mayor a cero');
    }
    if (type == 'percentage' && value > 100) {
      throw StateError('El porcentaje no puede superar 100');
    }

    if (await _connectivityService.hasConnection()) {
      await _db.collection('businesses').doc(businessId).collection('discounts').doc(discountId).update({
        'name': trimmedName,
        'type': type,
        'value': value,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } else {
      await SyncQueue.enqueue(type: 'updateDiscount', data: {
        'businessId': businessId,
        'discountId': discountId,
        'name': trimmedName,
        'type': type,
        'value': value,
      });
    }
  }

  Future<void> deactivateDiscount({
    required String businessId,
    required String discountId,
  }) async {
    if (await _connectivityService.hasConnection()) {
      await _db.collection('businesses').doc(businessId).collection('discounts').doc(discountId).update({
        'active': false,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } else {
      await SyncQueue.enqueue(type: 'deactivateDiscount', data: {
        'businessId': businessId,
        'discountId': discountId,
      });
    }
  }
}