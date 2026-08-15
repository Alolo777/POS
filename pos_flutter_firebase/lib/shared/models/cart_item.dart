import 'product.dart';

class SelectedModifier {
  const SelectedModifier({
    required this.id,
    required this.name,
    required this.price,
  });

  final String id;
  final String name;
  final double price;

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'price': price,
  };

  factory SelectedModifier.fromMap(Map<String, dynamic> map) {
    return SelectedModifier(
      id: map['id'] as String? ?? '',
      name: map['name'] as String? ?? '',
      price: (map['price'] as num? ?? 0).toDouble(),
    );
  }

  factory SelectedModifier.fromString(String name) {
    return SelectedModifier(id: '', name: name, price: 0);
  }
}

List<SelectedModifier> parseModifiers(dynamic modifiersData) {
  if (modifiersData is List) {
    return modifiersData.map((m) {
      if (m is Map<String, dynamic>) {
        return SelectedModifier.fromMap(m);
      }
      return SelectedModifier.fromString(m.toString());
    }).toList();
  }
  return const [];
}

/// Pieza de destazado intercambiada al vender un pollo entero.
///
/// - [direction] == `'out'`: pieza entregada al cliente (se resta del stock).
/// - [direction] == `'in'`: pieza devuelta por el cliente (se suma al stock).
class PieceSwap {
  const PieceSwap({
    required this.productId,
    required this.productName,
    required this.weight,
    required this.direction,
  });

  final String productId;
  final String productName;
  final double weight;
  final String direction;

  bool get isOut => direction == 'out';

  Map<String, dynamic> toMap() => {
    'productId': productId,
    'productName': productName,
    'weight': weight,
    'direction': direction,
  };

  factory PieceSwap.fromMap(Map<String, dynamic> map) => PieceSwap(
    productId: map['productId'] as String? ?? '',
    productName: map['productName'] as String? ?? '',
    weight: (map['weight'] as num? ?? 0).toDouble(),
    direction: map['direction'] as String? ?? 'out',
  );
}

List<PieceSwap> parsePieceSwaps(dynamic swapsData) {
  if (swapsData is List) {
    return swapsData.map((e) {
      if (e is Map<String, dynamic>) return PieceSwap.fromMap(e);
      return PieceSwap.fromMap(Map<String, dynamic>.from(e as Map));
    }).toList();
  }
  return const [];
}

class CartItem {
  const CartItem({
    required this.product,
    required this.quantity,
    this.modifiers = const [],
    this.discount = 0,
    this.chickenCount,
    this.pieceSwaps = const [],
  });

  final Product product;
  final double quantity;
  final List<SelectedModifier> modifiers;
  final double discount;

  /// Pollos enteros vendidos en esta línea. Solo se usa para el producto
  /// de pollo entero y permite descontar el conteo de pollos del stock.
  final int? chickenCount;

  /// Piezas de destazado intercambiadas al vender pollo entero.
  final List<PieceSwap> pieceSwaps;

  String get formattedQuantity {
    if (product.sellBy == 'weight') {
      return quantity.toStringAsFixed(3).replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '');
    }
    return quantity.toStringAsFixed(0);
  }

  double get subtotal {
    final basePrice = product.price * quantity;
    final modifierTotal = modifiers.fold<double>(0, (total, m) => total + m.price) * quantity;
    return basePrice + modifierTotal - discount;
  }

  CartItem copyWith({
    double? quantity,
    List<SelectedModifier>? modifiers,
    double? discount,
    int? chickenCount,
    List<PieceSwap>? pieceSwaps,
  }) {
    return CartItem(
      product: product,
      quantity: quantity ?? this.quantity,
      modifiers: modifiers ?? this.modifiers,
      discount: discount ?? this.discount,
      chickenCount: chickenCount ?? this.chickenCount,
      pieceSwaps: pieceSwaps ?? this.pieceSwaps,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'productId': product.id,
      'name': product.name,
      'categoryId': product.categoryId,
      'categoryName': product.categoryName,
      'unitPrice': product.price,
      'quantity': quantity,
      'modifiers': modifiers.map((m) => m.toMap()).toList(),
      'discount': discount,
      'subtotal': subtotal,
      if (chickenCount != null) 'chickenCount': chickenCount,
      if (pieceSwaps.isNotEmpty) 'pieceSwaps': pieceSwaps.map((s) => s.toMap()).toList(),
    };
  }
}