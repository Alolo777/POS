class ButcherAnomaly {
  final String? id;
  final String businessId;
  final String storeId;
  final String employeeId;
  final String employeeName;
  final DateTime createdAt;
  final String type;
  final double remainingKg;
  final int remainingChickens;
  final double butcheredKg;
  final int butcheredChickens;

  const ButcherAnomaly({
    this.id,
    required this.businessId,
    required this.storeId,
    required this.employeeId,
    required this.employeeName,
    required this.createdAt,
    required this.type,
    required this.remainingKg,
    required this.remainingChickens,
    required this.butcheredKg,
    required this.butcheredChickens,
  });

  Map<String, dynamic> toMap() => {
    'businessId': businessId,
    'storeId': storeId,
    'employeeId': employeeId,
    'employeeName': employeeName,
    'createdAt': createdAt,
    'type': type,
    'remainingKg': remainingKg,
    'remainingChickens': remainingChickens,
    'butcheredKg': butcheredKg,
    'butcheredChickens': butcheredChickens,
  };

  factory ButcherAnomaly.fromMap(String id, Map<String, dynamic> map) => ButcherAnomaly(
    id: id,
    businessId: map['businessId'] as String? ?? '',
    storeId: map['storeId'] as String? ?? '',
    employeeId: map['employeeId'] as String? ?? '',
    employeeName: map['employeeName'] as String? ?? '',
    createdAt: (map['createdAt'] as dynamic)?.toDate() ?? DateTime.now(),
    type: map['type'] as String? ?? '',
    remainingKg: (map['remainingKg'] as num? ?? 0).toDouble(),
    remainingChickens: (map['remainingChickens'] as num? ?? 0).toInt(),
    butcheredKg: (map['butcheredKg'] as num? ?? 0).toDouble(),
    butcheredChickens: (map['butcheredChickens'] as num? ?? 0).toInt(),
  );

  String get typeLabel {
    if (type == 'excess_kg') return 'Sobran kg sin pollos';
    if (type == 'excess_chickens') return 'Sobran pollos sin kg';
    return type;
  }

  String get message {
    if (type == 'excess_kg') {
      return 'Quedan ${remainingKg.toStringAsFixed(2)} kg pero 0 pollos. '
          'Los pollos destazados pesaron menos de lo esperado.';
    }
    if (type == 'excess_chickens') {
      return 'Quedan $remainingChickens pollos pero 0 kg. '
          'Los pollos destazados pesaron más de lo esperado.';
    }
    return '';
  }
}
