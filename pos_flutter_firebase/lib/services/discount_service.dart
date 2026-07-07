import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/discount.dart';

class DiscountService {
  final _db = FirebaseFirestore.instance;

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
      return discounts;
    });
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

    await _db.collection('businesses').doc(businessId).collection('discounts').doc(discountId).update({
      'name': trimmedName,
      'type': type,
      'value': value,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deactivateDiscount({
    required String businessId,
    required String discountId,
  }) async {
    await _db.collection('businesses').doc(businessId).collection('discounts').doc(discountId).update({
      'active': false,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  double applyDiscount(double amount, Discount discount) {
    if (discount.isPercentage) {
      return amount * (discount.value / 100);
    }
    return discount.value > amount ? amount : discount.value;
  }
}
