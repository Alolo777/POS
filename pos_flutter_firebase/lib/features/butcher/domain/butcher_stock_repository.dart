abstract class ButcherStockRepository {
  Future<void> assignPendingStockToProduct({
    required String businessId,
    required String sectionName,
    required String productId,
    required String storeId,
  });

  Future<List<({String name, double totalWeight, double percentage})>> getPendingStockBySection(
    String businessId, {
    String? storeId,
  });

  Future<void> clearStoreStock({
    required String businessId,
    required String storeId,
  });

  Future<Map<String, ({double price, double stock, double sales})>> getSectionRealData({
    required String businessId,
    required String storeId,
    required List<String> sectionNames,
  });
}
