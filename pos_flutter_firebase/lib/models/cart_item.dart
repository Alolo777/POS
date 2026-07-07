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

class CartItem {
  const CartItem({
    required this.product,
    required this.quantity,
    this.modifiers = const [],
    this.discount = 0,
  });

  final Product product;
  final double quantity;
  final List<SelectedModifier> modifiers;
  final double discount;

  double get subtotal {
    final basePrice = product.price * quantity;
    final modifierTotal = modifiers.fold<double>(0, (total, m) => total + m.price) * quantity;
    return basePrice + modifierTotal - discount;
  }

  CartItem copyWith({
    double? quantity,
    List<SelectedModifier>? modifiers,
    double? discount,
  }) {
    return CartItem(
      product: product,
      quantity: quantity ?? this.quantity,
      modifiers: modifiers ?? this.modifiers,
      discount: discount ?? this.discount,
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
    };
  }
}
