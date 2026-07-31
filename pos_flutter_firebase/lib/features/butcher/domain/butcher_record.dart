class ButcherSectionResult {
  final String sectionName;
  final double percentage;
  final double expectedKg;
  final double actualKg;

  const ButcherSectionResult({
    required this.sectionName,
    required this.percentage,
    required this.expectedKg,
    required this.actualKg,
  });

  Map<String, dynamic> toMap() => {
    'sectionName': sectionName,
    'percentage': percentage,
    'expectedKg': expectedKg,
    'actualKg': actualKg,
  };

  factory ButcherSectionResult.fromMap(Map<String, dynamic> map) =>
      ButcherSectionResult(
        sectionName: map['sectionName'] as String? ?? '',
        percentage: (map['percentage'] as num?)?.toDouble() ?? 0,
        expectedKg: (map['expectedKg'] as num?)?.toDouble() ?? 0,
        actualKg: (map['actualKg'] as num?)?.toDouble() ?? 0,
      );
}

class ButcherRecord {
  final String? id;
  final String businessId;
  final String storeId;
  final String employeeId;
  final String employeeName;
  final DateTime createdAt;
  final int chickenCount;
  final double exactWeightKg;
  final double totalExpectedKg;
  final double totalActualKg;
  final List<ButcherSectionResult> sections;
  final double mermaKg;
  final double mermaPercent;
  final String status;

  const ButcherRecord({
    this.id,
    required this.businessId,
    required this.storeId,
    required this.employeeId,
    required this.employeeName,
    required this.createdAt,
    required this.chickenCount,
    required this.exactWeightKg,
    required this.totalExpectedKg,
    required this.totalActualKg,
    required this.sections,
    required this.mermaKg,
    required this.mermaPercent,
    this.status = 'active',
  });

  Map<String, dynamic> toMap() => {
    'businessId': businessId,
    'storeId': storeId,
    'employeeId': employeeId,
    'employeeName': employeeName,
    'createdAt': createdAt,
    'chickenCount': chickenCount,
    'exactWeightKg': exactWeightKg,
    'totalExpectedKg': totalExpectedKg,
    'totalActualKg': totalActualKg,
    'sections': sections.map((e) => e.toMap()).toList(),
    'mermaKg': mermaKg,
    'mermaPercent': mermaPercent,
    'status': status,
  };

  factory ButcherRecord.fromMap(String id, Map<String, dynamic> map) =>
      ButcherRecord(
        id: id,
        businessId: map['businessId'] as String? ?? '',
        storeId: map['storeId'] as String? ?? '',
        employeeId: map['employeeId'] as String? ?? '',
        employeeName: map['employeeName'] as String? ?? '',
        createdAt: (map['createdAt'] as dynamic)?.toDate() ?? DateTime.now(),
        chickenCount: (map['chickenCount'] as num?)?.toInt() ?? 0,
        exactWeightKg: (map['exactWeightKg'] as num?)?.toDouble() ?? 0,
        totalExpectedKg: (map['totalExpectedKg'] as num?)?.toDouble() ?? 0,
        totalActualKg: (map['totalActualKg'] as num?)?.toDouble() ?? 0,
        sections: (map['sections'] as List<dynamic>?)
                ?.map((e) =>
                    ButcherSectionResult.fromMap(e as Map<String, dynamic>))
                .toList() ??
            [],
        mermaKg: (map['mermaKg'] as num?)?.toDouble() ?? 0,
        mermaPercent: (map['mermaPercent'] as num?)?.toDouble() ?? 0,
        status: map['status'] as String? ?? 'active',
      );
}
