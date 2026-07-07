import 'package:cloud_firestore/cloud_firestore.dart';

class OpenTicket {
  const OpenTicket({
    required this.id,
    required this.businessId,
    required this.storeId,
    required this.employeeId,
    required this.name,
    required this.items,
    required this.total,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String businessId;
  final String storeId;
  final String employeeId;
  final String name;
  final List<Map<String, dynamic>> items;
  final double total;
  final String status;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory OpenTicket.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};

    return OpenTicket(
      id: doc.id,
      businessId: data['businessId'] as String? ?? '',
      storeId: data['storeId'] as String? ?? '',
      employeeId: data['employeeId'] as String? ?? '',
      name: data['name'] as String? ?? 'Ticket abierto',
      items: List<Map<String, dynamic>>.from(
        (data['items'] as List? ?? const []).map(
          (item) => Map<String, dynamic>.from(item as Map? ?? const {}),
        ),
      ),
      total: (data['total'] as num? ?? 0).toDouble(),
      status: data['status'] as String? ?? 'open',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }
}
