import 'package:cloud_firestore/cloud_firestore.dart';

class Sale {
  const Sale({
    required this.id,
    required this.businessId,
    required this.folio,
    required this.storeId,
    required this.employeeId,
    required this.shiftId,
    required this.items,
    required this.subtotal,
    required this.discountTotal,
    this.discountName = '',
    this.discountId = '',
    this.discountType = '',
    this.discountValue = 0,
    required this.taxTotal,
    required this.total,
    required this.paymentMethod,
    required this.cashReceived,
    required this.changeDue,
    required this.status,
    required this.originalSaleId,
    required this.returnedItems,
    required this.createdAt,
    required this.cancelledAt,
    required this.cancelReason,
    required this.inventoryReturned,
    required this.clientCreatedAt,
    required this.type,
    required this.refund,
    required this.refundIds,
  });

  final String id;
  final String businessId;
  final String folio;
  final String storeId;
  final String employeeId;
  final String? shiftId;
  final List<Map<String, dynamic>> items;
  final double subtotal;
  final double discountTotal;
  final String discountName;
  final String discountId;
  final String discountType;
  final double discountValue;
  final double taxTotal;
  final double total;
  final String paymentMethod;
  final double? cashReceived;
  final double? changeDue;
  final String status;
  final String? originalSaleId;
  final List<Map<String, dynamic>> returnedItems;
  final DateTime? createdAt;
  final DateTime? cancelledAt;
  final String? cancelReason;
  final bool inventoryReturned;
  final DateTime? clientCreatedAt;
  final String type;
  final bool refund;
  final List<String> refundIds;

  bool get isCancelled => status == 'cancelled';
  bool get isPartiallyCancelled => status == 'partially_cancelled';
  bool get isRefund => status == 'refund' || type == 'refund' || refund;

  factory Sale.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};

    return Sale(
      id: doc.id,
      businessId: data['businessId'] as String? ?? '',
      folio: data['folio'] as String? ?? doc.id.substring(0, doc.id.length.clamp(0, 6)).toUpperCase(),
      storeId: data['storeId'] as String? ?? '',
      employeeId: data['employeeId'] as String? ?? '',
      shiftId: data['shiftId'] as String?,
      items: List<Map<String, dynamic>>.from(
        (data['items'] as List? ?? const []).map(
          (item) => Map<String, dynamic>.from(item as Map? ?? const {}),
        ),
      ),
      subtotal: (data['subtotal'] as num? ?? 0).toDouble(),
      discountTotal: (data['discountTotal'] as num? ?? 0).toDouble(),
      discountName: data['discountName'] as String? ?? '',
      discountId: data['discountId'] as String? ?? '',
      discountType: data['discountType'] as String? ?? '',
      discountValue: (data['discountValue'] as num? ?? 0).toDouble(),
      taxTotal: (data['taxTotal'] as num? ?? 0).toDouble(),
      total: (data['total'] as num? ?? 0).toDouble(),
      paymentMethod: data['paymentMethod'] as String? ?? 'cash',
      cashReceived: (data['cashReceived'] as num?)?.toDouble(),
      changeDue: (data['changeDue'] as num?)?.toDouble(),
      status: data['status'] as String? ?? 'completed',
      originalSaleId: data['originalSaleId'] as String?,
      returnedItems: List<Map<String, dynamic>>.from(
        (data['returnedItems'] as List? ?? const []).map(
          (item) => Map<String, dynamic>.from(item as Map? ?? const {}),
        ),
      ),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      cancelledAt: (data['cancelledAt'] as Timestamp?)?.toDate(),
      cancelReason: data['cancelReason'] as String?,
      inventoryReturned: data['inventoryReturned'] as bool? ?? false,
      clientCreatedAt: (data['clientCreatedAt'] as Timestamp?)?.toDate(),
      type: data['type'] as String? ?? data['folioType'] as String? ?? 'sale',
      refund: data['refund'] as bool? ?? false,
      refundIds: List<String>.from(data['refundIds'] as List? ?? const []),
    );
  }
}