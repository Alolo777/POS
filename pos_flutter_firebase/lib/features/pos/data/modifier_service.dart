import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../shared/models/modifier.dart';
import '../../../core/offline/local_database.dart';
import '../../../core/offline/sync_queue.dart';
import '../../../core/network/connectivity_service.dart';
import '../domain/modifier_repository.dart';

class ModifierService implements ModifierRepository {
  ModifierService({FirebaseFirestore? firestore, ConnectivityService? connectivityService})
      : _db = firestore ?? FirebaseFirestore.instance,
        _connectivityService = connectivityService ?? ConnectivityService();

  final FirebaseFirestore _db;
  final ConnectivityService _connectivityService;

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
      LocalDatabase.cacheModifiers(businessId, modifiers);
      return modifiers;
    });
  }

  List<Modifier>? getCachedModifiers(String businessId) {
    return LocalDatabase.getCachedModifiers(businessId);
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

    if (await _connectivityService.hasConnection()) {
      final doc = await _db.collection('businesses').doc(businessId).collection('modifiers').add({
        'businessId': businessId,
        'name': trimmedName,
        'price': price,
        'active': true,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return doc.id;
    } else {
      final tempId = 'temp_${DateTime.now().millisecondsSinceEpoch}';
      await SyncQueue.enqueue(type: 'addModifier', data: {
        'businessId': businessId,
        'name': trimmedName,
        'price': price,
        'tempId': tempId,
      });
      return tempId;
    }
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

    if (await _connectivityService.hasConnection()) {
      await _db.collection('businesses').doc(businessId).collection('modifiers').doc(modifierId).update({
        'name': trimmedName,
        'price': price,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } else {
      await SyncQueue.enqueue(type: 'updateModifier', data: {
        'businessId': businessId,
        'modifierId': modifierId,
        'name': trimmedName,
        'price': price,
      });
    }
  }

  Future<void> deactivateModifier({
    required String businessId,
    required String modifierId,
  }) async {
    if (await _connectivityService.hasConnection()) {
      await _db.collection('businesses').doc(businessId).collection('modifiers').doc(modifierId).update({
        'active': false,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } else {
      await SyncQueue.enqueue(type: 'deactivateModifier', data: {
        'businessId': businessId,
        'modifierId': modifierId,
      });
    }
  }
}