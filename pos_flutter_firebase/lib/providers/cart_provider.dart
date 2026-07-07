import 'package:flutter/foundation.dart';

import '../models/cart_item.dart';
import '../models/product.dart';

class CartProvider extends ChangeNotifier {
  final List<CartItem> _cart = [];

  double _ticketDiscount = 0;
  String? _ticketDiscountName;
  String? _currentOpenTicketId;
  String? _currentOpenTicketName;

  List<CartItem> get cart => List.unmodifiable(_cart);
  double get subtotal => _cart.fold(0, (sum, item) => sum + item.subtotal);
  double get ticketDiscount => _ticketDiscount;
  String? get ticketDiscountName => _ticketDiscountName;
  double get total => (subtotal - _ticketDiscount).clamp(0, double.infinity);
  String? get currentOpenTicketId => _currentOpenTicketId;
  String? get currentOpenTicketName => _currentOpenTicketName;
  bool get isEmpty => _cart.isEmpty;
  bool get isNotEmpty => _cart.isNotEmpty;
  bool get hasDiscount => _ticketDiscount > 0;

  int get itemCount => _cart.length;

  bool containsProduct(String productId) => _cart.any((item) => item.product.id == productId);

  void addToCart(Product product, double quantity) {
    final existingIndex = _cart.indexWhere((item) => item.product.id == product.id);
    if (existingIndex >= 0) {
      final existing = _cart[existingIndex];
      _cart[existingIndex] = existing.copyWith(quantity: existing.quantity + quantity);
    } else {
      _cart.add(CartItem(product: product, quantity: quantity));
    }
    notifyListeners();
  }

  void removeFromCart(int index) {
    if (index >= 0 && index < _cart.length) {
      _cart.removeAt(index);
      notifyListeners();
    }
  }

  void updateItem(int index, CartItem item) {
    if (index >= 0 && index < _cart.length) {
      _cart[index] = item;
      notifyListeners();
    }
  }

  int indexOf(String productId) => _cart.indexWhere((c) => c.product.id == productId);

  void clear() {
    _cart.clear();
    _ticketDiscount = 0;
    _ticketDiscountName = null;
    _currentOpenTicketId = null;
    _currentOpenTicketName = null;
    notifyListeners();
  }

  void clearCartOnly() {
    _cart.clear();
    notifyListeners();
  }

  void setTicketDiscount(double amount, String? name) {
    _ticketDiscount = amount;
    _ticketDiscountName = amount > 0 ? name : null;
    notifyListeners();
  }

  void removeTicketDiscount() {
    _ticketDiscount = 0;
    _ticketDiscountName = null;
    notifyListeners();
  }

  void setOpenTicket(String? id, String? name) {
    _currentOpenTicketId = id;
    _currentOpenTicketName = name;
    notifyListeners();
  }

  void restoreCart(List<CartItem> items) {
    _cart
      ..clear()
      ..addAll(items);
    notifyListeners();
  }
}
