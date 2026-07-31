import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../shared/models/category.dart';
import '../../../core/offline/local_database.dart';
import '../../../core/offline/sync_queue.dart';
import '../../../core/network/connectivity_service.dart';
import '../domain/category_repository.dart';

class CategoryService implements CategoryRepository {
  CategoryService({FirebaseFirestore? firestore, ConnectivityService? connectivityService})
      : _db = firestore ?? FirebaseFirestore.instance,
        _connectivityService = connectivityService ?? ConnectivityService();

  final FirebaseFirestore _db;
  final ConnectivityService _connectivityService;

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
      LocalDatabase.cacheCategories(businessId, categories);
      return categories;
    });
  }

  List<Category>? getCachedCategories(String businessId) {
    return LocalDatabase.getCachedCategories(businessId);
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

    if (await _connectivityService.hasConnection()) {
      final doc = await _db.collection('businesses').doc(businessId).collection('categories').add({
        'businessId': businessId,
        'name': trimmedName,
        'color': color,
        'active': true,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return doc.id;
    } else {
      final tempId = 'temp_${DateTime.now().millisecondsSinceEpoch}';
      await SyncQueue.enqueue(type: 'addCategory', data: {
        'businessId': businessId,
        'name': trimmedName,
        'color': color,
        'tempId': tempId,
      });
      return tempId;
    }
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

    if (await _connectivityService.hasConnection()) {
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
    } else {
      await SyncQueue.enqueue(type: 'updateCategory', data: {
        'businessId': businessId,
        'categoryId': categoryId,
        'name': trimmedName,
        'color': color,
      });
    }
  }

  Future<void> deactivateCategory({
    required String businessId,
    required String categoryId,
  }) async {
    if (await _connectivityService.hasConnection()) {
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
    } else {
      await SyncQueue.enqueue(type: 'deactivateCategory', data: {
        'businessId': businessId,
        'categoryId': categoryId,
      });
    }
  }
}