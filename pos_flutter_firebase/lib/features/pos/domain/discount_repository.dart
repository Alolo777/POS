import '../../../shared/models/discount.dart';

abstract class DiscountRepository {
  Stream<List<Discount>> watchDiscounts({
    required String businessId,
  });

  List<Discount>? getCachedDiscounts(String businessId);

  Future<String> addDiscount({
    required String businessId,
    required String name,
    required String type,
    required double value,
  });

  Future<void> updateDiscount({
    required String businessId,
    required String discountId,
    required String name,
    required String type,
    required double value,
  });

  Future<void> deactivateDiscount({
    required String businessId,
    required String discountId,
  });
}
