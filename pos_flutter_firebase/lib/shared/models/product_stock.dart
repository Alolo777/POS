import 'package:cloud_firestore/cloud_firestore.dart';

class ProductStock {
  const ProductStock({
    required this.productId,
    required this.storeId,
    required this.stockQuantity,
    required this.lowStockAlertQuantity,
    this.chickenCount,
    this.price,
  });

  final String productId;
  final String storeId;
  final double stockQuantity;
  final double lowStockAlertQuantity;
  final int? chickenCount;

  /// Precio específico de esta sucursal. Si es null se usa el precio global
  /// del producto.
  final double? price;

  factory ProductStock.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};

    return ProductStock(
      productId: data['productId'] as String? ?? '',
      storeId: data['storeId'] as String? ?? doc.id,
      stockQuantity: (data['stockQuantity'] as num? ?? data['stock'] as num? ?? 0).toDouble(),
      lowStockAlertQuantity: (data['lowStockAlertQuantity'] as num? ?? data['lowStockAlert'] as num? ?? 0).toDouble(),
      chickenCount: data['chickenCount'] as int?,
      price: (data['price'] as num?)?.toDouble(),
    );
  }
}