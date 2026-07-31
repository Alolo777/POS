import '../../../shared/models/product_stock.dart';

abstract class StockRepository {
  Stream<Map<String, ProductStock>> watchStockByStore({
    required String businessId,
    required String storeId,
  });

  Map<String, ProductStock>? getCachedStock(String businessId);

  Future<void> applyLocalStockDelta({
    required String businessId,
    required String productId,
    required double delta,
  });
}
