import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../shared/models/business.dart';
import '../../../shared/models/store.dart';
import '../../../core/offline/local_database.dart';
import '../../../core/offline/sync_queue.dart';
import '../../../core/network/connectivity_service.dart';
import '../domain/business_repository.dart';

class BusinessService implements BusinessRepository {
  BusinessService({FirebaseFirestore? firestore, ConnectivityService? connectivityService})
      : _db = firestore ?? FirebaseFirestore.instance,
        _connectivityService = connectivityService ?? ConnectivityService();

  final FirebaseFirestore _db;
  final ConnectivityService _connectivityService;

  Stream<Business> watchBusiness({required String businessId}) {
    return _db.collection('businesses').doc(businessId).snapshots().map((doc) {
      final business = Business.fromDoc(doc);
      LocalDatabase.cacheBusiness(businessId, business);
      return business;
    });
  }

  Business? getCachedBusiness(String businessId) {
    return LocalDatabase.getCachedBusiness(businessId);
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
      LocalDatabase.cacheStores(businessId, stores);
      return stores;
    });
  }

  List<Store>? getCachedStores(String businessId) {
    return LocalDatabase.getCachedStores(businessId);
  }

  Future<void> updateBusiness({
    required String businessId,
    required String name,
    required String currency,
    required String timezone,
  }) async {
    final trimmedName = name.trim();
    if (trimmedName.isEmpty) {
      throw StateError('El nombre del negocio es obligatorio');
    }

    if (await _connectivityService.hasConnection()) {
      await _db.collection('businesses').doc(businessId).update({
        'name': trimmedName,
        'currency': currency.trim().isEmpty ? 'MXN' : currency.trim().toUpperCase(),
        'timezone': timezone.trim().isEmpty ? 'America/Mexico_City' : timezone.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } else {
      await SyncQueue.enqueue(type: 'updateBusiness', data: {
        'businessId': businessId,
        'name': trimmedName,
        'currency': currency.trim().isEmpty ? 'MXN' : currency.trim().toUpperCase(),
        'timezone': timezone.trim().isEmpty ? 'America/Mexico_City' : timezone.trim(),
      });
    }
  }

  Future<void> addStore({
    required String businessId,
    required String name,
    required String address,
    required String phone,
  }) async {
    final trimmedName = name.trim();
    if (trimmedName.isEmpty) {
      throw StateError('El nombre de la sucursal es obligatorio');
    }

    if (await _connectivityService.hasConnection()) {
      await _db.collection('businesses').doc(businessId).collection('stores').add({
        'businessId': businessId,
        'name': trimmedName,
        'address': address.trim(),
        'phone': phone.trim(),
        'active': true,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } else {
      await SyncQueue.enqueue(type: 'addStore', data: {
        'businessId': businessId,
        'name': trimmedName,
        'address': address.trim(),
        'phone': phone.trim(),
      });
    }
  }

  Future<void> updateStore({
    required String businessId,
    required Store store,
    required String name,
    required String address,
    required String phone,
    required bool active,
  }) async {
    final trimmedName = name.trim();
    if (trimmedName.isEmpty) {
      throw StateError('El nombre de la sucursal es obligatorio');
    }

    if (await _connectivityService.hasConnection()) {
      await _db.collection('businesses').doc(businessId).collection('stores').doc(store.id).update({
        'name': trimmedName,
        'address': address.trim(),
        'phone': phone.trim(),
        'active': active,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } else {
      await SyncQueue.enqueue(type: 'updateStore', data: {
        'businessId': businessId,
        'storeId': store.id,
        'name': trimmedName,
        'address': address.trim(),
        'phone': phone.trim(),
        'active': active,
      });
    }
  }
}