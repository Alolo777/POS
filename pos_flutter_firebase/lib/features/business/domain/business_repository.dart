import '../../../shared/models/business.dart';
import '../../../shared/models/store.dart';

abstract class BusinessRepository {
  Stream<Business> watchBusiness({
    required String businessId,
  });

  Business? getCachedBusiness(String businessId);

  Stream<List<Store>> watchStores({
    required String businessId,
  });

  List<Store>? getCachedStores(String businessId);

  Future<void> updateBusiness({
    required String businessId,
    required String name,
    required String currency,
    required String timezone,
  });

  Future<void> addStore({
    required String businessId,
    required String name,
    required String address,
    required String phone,
  });

  Future<void> updateStore({
    required String businessId,
    required Store store,
    required String name,
    required String address,
    required String phone,
    required bool active,
  });
}
