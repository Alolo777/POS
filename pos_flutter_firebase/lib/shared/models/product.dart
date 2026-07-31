import 'package:cloud_firestore/cloud_firestore.dart';

class Product {
  const Product({
    required this.id,
    required this.name,
    required this.categoryId,
    required this.categoryName,
    required this.sellBy,
    required this.price,
    required this.cost,
    required this.ref,
    required this.trackStock,
    required this.stockQuantity,
    required this.lowStockAlertQuantity,
    required this.presentationType,
    required this.presentationShape,
    required this.presentationColor,
    required this.imageUrl,
    required this.localImagePath,
    required this.active,
    this.stockLoaded = false,
  });

  final String id;
  final String name;
  final String? categoryId;
  final String? categoryName;
  final String sellBy;
  final double price;
  final double cost;
  final String ref;
  final bool trackStock;
  final double stockQuantity;
  final double lowStockAlertQuantity;
  final String presentationType;
  final String presentationShape;
  final int presentationColor;
  final String? imageUrl;
  final String? localImagePath;
  final bool active;
  final bool stockLoaded;

  factory Product.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};

    return Product(
      id: doc.id,
      name: data['name'] as String? ?? '',
      categoryId: data['categoryId'] as String?,
      categoryName: data['categoryName'] as String?,
      sellBy: data['sellBy'] as String? ?? 'unit',
      price: (data['price'] as num? ?? 0).toDouble(),
      cost: (data['cost'] as num? ?? 0).toDouble(),
      ref: data['ref'] as String? ?? '',
      trackStock: data['trackStock'] as bool? ?? false,
      stockQuantity: (data['stockQuantity'] as num? ?? data['stock'] as num? ?? 0).toDouble(),
      lowStockAlertQuantity:
          (data['lowStockAlertQuantity'] as num? ?? data['lowStockAlert'] as num? ?? 0).toDouble(),
      presentationType: data['presentationType'] as String? ?? 'shape',
      presentationShape: data['presentationShape'] as String? ?? 'square',
      presentationColor: (data['presentationColor'] as num? ?? 0xFF9E9E9E).toInt(),
      imageUrl: data['imageUrl'] as String?,
      localImagePath: data['localImagePath'] as String?,
      active: data['active'] as bool? ?? true,
      stockLoaded: true,
    );
  }
}