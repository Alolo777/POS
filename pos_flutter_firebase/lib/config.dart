class FirestorePaths {
  static String business(String businessId) => 'businesses/$businessId';
  static String stores(String businessId) => '${business(businessId)}/stores';
  static String store(String businessId, String storeId) => '${stores(businessId)}/$storeId';
  static String employees(String businessId) => '${business(businessId)}/employees';
  static String products(String businessId) => '${business(businessId)}/products';
  static String product(String businessId, String productId) => '${products(businessId)}/$productId';
  static String stockByStore(String businessId, String productId, String storeId) =>
      '${product(businessId, productId)}/stockByStore/$storeId';
  static String categories(String businessId) => '${business(businessId)}/categories';
  static String modifiers(String businessId) => '${business(businessId)}/modifiers';
  static String discounts(String businessId) => '${business(businessId)}/discounts';
  static String sales(String businessId) => '${business(businessId)}/sales';
  static String shifts(String businessId) => '${business(businessId)}/shifts';
  static String counters(String businessId) => '${business(businessId)}/counters';
  static String counter(String businessId, String counterId) => '${counters(businessId)}/$counterId';
  static String inventoryMovements(String businessId) => '${business(businessId)}/inventoryMovements';
  static String openTickets(String businessId) => '${business(businessId)}/openTickets';
  static String productRefs(String businessId) => '${business(businessId)}/productRefs';
}

class FolioFormat {
  static const String salePrefix = 'T-';
  static const String refundPrefix = 'D-';
  static const int padding = 6;
  static String saleFolio(int number) => '$salePrefix${number.toString().padLeft(padding, '0')}';
  static String refundFolio(int number) => '$refundPrefix${number.toString().padLeft(padding, '0')}';
}

class PosConstants {
  static const String currencySymbol = '\$';
  static const String dateFormat = 'dd/MM/yyyy HH:mm';
  static const String appName = 'POS Flutter';
  static const double maxPdfWidth = 420;
}

class LogMessages {
  static String saleCreated(String folio) => 'Venta creada: $folio';
  static String saleCancelled(String folio) => 'Venta cancelada: $folio';
  static String refundCreated(String folio) => 'Devolucion creada: $folio';
  static String stockAdjusted(String product) => 'Stock ajustado: $product';
  static String error(String message) => 'Error: $message';
}
