import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/modifier.dart';

class ModifierService {
  final _db = FirebaseFirestore.instance;

  Stream<List<Modifier>> watchModifiers({required String businessId}) {
    return _db
        .collection('businesses')
        .doc(businessId)
        .collection('modifiers')
        .where('active', isEqualTo: true)
        .snapshots()
        .map((snapshot) {
      final modifiers = snapshot.docs.map(Modifier.fromDoc).toList();
      modifiers.sort((a, b) => a.name.compareTo(b.name));
      return modifiers;
    });
  }

  Future<String> addModifier({
    required String businessId,
    required String name,
    required double price,
  }) async {
    final trimmedName = name.trim();
    if (trimmedName.isEmpty) {
      throw StateError('El nombre del modificador es obligatorio');
    }
    if (price < 0) {
      throw StateError('El precio no puede ser negativo');
    }

    final doc = await _db.collection('businesses').doc(businessId).collection('modifiers').add({
      'businessId': businessId,
      'name': trimmedName,
      'price': price,
      'active': true,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    return doc.id;
  }

  Future<void> updateModifier({
    required String businessId,
    required String modifierId,
    required String name,
    required double price,
  }) async {
    final trimmedName = name.trim();
    if (trimmedName.isEmpty) {
      throw StateError('El nombre del modificador es obligatorio');
    }
    if (price < 0) {
      throw StateError('El precio no puede ser negativo');
    }

    await _db.collection('businesses').doc(businessId).collection('modifiers').doc(modifierId).update({
      'name': trimmedName,
      'price': price,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deactivateModifier({
    required String businessId,
    required String modifierId,
  }) async {
    await _db.collection('businesses').doc(businessId).collection('modifiers').doc(modifierId).update({
      'active': false,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}
