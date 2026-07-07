import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/category.dart';

class CategoryService {
  final _db = FirebaseFirestore.instance;

  Stream<List<Category>> watchCategories({required String businessId}) {
    return _db
        .collection('businesses')
        .doc(businessId)
        .collection('categories')
        .where('active', isEqualTo: true)
        .snapshots()
        .map((snapshot) {
      final categories = snapshot.docs.map(Category.fromDoc).toList();
      categories.sort((a, b) => a.name.compareTo(b.name));
      return categories;
    });
  }

  Future<String> addCategory({
    required String businessId,
    required String name,
    required int color,
  }) async {
    final trimmedName = name.trim();
    if (trimmedName.isEmpty) {
      throw StateError('El nombre de la categoria es obligatorio');
    }

    final doc = await _db.collection('businesses').doc(businessId).collection('categories').add({
      'businessId': businessId,
      'name': trimmedName,
      'color': color,
      'active': true,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    return doc.id;
  }

  Future<void> updateCategory({
    required String businessId,
    required String categoryId,
    required String name,
    required int color,
  }) async {
    final trimmedName = name.trim();
    if (trimmedName.isEmpty) {
      throw StateError('El nombre de la categoria es obligatorio');
    }

    final businessRef = _db.collection('businesses').doc(businessId);
    final categoryRef = businessRef.collection('categories').doc(categoryId);

    await _db.runTransaction((transaction) async {
      final categorySnapshot = await transaction.get(categoryRef);
      if (!categorySnapshot.exists) {
        throw StateError('La categoria ya no existe');
      }

      transaction.update(categoryRef, {
        'name': trimmedName,
        'color': color,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });

    final products = await businessRef
        .collection('products')
        .where('categoryId', isEqualTo: categoryId)
        .get();

    var batch = _db.batch();
    var writes = 0;
    for (final product in products.docs) {
      batch.update(product.reference, {
        'categoryName': trimmedName,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      writes++;
      if (writes == 450) {
        await batch.commit();
        batch = _db.batch();
        writes = 0;
      }
    }
    if (writes > 0) {
      await batch.commit();
    }
  }

  Future<void> deactivateCategory({
    required String businessId,
    required String categoryId,
  }) async {
    final businessRef = _db.collection('businesses').doc(businessId);
    final categoryRef = businessRef.collection('categories').doc(categoryId);

    await categoryRef.update({
      'active': false,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    final products = await businessRef
        .collection('products')
        .where('categoryId', isEqualTo: categoryId)
        .get();

    var batch = _db.batch();
    var writes = 0;
    for (final product in products.docs) {
      batch.update(product.reference, {
        'categoryId': null,
        'categoryName': null,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      writes++;
      if (writes == 450) {
        await batch.commit();
        batch = _db.batch();
        writes = 0;
      }
    }
    if (writes > 0) {
      await batch.commit();
    }
  }
}
