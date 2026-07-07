import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/business.dart';
import '../models/store.dart';
import 'connectivity_service.dart';

class BusinessService {
  final _db = FirebaseFirestore.instance;
  final _connectivityService = ConnectivityService();

  Stream<Business> watchBusiness({required String businessId}) {
    return _db.collection('businesses').doc(businessId).snapshots().map(Business.fromDoc);
  }

  Stream<List<Store>> watchStores({required String businessId}) {
    return _db
        .collection('businesses')
        .doc(businessId)
        .collection('stores')
        .snapshots()
        .map((snapshot) {
      final stores = snapshot.docs.map(Store.fromDoc).toList();
      stores.sort((a, b) => a.name.compareTo(b.name));
      return stores;
    });
  }

  Future<void> updateBusiness({
    required String businessId,
    required String name,
    required String currency,
    required String timezone,
  }) async {
    await _connectivityService.requireConnection('Editar negocio');
    final trimmedName = name.trim();
    if (trimmedName.isEmpty) {
      throw StateError('El nombre del negocio es obligatorio');
    }

    await _db.collection('businesses').doc(businessId).update({
      'name': trimmedName,
      'currency': currency.trim().isEmpty ? 'MXN' : currency.trim().toUpperCase(),
      'timezone': timezone.trim().isEmpty ? 'America/Mexico_City' : timezone.trim(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> addStore({
    required String businessId,
    required String name,
    required String address,
    required String phone,
  }) async {
    await _connectivityService.requireConnection('Crear sucursal');
    final trimmedName = name.trim();
    if (trimmedName.isEmpty) {
      throw StateError('El nombre de la sucursal es obligatorio');
    }

    await _db.collection('businesses').doc(businessId).collection('stores').add({
      'businessId': businessId,
      'name': trimmedName,
      'address': address.trim(),
      'phone': phone.trim(),
      'active': true,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateStore({
    required String businessId,
    required Store store,
    required String name,
    required String address,
    required String phone,
    required bool active,
  }) async {
    await _connectivityService.requireConnection('Editar sucursal');
    final trimmedName = name.trim();
    if (trimmedName.isEmpty) {
      throw StateError('El nombre de la sucursal es obligatorio');
    }

    await _db.collection('businesses').doc(businessId).collection('stores').doc(store.id).update({
      'name': trimmedName,
      'address': address.trim(),
      'phone': phone.trim(),
      'active': active,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}
