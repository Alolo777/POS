import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../shared/models/butcher_section.dart';
import '../../../core/network/connectivity_service.dart';
import '../domain/butcher_anomaly.dart';
import '../domain/butcher_record.dart';
import 'butcher_stock_service.dart';

class ButcherReceiptService {
  ButcherReceiptService({
    required ConnectivityService connectivityService,
    required ButcherStockService stockService,
    FirebaseFirestore? firestore,
  })  : _db = firestore ?? FirebaseFirestore.instance,
        _connectivityService = connectivityService,
        _stockService = stockService;

  final FirebaseFirestore _db;
  final ConnectivityService _connectivityService;
  final ButcherStockService _stockService;

  CollectionReference _receiptsRef(String businessId) =>
      _db.collection('businesses').doc(businessId).collection('butcherReceipts');

  CollectionReference _butcheringRef(String businessId) =>
      _db.collection('businesses').doc(businessId).collection('butchering');

  DocumentReference _stockRef(String businessId, String productId, String storeId) =>
      _db.collection('businesses').doc(businessId).collection('products').doc(productId).collection('stockByStore').doc(storeId);

  CollectionReference _productsRef(String businessId) =>
      _db.collection('businesses').doc(businessId).collection('products');

  Future<({String receiptId, List<({String name, double weight, double percentage})> yields})> registerEntry({
    required String businessId,
    required String storeId,
    required String employeeId,
    required int chickenCount,
    required double avgWeight,
    required List<ButcherSection> sections,
    String? sourceStoreId,
  }) async {
    if (!await _connectivityService.hasConnection()) {
      throw Exception('Se requiere conexión para registrar entrada de pollos');
    }

    final totalWeight = chickenCount * avgWeight;
    final yields = sections.map((s) {
      final weight = totalWeight * (s.percentage / 100);
      return (name: s.name, weight: weight, percentage: s.percentage);
    }).toList();

    final docRef = _receiptsRef(businessId).doc();
    await docRef.set({
      'type': 'chicken',
      'storeId': storeId,
      'employeeId': employeeId,
      'chickenCount': chickenCount,
      'avgWeight': avgWeight,
      'totalWeight': totalWeight,
      'yields': yields
          .map((y) => {'name': y.name, 'weight': y.weight, 'percentage': y.percentage})
          .toList(),
      'sourceStoreId': sourceStoreId,
      'status': 'active',
      'consumedSections': [],
      'createdAt': FieldValue.serverTimestamp(),
    });

    await _stockService.addStockFromYields(
      businessId: businessId,
      storeId: storeId,
      yields: yields,
    );

    if (sourceStoreId != null) {
      await _stockService.subtractStockFromYields(
        businessId: businessId,
        storeId: sourceStoreId,
        yields: yields,
      );
    }

    return (receiptId: docRef.id, yields: yields);
  }

  Future<({String receiptId, List<({String name, double weight, double percentage})> yields})> registerPartsEntry({
    required String businessId,
    required String storeId,
    required String employeeId,
    required List<({String name, double weight})> parts,
    String? sourceStoreId,
  }) async {
    if (!await _connectivityService.hasConnection()) {
      throw Exception('Se requiere conexión para registrar entrada de piezas');
    }

    final totalWeight = parts.fold<double>(0, (sum, p) => sum + p.weight);
    final yields = parts.map((p) {
      final percentage = totalWeight > 0 ? (p.weight / totalWeight) * 100 : 0.0;
      return (name: p.name, weight: p.weight, percentage: percentage);
    }).toList();

    final docRef = _receiptsRef(businessId).doc();
    await docRef.set({
      'type': 'parts',
      'storeId': storeId,
      'employeeId': employeeId,
      'totalWeight': totalWeight,
      'yields': yields
          .map((y) => {'name': y.name, 'weight': y.weight, 'percentage': y.percentage})
          .toList(),
      'sourceStoreId': sourceStoreId,
      'status': 'active',
      'consumedSections': [],
      'createdAt': FieldValue.serverTimestamp(),
    });

    await _stockService.addStockFromYields(
      businessId: businessId,
      storeId: storeId,
      yields: yields,
    );

    if (sourceStoreId != null) {
      await _stockService.subtractStockFromYields(
        businessId: businessId,
        storeId: sourceStoreId,
        yields: yields,
      );
    }

    return (receiptId: docRef.id, yields: yields);
  }

  Future<String> registerButchering({
    required String businessId,
    required String storeId,
    required String employeeId,
    required String employeeName,
    required int chickenCount,
    required double exactWeightKg,
    required String wholeProductId,
    required List<ButcherSectionResult> sections,
  }) async {
    if (!await _connectivityService.hasConnection()) {
      throw Exception('Se requiere conexión para registrar destazado');
    }

    final totalActualKg = sections.fold<double>(0, (sum, s) => sum + s.actualKg);
    final totalExpectedKg = sections.fold<double>(0, (sum, s) => sum + s.expectedKg);
    final mermaKg = (totalExpectedKg - totalActualKg).clamp(0.0, double.infinity);
    final mermaPercent = totalExpectedKg > 0 ? (mermaKg / totalExpectedKg) * 100 : 0.0;

    final sectionProductIds = <String, String>{};
    final sectionNames = <String, String>{};
    for (final section in sections) {
      if (section.actualKg <= 0) continue;
      final products = await _productsRef(businessId)
          .where('name', isEqualTo: section.sectionName)
          .where('active', isEqualTo: true)
          .limit(1)
          .get();
      if (products.docs.isNotEmpty) {
        sectionProductIds[section.sectionName] = products.docs.first.id;
        sectionNames[section.sectionName] = products.docs.first.get('name') as String? ?? section.sectionName;
      } else {
        throw Exception(
          'Producto para sección "${section.sectionName}" no encontrado. '
          'Un administrador debe guardar la receta de destazado para crear los productos.',
        );
      }
    }

    final recordRef = _butcheringRef(businessId).doc();
    final movementsRef = _db.collection('businesses').doc(businessId).collection('inventoryMovements');
    final wholeStockRef = _stockRef(businessId, wholeProductId, storeId);

    final record = ButcherRecord(
      businessId: businessId,
      storeId: storeId,
      employeeId: employeeId,
      employeeName: employeeName,
      createdAt: DateTime.now(),
      chickenCount: chickenCount,
      exactWeightKg: exactWeightKg,
      totalExpectedKg: totalExpectedKg,
      totalActualKg: totalActualKg,
      sections: sections,
      mermaKg: mermaKg,
      mermaPercent: mermaPercent,
    );

    double? newWholeStock;
    int? newChickenCount;

    final existingStockDoc = await wholeStockRef.get();
    if (!existingStockDoc.exists) {
      await wholeStockRef.set({
        'businessId': businessId,
        'storeId': storeId,
        'productId': wholeProductId,
        'stockQuantity': 0,
        'chickenCount': 0,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }

    await _db.runTransaction((txn) async {
      final wholeStockDoc = await txn.get(wholeStockRef);
      final wholeData = wholeStockDoc.data() as Map<String, dynamic>?;
      final currentWholeStock = (wholeData?['stockQuantity'] as num? ?? 0).toDouble();
      final currentChickenCount = wholeData?['chickenCount'] as int? ?? 0;

      final sectionStocks = <String, ({String productId, String productName, double currentStock, double actualKg})>{};
      for (final section in sections) {
        if (section.actualKg <= 0) continue;
        final productId = sectionProductIds[section.sectionName];
        if (productId == null) continue;
        final sectionStockRef = _stockRef(businessId, productId, storeId);
        final sectionDoc = await txn.get(sectionStockRef);
        final sectionData = sectionDoc.data() as Map<String, dynamic>?;
        sectionStocks[section.sectionName] = (
          productId: productId,
          productName: sectionNames[section.sectionName] ?? section.sectionName,
          currentStock: (sectionData?['stockQuantity'] as num? ?? 0).toDouble(),
          actualKg: section.actualKg,
        );
      }

      if (currentWholeStock < exactWeightKg) {
        throw StateError(
          'Stock insuficiente de pollo entero: '
          'disponible ${currentWholeStock.toStringAsFixed(2)} kg, '
          'requerido ${exactWeightKg.toStringAsFixed(2)} kg',
        );
      }
      if (currentChickenCount < chickenCount) {
        throw StateError(
          'No hay suficientes pollos enteros: '
          'disponibles $currentChickenCount pollos, '
          'requeridos $chickenCount pollos',
        );
      }

      newWholeStock = currentWholeStock - exactWeightKg;
      newChickenCount = currentChickenCount - chickenCount;

      txn.set(recordRef, {
        ...record.toMap(),
        'createdAt': FieldValue.serverTimestamp(),
      });

      txn.set(wholeStockRef, {
        'businessId': businessId,
        'storeId': storeId,
        'productId': wholeProductId,
        'stockQuantity': newWholeStock,
        'chickenCount': newChickenCount,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      txn.set(movementsRef.doc(), {
        'businessId': businessId,
        'storeId': storeId,
        'productId': wholeProductId,
        'productName': 'Pollo Entero',
        'type': 'butchering',
        'previousQuantity': currentWholeStock,
        'newQuantity': newWholeStock,
        'difference': -exactWeightKg,
        'reason': 'Destazado $chickenCount pollos',
        'employeeId': employeeId,
        'createdAt': FieldValue.serverTimestamp(),
      });

      for (final entry in sectionStocks.entries) {
        final section = entry.value;
        final newSectionStock = section.currentStock + section.actualKg;

        txn.set(_stockRef(businessId, section.productId, storeId), {
          'businessId': businessId,
          'storeId': storeId,
          'productId': section.productId,
          'stockQuantity': newSectionStock,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        txn.set(movementsRef.doc(), {
          'businessId': businessId,
          'storeId': storeId,
          'productId': section.productId,
          'productName': section.productName,
          'type': 'butchering',
          'previousQuantity': section.currentStock,
          'newQuantity': newSectionStock,
          'difference': section.actualKg,
          'reason': 'Destazado - sección ${entry.key}',
          'employeeId': employeeId,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
    });

    if (newWholeStock != null && newChickenCount != null) {
      await _checkAndSaveAnomaly(
        businessId: businessId,
        storeId: storeId,
        employeeId: employeeId,
        employeeName: employeeName,
        remainingKg: newWholeStock!,
        remainingChickens: newChickenCount!,
        butcheredKg: exactWeightKg,
        butcheredChickens: chickenCount,
      );
    }

    return recordRef.id;
  }

  Stream<List<ButcherRecord>> watchButcheringRecords(
    String businessId, {
    String? storeId,
  }) {
    Query query = _butcheringRef(businessId).orderBy('createdAt', descending: true);
    if (storeId != null) {
      query = query.where('storeId', isEqualTo: storeId);
    }
    return query.snapshots().map((snapshot) => snapshot.docs
        .map((doc) => ButcherRecord.fromMap(doc.id, doc.data() as Map<String, dynamic>))
        .toList());
  }

  Future<List<ButcherRecord>> getButcheringRecords(
    String businessId, {
    String? storeId,
    DateTime? from,
    DateTime? to,
  }) async {
    Query query = _butcheringRef(businessId);
    if (storeId != null) query = query.where('storeId', isEqualTo: storeId);
    if (from != null) query = query.where('createdAt', isGreaterThanOrEqualTo: from);
    if (to != null) query = query.where('createdAt', isLessThanOrEqualTo: to);
    final snapshot = await query.orderBy('createdAt', descending: true).get();
    return snapshot.docs
        .map((doc) => ButcherRecord.fromMap(doc.id, doc.data() as Map<String, dynamic>))
        .toList();
  }

  Future<void> cancelEntry({
    required String businessId,
    required String receiptId,
    required String reason,
    required String cancelledBy,
  }) async {
    final doc = await _receiptsRef(businessId).doc(receiptId).get();
    if (!doc.exists) throw Exception('Recibo no encontrado');

    final data = doc.data() as Map<String, dynamic>;
    final storeId = data['storeId'] as String;
    final sourceStoreId = data['sourceStoreId'] as String?;
    final yields = (data['yields'] as List<dynamic>)
        .map((y) => (name: y['name'] as String, weight: y['weight'] as double, percentage: y['percentage'] as double))
        .toList();

    await _stockService.subtractStockFromYields(
      businessId: businessId,
      storeId: storeId,
      yields: yields,
    );

    if (sourceStoreId != null) {
      await _stockService.addStockFromYields(
        businessId: businessId,
        storeId: sourceStoreId,
        yields: yields,
      );
    }

    await _receiptsRef(businessId).doc(receiptId).update({
      'status': 'cancelled',
      'cancelReason': reason,
      'cancelledBy': cancelledBy,
      'cancelledAt': FieldValue.serverTimestamp(),
    });
  }

  Stream<List<Map<String, dynamic>>> watchReceipts(
    String businessId, {
    String? storeId,
  }) {
    Query query = _receiptsRef(businessId).orderBy('createdAt', descending: true);
    if (storeId != null) {
      query = query.where('storeId', isEqualTo: storeId);
    }
    return query.snapshots().map((snapshot) => snapshot.docs
        .map((doc) => {'id': doc.id, ...doc.data() as Map<String, dynamic>})
        .toList());
  }

  Future<void> cancelButchering({
    required String businessId,
    required String recordId,
    required String reason,
    required String cancelledBy,
  }) async {
    final doc = await _butcheringRef(businessId).doc(recordId).get();
    if (!doc.exists) throw Exception('Registro de destazado no encontrado');

    final record = ButcherRecord.fromMap(doc.id, doc.data() as Map<String, dynamic>);
    final batch = _db.batch();

    batch.update(_butcheringRef(businessId).doc(recordId), {
      'status': 'cancelled',
      'cancelReason': reason,
      'cancelledBy': cancelledBy,
      'cancelledAt': FieldValue.serverTimestamp(),
    });

    final wholeProductId = await _getWholeProductId(businessId);
    if (wholeProductId != null) {
      final wholeStockRef = _stockRef(businessId, wholeProductId, record.storeId);
      batch.set(wholeStockRef, {
        'businessId': businessId,
        'storeId': record.storeId,
        'productId': wholeProductId,
        'stockQuantity': FieldValue.increment(record.exactWeightKg),
        'chickenCount': FieldValue.increment(record.chickenCount),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }

    for (final section in record.sections) {
      if (section.actualKg <= 0) continue;
      final products = await _productsRef(businessId)
          .where('name', isEqualTo: section.sectionName)
          .where('active', isEqualTo: true)
          .limit(1)
          .get();
      if (products.docs.isEmpty) continue;
      final stockRef = _stockRef(businessId, products.docs.first.id, record.storeId);
      batch.set(stockRef, {
        'businessId': businessId,
        'storeId': record.storeId,
        'productId': products.docs.first.id,
        'stockQuantity': FieldValue.increment(-section.actualKg),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }

    await batch.commit();
  }

  Future<String?> _getWholeProductId(String businessId) async {
    final doc = await _db
        .collection('businesses')
        .doc(businessId)
        .collection('config')
        .doc('poultry')
        .get();
    if (!doc.exists) return null;
    return doc.data()?['wholeProductId'] as String?;
  }

  Future<void> _checkAndSaveAnomaly({
    required String businessId,
    required String storeId,
    required String employeeId,
    required String employeeName,
    required double remainingKg,
    required int remainingChickens,
    required double butcheredKg,
    required int butcheredChickens,
  }) async {
    String? type;
    if (remainingChickens == 0 && remainingKg > 0.5) {
      type = 'excess_kg';
    } else if (remainingKg <= 0.01 && remainingChickens > 0) {
      type = 'excess_chickens';
    }

    if (type == null) return;

    final anomaly = ButcherAnomaly(
      businessId: businessId,
      storeId: storeId,
      employeeId: employeeId,
      employeeName: employeeName,
      createdAt: DateTime.now(),
      type: type,
      remainingKg: remainingKg,
      remainingChickens: remainingChickens,
      butcheredKg: butcheredKg,
      butcheredChickens: butcheredChickens,
    );

    await _db
        .collection('businesses')
        .doc(businessId)
        .collection('butcherAnomalies')
        .doc()
        .set(anomaly.toMap());
  }
}
