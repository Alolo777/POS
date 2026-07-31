import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/poultry_repository.dart';
import '../domain/poultry_config.dart';
import '../domain/chicken_receiving.dart';

class PoultryService implements PoultryRepository {
  PoultryService({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  @override
  Future<PoultryConfig?> getConfig(String businessId) async {
    final doc = await _db
        .collection('businesses')
        .doc(businessId)
        .collection('config')
        .doc('poultry')
        .get();
    if (!doc.exists) return null;
    return PoultryConfig.fromMap(doc.data()!);
  }

  @override
  Future<void> saveConfig(String businessId, PoultryConfig config) async {
    await _db
        .collection('businesses')
        .doc(businessId)
        .collection('config')
        .doc('poultry')
        .set(config.toMap(), SetOptions(merge: true));
  }

  @override
  Future<void> saveReceiving(
    String businessId,
    ChickenReceiving receiving,
  ) async {
    final wholeProductId = await _ensureWholeProduct(
      businessId,
      receiving.storeId,
    );

    final receivingRef = _db
        .collection('businesses')
        .doc(businessId)
        .collection('poultryReceivings')
        .doc();

    final stockRef = _db
        .collection('businesses')
        .doc(businessId)
        .collection('products')
        .doc(wholeProductId)
        .collection('stockByStore')
        .doc(receiving.storeId);

    final movementsRef = _db
        .collection('businesses')
        .doc(businessId)
        .collection('inventoryMovements');

    final existingStockDoc = await stockRef.get();
    if (!existingStockDoc.exists) {
      await stockRef.set({
        'businessId': businessId,
        'storeId': receiving.storeId,
        'productId': wholeProductId,
        'stockQuantity': 0,
        'chickenCount': 0,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }

    await _db.runTransaction((txn) async {
      final stockDoc = await txn.get(stockRef);
      final data = stockDoc.data() as Map<String, dynamic>?;
      final previousStock = (data?['stockQuantity'] as num? ?? 0).toDouble();
      final previousCount = data?['chickenCount'] as int? ?? 0;
      final newStock = previousStock + receiving.totalWeightKg;
      final newCount = previousCount + receiving.totalChickens;

      txn.set(receivingRef, {
        ...receiving.toMap(),
        'createdAt': FieldValue.serverTimestamp(),
      });

      txn.set(stockRef, {
        'businessId': businessId,
        'storeId': receiving.storeId,
        'productId': wholeProductId,
        'stockQuantity': newStock,
        'chickenCount': newCount,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      txn.set(movementsRef.doc(), {
        'businessId': businessId,
        'storeId': receiving.storeId,
        'productId': wholeProductId,
        'productName': 'Pollo Entero',
        'type': 'receiving',
        'previousQuantity': previousStock,
        'newQuantity': newStock,
        'difference': receiving.totalWeightKg,
        'reason': 'Recepción de ${receiving.totalChickens} pollos',
        'employeeId': receiving.employeeId,
        'createdAt': FieldValue.serverTimestamp(),
      });
    });
  }

  Future<String> _ensureWholeProduct(
    String businessId,
    String storeId,
  ) async {
    final configDoc = await _db
        .collection('businesses')
        .doc(businessId)
        .collection('config')
        .doc('poultry')
        .get();

    String? existingId;
    if (configDoc.exists) {
      final config = PoultryConfig.fromMap(configDoc.data()!);
      existingId = config.wholeProductId;
    }

    if (existingId != null) {
      final productDoc = await _db
          .collection('businesses')
          .doc(businessId)
          .collection('products')
          .doc(existingId)
          .get();
      if (productDoc.exists) return existingId;
    }

    final query = await _db
        .collection('businesses')
        .doc(businessId)
        .collection('products')
        .where('name', isEqualTo: 'Pollo Entero')
        .where('active', isEqualTo: true)
        .limit(1)
        .get();

    if (query.docs.isNotEmpty) {
      final id = query.docs.first.id;
      await _saveWholeProductId(businessId, id);
      return id;
    }

    final now = FieldValue.serverTimestamp();
    final ref = _generateRef();
    final productRef = _db
        .collection('businesses')
        .doc(businessId)
        .collection('products')
        .doc();

    await productRef.set({
      'businessId': businessId,
      'name': 'Pollo Entero',
      'description': 'Pollos enteros recibidos por destazar',
      'sku': ref,
      'barcode': '',
      'categoryId': null,
      'categoryName': null,
      'sellBy': 'weight',
      'imageUrl': null,
      'localImagePath': null,
      'price': 0.0,
      'cost': 0.0,
      'ref': ref,
      'trackStock': true,
      'stock': 0,
      'stockQuantity': 0.0,
      'lowStockAlert': 0,
      'lowStockAlertQuantity': 0.0,
      'presentationType': 'shape',
      'presentationShape': 'square',
      'presentationColor': 0xFF868E96,
      'active': true,
      'createdAt': now,
      'updatedAt': now,
    });

    final stockRef = productRef.collection('stockByStore').doc(storeId);
    await stockRef.set({
      'businessId': businessId,
      'storeId': storeId,
      'productId': productRef.id,
      'stock': 0,
      'stockQuantity': 0.0,
      'chickenCount': 0,
      'lowStockAlert': 0,
      'lowStockAlertQuantity': 0.0,
      'createdAt': now,
      'updatedAt': now,
    });

    await _saveWholeProductId(businessId, productRef.id);

    return productRef.id;
  }

  Future<void> _saveWholeProductId(String businessId, String productId) async {
    await _db
        .collection('businesses')
        .doc(businessId)
        .collection('config')
        .doc('poultry')
        .set({
      'wholeProductId': productId,
    }, SetOptions(merge: true));
  }

  String _generateRef() {
    final ts = DateTime.now().millisecondsSinceEpoch;
    return 'PO${ts.toString().substring(ts.toString().length - 8)}';
  }

  @override
  Stream<List<ChickenReceiving>> watchReceivings(
    String businessId,
    String storeId,
  ) {
    return _db
        .collection('businesses')
        .doc(businessId)
        .collection('poultryReceivings')
        .where('storeId', isEqualTo: storeId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ChickenReceiving.fromMap(doc.id, doc.data()))
            .toList());
  }
}
