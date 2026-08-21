import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../shared/models/sale.dart';
import '../../../shared/models/cart_item.dart';
import '../../../core/network/connectivity_service.dart';
import '../../inventory/data/stock_service.dart';
import '../domain/sale_repository.dart';
import 'sale_creator_service.dart';
import 'sale_refund_service.dart';
import 'sale_query_service.dart';

export '../domain/sale_repository.dart' show SalesPage;

class SaleService implements SaleRepository {
  SaleService({
    required ConnectivityService connectivityService,
    required StockService stockService,
    FirebaseFirestore? firestore,
  })  : _creatorService = SaleCreatorService(
          connectivityService: connectivityService,
          stockService: stockService,
          firestore: firestore,
        ),
        _refundService = SaleRefundService(
          connectivityService: connectivityService,
          stockService: stockService,
          firestore: firestore,
        ),
        _queryService = SaleQueryService(firestore: firestore);

  final SaleCreatorService _creatorService;
  final SaleRefundService _refundService;
  final SaleQueryService _queryService;

  // Create
  @override
  Future<String> createSale({
    required String businessId,
    required String storeId,
    required String employeeId,
    required String shiftId,
    required List<CartItem> items,
    required double subtotal,
    required double discountTotal,
    String discountName = '',
    String discountId = '',
    String discountType = '',
    double discountValue = 0,
    required double total,
    required String paymentMethod,
    double? cashReceived,
    double? changeDue,
    String? createdByUid,
  }) =>
      _creatorService.createSale(
        businessId: businessId,
        storeId: storeId,
        employeeId: employeeId,
        shiftId: shiftId,
        items: items,
        subtotal: subtotal,
        discountTotal: discountTotal,
        discountName: discountName,
        discountId: discountId,
        discountType: discountType,
        discountValue: discountValue,
        total: total,
        paymentMethod: paymentMethod,
        cashReceived: cashReceived,
        changeDue: changeDue,
        createdByUid: createdByUid,
      );

  // Refund
  @override
  Future<String> cancelSale({
    required String businessId,
    required Sale sale,
    required List<Map<String, dynamic>> returnItems,
    required bool returnInventory,
    required String reason,
    String? refundShiftId,
    String? refundEmployeeId,
  }) =>
      _refundService.cancelSale(
        businessId: businessId,
        sale: sale,
        returnItems: returnItems,
        returnInventory: returnInventory,
        reason: reason,
        refundShiftId: refundShiftId,
        refundEmployeeId: refundEmployeeId,
      );

  @override
  Future<bool> refundExists({
    required String businessId,
    required String refundId,
  }) =>
      _refundService.refundExists(
        businessId: businessId,
        refundId: refundId,
      );

  // Query
  @override
  Stream<List<Sale>> watchSales({
    required String businessId,
    required String storeId,
  }) =>
      _queryService.watchSales(
        businessId: businessId,
        storeId: storeId,
      );

  @override
  Stream<List<Sale>> watchSalesByShift({
    required String businessId,
    required String storeId,
    required String shiftId,
  }) =>
      _queryService.watchSalesByShift(
        businessId: businessId,
        storeId: storeId,
        shiftId: shiftId,
      );

  @override
  Stream<List<Sale>> watchBusinessSales({
    required String businessId,
  }) =>
      _queryService.watchBusinessSales(businessId: businessId);

  @override
  List<Sale>? getCachedSales(String businessId) =>
      _queryService.getCachedSales(businessId);

  @override
  Future<SalesPage> fetchSalesPage({
    required String businessId,
    required String storeId,
    int limit = 30,
    DocumentSnapshot<Map<String, dynamic>>? startAfter,
  }) =>
      _queryService.fetchSalesPage(
        businessId: businessId,
        storeId: storeId,
        limit: limit,
        startAfter: startAfter,
      );
}
