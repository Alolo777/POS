import '../../../shared/models/sale.dart';

abstract class SaleRefundRepository {
  Future<String> cancelSale({
    required String businessId,
    required Sale sale,
    required List<Map<String, dynamic>> returnItems,
    required bool returnInventory,
    required String reason,
    String? refundShiftId,
    String? refundEmployeeId,
  });

  Future<bool> refundExists({
    required String businessId,
    required String refundId,
  });
}
