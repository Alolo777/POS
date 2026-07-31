class ButcherSection {
  const ButcherSection({
    this.id,
    required this.name,
    this.productId,
    this.productName,
    required this.percentage,
    required this.sortOrder,
  });

  final String? id;
  final String name;
  final String? productId;
  final String? productName;
  final double percentage;
  final int sortOrder;

  Map<String, dynamic> toMap() => {
    'name': name,
    'productId': productId,
    'productName': productName,
    'percentage': percentage,
    'sortOrder': sortOrder,
  };

  factory ButcherSection.fromMap(Map<String, dynamic> map) => ButcherSection(
    id: map['id'] as String?,
    name: map['name'] as String? ?? '',
    productId: map['productId'] as String?,
    productName: map['productName'] as String?,
    percentage: (map['percentage'] as num? ?? 0).toDouble(),
    sortOrder: (map['sortOrder'] as num? ?? 0).toInt(),
  );

  static const List<ButcherSection> defaults = [
    ButcherSection(name: 'Pechuga', percentage: 0.3738, sortOrder: 1),
    ButcherSection(name: 'Maciza', percentage: 0.2619, sortOrder: 2),
    ButcherSection(name: 'Alas', percentage: 0.0810, sortOrder: 3),
    ButcherSection(name: 'Patas', percentage: 0.0357, sortOrder: 4),
    ButcherSection(name: 'Huacal', percentage: 0.0857, sortOrder: 5),
    ButcherSection(name: 'Mollejas/Higado', percentage: 0.0357, sortOrder: 6),
    ButcherSection(name: 'Rabadilla', percentage: 0.0690, sortOrder: 7),
    ButcherSection(name: 'Cabezas', percentage: 0.0190, sortOrder: 8),
    ButcherSection(name: 'Merma', percentage: 0.0381, sortOrder: 9),
  ];

  ButcherSection copyWith({
    String? id,
    String? name,
    String? productId,
    String? productName,
    double? percentage,
    int? sortOrder,
  }) => ButcherSection(
    id: id ?? this.id,
    name: name ?? this.name,
    productId: productId ?? this.productId,
    productName: productName ?? this.productName,
    percentage: percentage ?? this.percentage,
    sortOrder: sortOrder ?? this.sortOrder,
  );
}