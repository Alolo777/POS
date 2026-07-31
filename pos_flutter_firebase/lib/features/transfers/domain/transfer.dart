import 'transfer_item.dart';

class Transfer {
  final String? id;
  final String businessId;
  final String fromStoreId;
  final String toStoreId;
  final String fromEmployeeId;
  final String? toEmployeeId;
  final String status;
  final List<TransferItem> items;
  final DateTime createdAt;
  final DateTime? confirmedAt;
  final String? notes;

  const Transfer({
    this.id,
    required this.businessId,
    required this.fromStoreId,
    required this.toStoreId,
    required this.fromEmployeeId,
    this.toEmployeeId,
    this.status = 'sent',
    required this.items,
    required this.createdAt,
    this.confirmedAt,
    this.notes,
  });

  bool get isSent => status == 'sent';
  bool get isConfirmed => status == 'confirmed';
  bool get isCancelled => status == 'cancelled';

  Map<String, dynamic> toMap() => {
    'businessId': businessId,
    'fromStoreId': fromStoreId,
    'toStoreId': toStoreId,
    'fromEmployeeId': fromEmployeeId,
    if (toEmployeeId != null) 'toEmployeeId': toEmployeeId,
    'status': status,
    'items': items.map((e) => e.toMap()).toList(),
    'createdAt': createdAt,
    if (confirmedAt != null) 'confirmedAt': confirmedAt,
    if (notes != null) 'notes': notes,
  };

  factory Transfer.fromMap(String id, Map<String, dynamic> map) => Transfer(
    id: id,
    businessId: map['businessId'] as String? ?? '',
    fromStoreId: map['fromStoreId'] as String? ?? '',
    toStoreId: map['toStoreId'] as String? ?? '',
    fromEmployeeId: map['fromEmployeeId'] as String? ?? '',
    toEmployeeId: map['toEmployeeId'] as String?,
    status: map['status'] as String? ?? 'sent',
    items: (map['items'] as List<dynamic>?)
            ?.map((e) => TransferItem.fromMap(e as Map<String, dynamic>))
            .toList() ?? [],
    createdAt: (map['createdAt'] as dynamic)?.toDate() ?? DateTime.now(),
    confirmedAt: (map['confirmedAt'] as dynamic)?.toDate(),
    notes: map['notes'] as String?,
  );
}
