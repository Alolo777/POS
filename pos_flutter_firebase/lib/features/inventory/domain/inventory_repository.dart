import '../../../shared/models/inventory_movement.dart';
import '../../../shared/models/product.dart';

abstract class InventoryRepository {
  Stream<List<InventoryMovement>> watchMovements({
    required String businessId,
  });

  List<InventoryMovement>? getCachedMovements(String businessId);

  Future<void> adjustStock({
    required String businessId,
    required String storeId,
    required Product product,
    required double newQuantity,
    required String reason,
    required String employeeId,
  });
}
