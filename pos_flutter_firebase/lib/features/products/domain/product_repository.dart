import 'package:image_picker/image_picker.dart';

import '../../../shared/models/product.dart';

abstract class ProductRepository {
  Stream<List<Product>> watchProducts({
    required String businessId,
  });

  List<Product>? getCachedProducts(String businessId);

  Future<String> getSuggestedRef({
    required String businessId,
  });

  Future<void> addProduct({
    required String businessId,
    required String storeId,
    required String name,
    required String? categoryId,
    required String? categoryName,
    required String sellBy,
    required double price,
    required double cost,
    required String ref,
    required bool trackStock,
    required double stockQuantity,
    required double lowStockAlertQuantity,
    required String presentationType,
    required String presentationShape,
    required int presentationColor,
    double? storePrice,
    XFile? imageFile,
  });

  Future<void> updateProduct({
    required String businessId,
    required String storeId,
    required Product product,
    required String name,
    required String? categoryId,
    required String? categoryName,
    required String sellBy,
    required double price,
    required double cost,
    required String ref,
    required bool trackStock,
    required double stockQuantity,
    required double lowStockAlertQuantity,
    required String presentationType,
    required String presentationShape,
    required int presentationColor,
    double? storePrice,
    XFile? imageFile,
  });

  Future<void> deactivateProduct({
    required String businessId,
    required Product product,
  });
}
