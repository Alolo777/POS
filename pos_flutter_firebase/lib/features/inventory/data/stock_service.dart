import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../shared/models/product_stock.dart';
import '../../../core/offline/local_database.dart';
import '../domain/stock_repository.dart';

class StockService implements StockRepository {
  StockService({FirebaseFirestore? firestore}) : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  Stream<Map<String, ProductStock>> watchStockByStore({
    required String businessId,
    required String storeId,
  }) {
    final controller = StreamController<Map<String, ProductStock>>.broadcast();

    final cached = _getCachedStockForStore(businessId, storeId);
    if (cached != null && cached.isNotEmpty) {
      controller.add(cached);
    }

    final sub = _db
        .collectionGroup('stockByStore')
        .where('businessId', isEqualTo: businessId)
        .where('storeId', isEqualTo: storeId)
        .snapshots()
        .listen(
      (snapshot) async {
        final result = <String, ProductStock>{};
        final stockList = <ProductStock>[];
        for (final doc in snapshot.docs) {
          final stock = ProductStock.fromDoc(doc);
          result[stock.productId] = stock;
          stockList.add(stock);
        }
        await LocalDatabase.cacheProductStock(businessId, stockList);
        controller.add(result);
      },
    );

    controller.onCancel = () => sub.cancel();
    return controller.stream;
  }

  Map<String, ProductStock>? _getCachedStockForStore(String businessId, String storeId) {
    final data = LocalDatabase.getCachedProductStock(businessId);
    if (data == null) return null;
    final result = <String, ProductStock>{};
    for (final stock in data) {
      if (stock.storeId != storeId) continue;
      result[stock.productId] = stock;
    }
    return result.isEmpty ? null : result;
  }

  Map<String, ProductStock>? getCachedStock(String businessId) {
    final data = LocalDatabase.getCachedProductStock(businessId);
    if (data == null) return null;
    final result = <String, ProductStock>{};
    for (final stock in data) {
      result[stock.productId] = stock;
    }
    return result;
  }

  Future<void> applyLocalStockDelta({
    required String businessId,
    required String productId,
    required double delta,
  }) async {
    final data = LocalDatabase.getCachedProductStock(businessId);
    if (data == null) return;
    final updatedList = <ProductStock>[];
    for (final stock in data) {
      if (stock.productId == productId) {
        updatedList.add(ProductStock(
          productId: stock.productId,
          storeId: stock.storeId,
          stockQuantity: (stock.stockQuantity + delta).clamp(0.0, double.infinity),
          lowStockAlertQuantity: stock.lowStockAlertQuantity,
        ));
      } else {
        updatedList.add(stock);
      }
    }
    await LocalDatabase.cacheProductStock(businessId, updatedList);
  }
}
