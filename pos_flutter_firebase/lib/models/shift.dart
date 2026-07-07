import 'package:cloud_firestore/cloud_firestore.dart';

class Shift {
  const Shift({
    required this.id,
    required this.businessId,
    required this.storeId,
    required this.employeeId,
    required this.status,
    required this.openingCash,
    required this.closingCash,
    required this.cashSales,
    required this.cardSales,
    required this.totalSales,
    required this.cashRefunds,
    required this.depositsTotal,
    required this.payoutsTotal,
    required this.cashMovements,
    required this.expectedCash,
    required this.cashDifference,
    required this.openedAt,
    required this.closedAt,
  });

  final String id;
  final String businessId;
  final String storeId;
  final String employeeId;
  final String status;
  final double openingCash;
  final double? closingCash;
  final double cashSales;
  final double cardSales;
  final double totalSales;
  final double cashRefunds;
  final double depositsTotal;
  final double payoutsTotal;
  final List<Map<String, dynamic>> cashMovements;
  final double expectedCash;
  final double cashDifference;
  final DateTime? openedAt;
  final DateTime? closedAt;

  bool get isOpen => status == 'open';

  factory Shift.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};

    return Shift(
      id: doc.id,
      businessId: data['businessId'] as String? ?? '',
      storeId: data['storeId'] as String? ?? '',
      employeeId: data['employeeId'] as String? ?? '',
      status: data['status'] as String? ?? 'open',
      openingCash: (data['openingCash'] as num? ?? 0).toDouble(),
      closingCash: (data['closingCash'] as num?)?.toDouble(),
      cashSales: (data['cashSales'] as num? ?? 0).toDouble(),
      cardSales: (data['cardSales'] as num? ?? 0).toDouble(),
      totalSales: (data['totalSales'] as num? ?? 0).toDouble(),
      cashRefunds: (data['cashRefunds'] as num? ?? 0).toDouble(),
      depositsTotal: (data['depositsTotal'] as num? ?? 0).toDouble(),
      payoutsTotal: (data['payoutsTotal'] as num? ?? 0).toDouble(),
      cashMovements: List<Map<String, dynamic>>.from(
        (data['cashMovements'] as List? ?? const []).map(
          (item) => Map<String, dynamic>.from(item as Map? ?? const {}),
        ),
      ),
      expectedCash: (data['expectedCash'] as num? ?? 0).toDouble(),
      cashDifference: (data['cashDifference'] as num? ?? 0).toDouble(),
      openedAt: (data['openedAt'] as Timestamp?)?.toDate(),
      closedAt: (data['closedAt'] as Timestamp?)?.toDate(),
    );
  }
}
