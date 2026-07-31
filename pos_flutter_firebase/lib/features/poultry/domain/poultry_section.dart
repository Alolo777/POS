class PoultrySection {
  final String id;
  final String name;
  final double defaultPercent;
  final String? productId;
  final int sortOrder;

  const PoultrySection({
    required this.id,
    required this.name,
    required this.defaultPercent,
    this.productId,
    this.sortOrder = 0,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'defaultPercent': defaultPercent,
    if (productId != null) 'productId': productId,
    'sortOrder': sortOrder,
  };

  factory PoultrySection.fromMap(Map<String, dynamic> map) => PoultrySection(
    id: map['id'] as String? ?? '',
    name: map['name'] as String? ?? '',
    defaultPercent: (map['defaultPercent'] as num?)?.toDouble() ?? 0,
    productId: map['productId'] as String?,
    sortOrder: (map['sortOrder'] as num?)?.toInt() ?? 0,
  );

  PoultrySection copyWith({
    String? id,
    String? name,
    double? defaultPercent,
    String? productId,
    int? sortOrder,
  }) => PoultrySection(
    id: id ?? this.id,
    name: name ?? this.name,
    defaultPercent: defaultPercent ?? this.defaultPercent,
    productId: productId ?? this.productId,
    sortOrder: sortOrder ?? this.sortOrder,
  );
}
