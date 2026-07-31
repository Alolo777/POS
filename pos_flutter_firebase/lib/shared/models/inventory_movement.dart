class InventoryMovement {
  const InventoryMovement({
    required this.id,
    required this.businessId,
    required this.storeId,
    required this.productId,
    required this.productName,
    required this.type,
    required this.previousQuantity,
    required this.newQuantity,
    required this.reason,
    required this.employeeId,
    required this.createdAt,
  });

  final String id;
  final String businessId;
  final String storeId;
  final String productId;
  final String productName;
  final String type;
  final double previousQuantity;
  final double newQuantity;
  final String reason;
  final String employeeId;
  final DateTime? createdAt;

  double get difference => newQuantity - previousQuantity;

  factory InventoryMovement.fromMap(Map<String, dynamic> map, String id) {
    return InventoryMovement(
      id: id,
      businessId: map['businessId'] as String? ?? '',
      storeId: map['storeId'] as String? ?? '',
      productId: map['productId'] as String? ?? '',
      productName: map['productName'] as String? ?? '',
      type: map['type'] as String? ?? '',
      previousQuantity: (map['previousQuantity'] as num? ?? 0).toDouble(),
      newQuantity: (map['newQuantity'] as num? ?? 0).toDouble(),
      reason: map['reason'] as String? ?? '',
      employeeId: map['employeeId'] as String? ?? '',
      createdAt: (map['createdAt'] as dynamic)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() => {
    'businessId': businessId,
    'storeId': storeId,
    'productId': productId,
    'productName': productName,
    'type': type,
    'previousQuantity': previousQuantity,
    'newQuantity': newQuantity,
    'reason': reason,
    'employeeId': employeeId,
  };

  String get typeLabel {
    switch (type) {
      case 'sale':
        return 'Venta';
      case 'refund':
        return 'Devolucion';
      case 'adjustment':
        return 'Ajuste';
      case 'butchering':
        return 'Destazado';
      case 'receiving':
        return 'Recepción';
      default:
        return type;
    }
  }
}