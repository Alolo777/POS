class ChickenReceiving {
  final String? id;
  final String businessId;
  final String storeId;
  final String employeeId;
  final String employeeName;
  final DateTime createdAt;
  final int totalChickens;
  final double totalWeightKg;
  final double avgWeightKg;
  final String status;

  const ChickenReceiving({
    this.id,
    required this.businessId,
    required this.storeId,
    required this.employeeId,
    required this.employeeName,
    required this.createdAt,
    required this.totalChickens,
    required this.totalWeightKg,
    required this.avgWeightKg,
    this.status = 'completed',
  });

  Map<String, dynamic> toMap() => {
    'businessId': businessId,
    'storeId': storeId,
    'employeeId': employeeId,
    'employeeName': employeeName,
    'createdAt': createdAt,
    'totalChickens': totalChickens,
    'totalWeightKg': totalWeightKg,
    'avgWeightKg': avgWeightKg,
    'status': status,
  };

  factory ChickenReceiving.fromMap(String id, Map<String, dynamic> map) =>
      ChickenReceiving(
        id: id,
        businessId: map['businessId'] as String? ?? '',
        storeId: map['storeId'] as String? ?? '',
        employeeId: map['employeeId'] as String? ?? '',
        employeeName: map['employeeName'] as String? ?? '',
        createdAt: (map['createdAt'] as dynamic)?.toDate() ?? DateTime.now(),
        totalChickens: (map['totalChickens'] as num?)?.toInt() ?? 0,
        totalWeightKg: (map['totalWeightKg'] as num?)?.toDouble() ?? 0,
        avgWeightKg: (map['avgWeightKg'] as num?)?.toDouble() ?? 0,
        status: map['status'] as String? ?? 'completed',
      );
}
