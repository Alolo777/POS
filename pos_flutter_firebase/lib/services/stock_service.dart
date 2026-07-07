import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/product_stock.dart';

class StockService {
  final _db = FirebaseFirestore.instance;

  Stream<Map<String, ProductStock>> watchStockByStore({
    required String businessId,
    required String storeId,
  }) {
    return _db.collection('businesses').doc(businessId).collection('products').snapshots().asyncMap(
      (productsSnapshot) async {
        final result = <String, ProductStock>{};
        for (final productDoc in productsSnapshot.docs) {
          final stockDoc = await productDoc.reference.collection('stockByStore').doc(storeId).get();
          if (stockDoc.exists) {
            result[productDoc.id] = ProductStock.fromDoc(stockDoc);
          }
        }
        return result;
      },
    );
  }

}
