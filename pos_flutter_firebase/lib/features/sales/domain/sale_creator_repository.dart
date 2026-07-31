import '../../../shared/models/cart_item.dart';

abstract class SaleCreatorRepository {
  Future<String> createSale({
    required String businessId,
    required String storeId,
    required String employeeId,
    required String shiftId,
    required List<CartItem> items,
    required double subtotal,
    required double discountTotal,
    required double total,
    required String paymentMethod,
    double? cashReceived,
    double? changeDue,
    String? createdByUid,
  });
}
