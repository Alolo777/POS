import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../shared/models/sale.dart';

class SalesPage {
  final List<Sale> sales;
  final DocumentSnapshot<Map<String, dynamic>>? lastDocument;
  final bool hasMore;

  const SalesPage({
    required this.sales,
    this.lastDocument,
    required this.hasMore,
  });
}

abstract class SaleQueryRepository {
  Stream<List<Sale>> watchSales({
    required String businessId,
    required String storeId,
  });

  Stream<List<Sale>> watchSalesByShift({
    required String businessId,
    required String storeId,
    required String shiftId,
  });

  Stream<List<Sale>> watchBusinessSales({
    required String businessId,
  });

  List<Sale>? getCachedSales(String businessId);

  Future<SalesPage> fetchSalesPage({
    required String businessId,
    required String storeId,
    int limit = 30,
    DocumentSnapshot<Map<String, dynamic>>? startAfter,
  });
}
