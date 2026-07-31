import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/offline/local_database.dart';

class ButcherStockService {
  ButcherStockService({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  FirebaseFirestore get firestore => _db;

  CollectionReference _productsRef(String businessId) =>
      _db.collection('businesses').doc(businessId).collection('products');

  DocumentReference _stockRef(String businessId, String productId, String storeId) =>
      _db.collection('businesses').doc(businessId).collection('products').doc(productId).collection('stockByStore').doc(storeId);

  CollectionReference _receiptsRef(String businessId) =>
      _db.collection('businesses').doc(businessId).collection('butcherReceipts');

  CollectionReference _salesRef(String businessId) =>
      _db.collection('businesses').doc(businessId).collection('sales');

  Future<void> addStockFromYields({
    required String businessId,
    required String storeId,
    required List<({String name, double weight, double percentage})> yields,
  }) async {
    for (final yield_ in yields) {
      await _applyStockChange(
        businessId: businessId,
        storeId: storeId,
        sectionName: yield_.name,
        weight: yield_.weight,
        multiplier: 1,
      );
    }
  }

  Future<void> subtractStockFromYields({
    required String businessId,
    required String storeId,
    required List<({String name, double weight, double percentage})> yields,
  }) async {
    for (final yield_ in yields) {
      await _applyStockChange(
        businessId: businessId,
        storeId: storeId,
        sectionName: yield_.name,
        weight: yield_.weight,
        multiplier: -1,
      );
    }
  }

  Future<void> _applyStockChange({
    required String businessId,
    required String storeId,
    required String sectionName,
    required double weight,
    required int multiplier,
  }) async {
    final products = await _productsRef(businessId)
        .where('name', isEqualTo: sectionName)
        .where('active', isEqualTo: true)
        .limit(1)
        .get();

    if (products.docs.isEmpty) return;

    final productDoc = products.docs.first;
    final productId = productDoc.id;
    final productData = productDoc.data() as Map<String, dynamic>;

    if (productData['trackStock'] != true) return;

    final stockRef = _stockRef(businessId, productId, storeId);

    await _db.runTransaction((txn) async {
      final stockDoc = await txn.get(stockRef);
      final currentStock =
          (stockDoc.exists ? (stockDoc.data() as Map<String, dynamic>)['stockQuantity'] ?? 0.0 : 0.0) as num;
      var newStock = currentStock.toDouble() + (weight * multiplier);
      if (newStock < 0) newStock = 0;
      txn.set(stockRef, {
        'businessId': businessId,
        'storeId': storeId,
        'productId': productId,
        'stockQuantity': newStock,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    });
  }

  Future<void> assignPendingStockToProduct({
    required String businessId,
    required String sectionName,
    required String productId,
    required String storeId,
  }) async {
    final sevenDaysAgo = DateTime.now().subtract(const Duration(days: 7));
    final receipts = await _receiptsRef(businessId)
        .where('storeId', isEqualTo: storeId)
        .where('status', isEqualTo: 'active')
        .where('createdAt', isGreaterThanOrEqualTo: sevenDaysAgo)
        .orderBy('createdAt', descending: true)
        .get();

    double totalPendingWeight = 0;
    final List<String> receiptIdsToUpdate = [];
    final Map<String, List<String>> receiptConsumedSections = {};

    for (final doc in receipts.docs) {
      final data = doc.data() as Map<String, dynamic>;
      final yields = (data['yields'] as List<dynamic>?) ?? [];
      final consumedSections =
          (data['consumedSections'] as List<dynamic>?)?.cast<String>() ?? [];

      for (final yield_ in yields) {
        final name = yield_['name'] as String;
        final weight = yield_['weight'] as double;
        if (name == sectionName && !consumedSections.contains(name)) {
          totalPendingWeight += weight;
          receiptIdsToUpdate.add(doc.id);
          receiptConsumedSections.putIfAbsent(doc.id, () => []);
          receiptConsumedSections[doc.id]!.add(name);
        }
      }
    }

    if (totalPendingWeight <= 0) return;

    final stockRef = _stockRef(businessId, productId, storeId);
    await _db.runTransaction((txn) async {
      final stockDoc = await txn.get(stockRef);
      final currentStock =
          (stockDoc.exists ? (stockDoc.data() as Map<String, dynamic>)['stockQuantity'] ?? 0.0 : 0.0) as num;
      txn.set(stockRef, {
        'stockQuantity': currentStock.toDouble() + totalPendingWeight,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    });

    for (final receiptId in receiptIdsToUpdate) {
      final sectionsToAdd = receiptConsumedSections[receiptId] ?? [];
      if (sectionsToAdd.isNotEmpty) {
        await _receiptsRef(businessId).doc(receiptId).update({
          'consumedSections': FieldValue.arrayUnion(sectionsToAdd),
        });
      }
    }
  }

  Future<List<({String name, double totalWeight, double percentage})>> getPendingStockBySection(
    String businessId, {
    String? storeId,
  }) async {
    final sevenDaysAgo = DateTime.now().subtract(const Duration(days: 7));
    Query query = _receiptsRef(businessId)
        .where('status', isEqualTo: 'active')
        .where('createdAt', isGreaterThanOrEqualTo: sevenDaysAgo);
    if (storeId != null) {
      query = query.where('storeId', isEqualTo: storeId);
    }
    final receipts = await query.orderBy('createdAt', descending: true).get();

    final Map<String, double> sectionWeights = {};

    for (final doc in receipts.docs) {
      final data = doc.data() as Map<String, dynamic>;
      final yields = (data['yields'] as List<dynamic>?) ?? [];
      final consumedSections =
          (data['consumedSections'] as List<dynamic>?)?.cast<String>() ?? [];

      for (final yield_ in yields) {
        final name = yield_['name'] as String;
        final weight = yield_['weight'] as double;
        if (!consumedSections.contains(name)) {
          sectionWeights[name] = (sectionWeights[name] ?? 0) + weight;
        }
      }
    }

    final totalWeight =
        sectionWeights.values.fold<double>(0, (sum, w) => sum + w);

    return sectionWeights.entries.map((e) {
      final percentage = totalWeight > 0 ? (e.value / totalWeight) * 100 : 0.0;
      return (name: e.key, totalWeight: e.value, percentage: percentage);
    }).toList()
      ..sort((a, b) => a.name.compareTo(b.name));
  }

  Future<void> clearStoreStock({
    required String businessId,
    required String storeId,
  }) async {
    final products = await _productsRef(businessId)
        .where('active', isEqualTo: true)
        .where('trackStock', isEqualTo: true)
        .get();

    final batch = _db.batch();
    for (final product in products.docs) {
      final stockRef = _stockRef(businessId, product.id, storeId);
      batch.set(stockRef, {
        'stockQuantity': 0,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }
    await batch.commit();

    await LocalDatabase.clearCachedStockForStore(businessId, storeId);

    await _consumePendingSectionsForStore(businessId: businessId, storeId: storeId);
  }

  Future<void> _consumePendingSectionsForStore({
    required String businessId,
    required String storeId,
  }) async {
    final sevenDaysAgo = DateTime.now().subtract(const Duration(days: 7));
    final receipts = await _receiptsRef(businessId)
        .where('storeId', isEqualTo: storeId)
        .where('status', isEqualTo: 'active')
        .where('createdAt', isGreaterThanOrEqualTo: sevenDaysAgo)
        .orderBy('createdAt', descending: true)
        .get();

    final batch = _db.batch();
    for (final doc in receipts.docs) {
      final data = doc.data() as Map<String, dynamic>;
      final yields = (data['yields'] as List<dynamic>?) ?? [];
      final allSectionNames = yields.map((y) => y['name'] as String).toList();
      if (allSectionNames.isNotEmpty) {
        batch.update(doc.reference, {
          'consumedSections': FieldValue.arrayUnion(allSectionNames),
        });
      }
    }
    await batch.commit();
  }

  Future<Map<String, ({double price, double stock, double sales})>> getSectionRealData({
    required String businessId,
    required String storeId,
    required List<String> sectionNames,
  }) async {
    final result = <String, ({double price, double stock, double sales})>{};

    // ── BULK QUERY 1: All active products ──
    final productsSnapshot = await _productsRef(businessId)
        .where('active', isEqualTo: true)
        .get();
    final productsByName = <String, ({String id, num price, bool trackStock})>{};
    for (final doc in productsSnapshot.docs) {
      final data = doc.data() as Map<String, dynamic>;
      final name = data['name'] as String? ?? '';
      if (sectionNames.contains(name)) {
        productsByName[name] = (
          id: doc.id,
          price: (data['price'] ?? 0.0) as num,
          trackStock: data['trackStock'] == true,
        );
      }
    }

    // ── BULK QUERY 2: All stock for this store ──
    final stockSnapshot = await _db
        .collectionGroup('stockByStore')
        .where('storeId', isEqualTo: storeId)
        .get();
    final stockByProductId = <String, double>{};
    for (final doc in stockSnapshot.docs) {
      final data = doc.data();
      final productId = (data['productId'] as String?) ?? doc.reference.parent.parent?.id ?? '';
      final quantity = (data['stockQuantity'] ?? 0.0).toDouble();
      stockByProductId[productId] = quantity;
    }

    // ── BULK QUERY 3: Today's sales for this store (once) ──
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final salesSnapshot = await _salesRef(businessId)
        .where('storeId', isEqualTo: storeId)
        .where('createdAt', isGreaterThanOrEqualTo: startOfDay)
        .get();
    final salesCountByName = <String, double>{};
    for (final saleDoc in salesSnapshot.docs) {
      final saleData = saleDoc.data() as Map<String, dynamic>;
      final items = (saleData['items'] as List<dynamic>?) ?? [];
      for (final item in items) {
        final itemName = item['name'] as String? ?? '';
        final quantity = (item['quantity'] as num? ?? 0).toDouble();
        salesCountByName[itemName] = (salesCountByName[itemName] ?? 0) + quantity;
      }
    }

    // ── Assemble result in memory ──
    for (final name in sectionNames) {
      final product = productsByName[name];
      if (product == null) {
        result[name] = (price: 0.0, stock: 0.0, sales: 0.0);
        continue;
      }
      final stock = product.trackStock ? (stockByProductId[product.id] ?? 0.0) : 0.0;
      final sales = salesCountByName[name] ?? 0;
      result[name] = (
        price: product.price.toDouble(),
        stock: stock,
        sales: sales,
      );
    }

    return result;
  }
}
