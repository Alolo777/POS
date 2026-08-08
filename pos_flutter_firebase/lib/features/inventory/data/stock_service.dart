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

    final subscriptions = <StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>>{};

    void disposeStockSubscriptions() {
      for (final sub in subscriptions) {
        sub.cancel();
      }
      subscriptions.clear();
    }

    // Escucha el stock de cada producto con lecturas por-ruta (path-scoped),
    // que las reglas de Firestore permiten. No usa collectionGroup.
    void subscribeToProducts(QuerySnapshot<Map<String, dynamic>> products) {
      disposeStockSubscriptions();
      final result = <String, ProductStock>{};
      for (final productDoc in products.docs) {
        final productId = productDoc.id;
        final sub = _db
            .collection('businesses')
            .doc(businessId)
            .collection('products')
            .doc(productId)
            .collection('stockByStore')
            .doc(storeId)
            .snapshots()
            .listen((stockDoc) {
          if (stockDoc.exists) {
            final stock = ProductStock.fromDoc(stockDoc);
            result[stock.productId] = stock;
          } else {
            result.remove(productId);
          }
          final emitted = Map<String, ProductStock>.from(result);
          controller.add(emitted);
          LocalDatabase.cacheProductStock(businessId, _mergeStockIntoCache(businessId, storeId, emitted));
        });
        subscriptions.add(sub);
      }
    }

    final productsSub = _db
        .collection('businesses')
        .doc(businessId)
        .collection('products')
        .snapshots()
        .listen(subscribeToProducts);

    controller.onCancel = () {
      productsSub.cancel();
      disposeStockSubscriptions();
    };
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

  List<ProductStock> _mergeStockIntoCache(
    String businessId,
    String storeId,
    Map<String, ProductStock> storeStock,
  ) {
    final data = LocalDatabase.getCachedProductStock(businessId);
    return <ProductStock>[
      if (data != null) ...data.where((s) => s.storeId != storeId),
      ...storeStock.values,
    ];
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
