import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../shared/models/sale.dart';
import '../../../core/offline/local_database.dart';
import '../domain/sale_repository.dart';

class SaleQueryService {
  SaleQueryService({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  CollectionReference _salesRef(String businessId) =>
      _db.collection('businesses').doc(businessId).collection('sales');

  Stream<List<Sale>> watchSales({
    required String businessId,
    required String storeId,
  }) {
    return _salesRef(businessId)
        .where('storeId', isEqualTo: storeId)
        .orderBy('clientCreatedAt', descending: true)
        .snapshots()
        .map((snapshot) {
      final sales = snapshot.docs
          .map((doc) => Sale.fromDoc(doc as DocumentSnapshot<Map<String, dynamic>>))
          .toList();
      return sales;
    });
  }

  Stream<List<Sale>> watchSalesByShift({
    required String businessId,
    required String storeId,
    required String shiftId,
  }) {
    return _salesRef(businessId)
        .where('storeId', isEqualTo: storeId)
        .where('shiftId', isEqualTo: shiftId)
        .orderBy('clientCreatedAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => Sale.fromDoc(doc as DocumentSnapshot<Map<String, dynamic>>))
          .toList();
    });
  }

  Stream<List<Sale>> watchBusinessSales({
    required String businessId,
  }) {
    return _salesRef(businessId)
        .orderBy('clientCreatedAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => Sale.fromDoc(doc as DocumentSnapshot<Map<String, dynamic>>))
          .toList();
    });
  }

  List<Sale>? getCachedSales(String businessId) {
    return LocalDatabase.getCachedSales(businessId);
  }

  Future<SalesPage> fetchSalesPage({
    required String businessId,
    required String storeId,
    int limit = 30,
    DocumentSnapshot<Map<String, dynamic>>? startAfter,
  }) async {
    Query query = _salesRef(businessId)
        .where('storeId', isEqualTo: storeId)
        .orderBy('clientCreatedAt', descending: true)
        .limit(limit);

    if (startAfter != null) {
      query = query.startAfterDocument(startAfter);
    }

    final snapshot = await query.get();
    final sales = snapshot.docs
        .map((doc) => Sale.fromDoc(doc as DocumentSnapshot<Map<String, dynamic>>))
        .toList();

    final lastDoc = snapshot.docs.isNotEmpty
        ? snapshot.docs.last as DocumentSnapshot<Map<String, dynamic>>
        : null;
    final hasMore = snapshot.docs.length == limit;

    return SalesPage(
      sales: sales,
      lastDocument: lastDoc,
      hasMore: hasMore,
    );
  }
}
