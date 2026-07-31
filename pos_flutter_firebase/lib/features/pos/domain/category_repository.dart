import '../../../shared/models/category.dart';

abstract class CategoryRepository {
  Stream<List<Category>> watchCategories({
    required String businessId,
  });

  List<Category>? getCachedCategories(String businessId);

  Future<String> addCategory({
    required String businessId,
    required String name,
    required int color,
  });

  Future<void> updateCategory({
    required String businessId,
    required String categoryId,
    required String name,
    required int color,
  });

  Future<void> deactivateCategory({
    required String businessId,
    required String categoryId,
  });
}
