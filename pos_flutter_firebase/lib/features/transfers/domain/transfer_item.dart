class TransferItem {
  final String productId;
  final String productName;
  final double sentQuantity;
  final double? confirmedQuantity;

  const TransferItem({
    required this.productId,
    required this.productName,
    required this.sentQuantity,
    this.confirmedQuantity,
  });

  Map<String, dynamic> toMap() => {
    'productId': productId,
    'productName': productName,
    'sentQuantity': sentQuantity,
    if (confirmedQuantity != null) 'confirmedQuantity': confirmedQuantity,
  };

  factory TransferItem.fromMap(Map<String, dynamic> map) => TransferItem(
    productId: map['productId'] as String? ?? '',
    productName: map['productName'] as String? ?? '',
    sentQuantity: (map['sentQuantity'] as num?)?.toDouble() ?? 0,
    confirmedQuantity: (map['confirmedQuantity'] as num?)?.toDouble(),
  );
}
