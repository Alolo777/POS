import 'package:flutter/foundation.dart';

import '../models/cart_item.dart';
import '../models/product.dart';
import 'app_session_notifier.dart';

class CartProvider extends ChangeNotifier {
  CartProvider({required AppSessionNotifier sessionNotifier}) {
    _sessionNotifier = sessionNotifier;
    _sessionNotifier.addListener(_onSessionChanged);
  }

  late final AppSessionNotifier _sessionNotifier;
  String? _lastStoreId;

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

  void _onSessionChanged() {
    final currentStoreId = _sessionNotifier.resolvedStore.id;
    if (currentStoreId != _lastStoreId) {
      _lastStoreId = currentStoreId;
      if (_cart.isNotEmpty) {
        clear();
      }
    }
  }

  void addToCart(
    Product product,
    double quantity, {
    int? chickenCount,
    List<PieceSwap>? pieceSwaps,
  }) {
    final existingIndex = _cart.indexWhere((item) => item.product.id == product.id);
    if (existingIndex >= 0) {
      final existing = _cart[existingIndex];
      _cart[existingIndex] = existing.copyWith(
        quantity: existing.quantity + quantity,
        chickenCount: chickenCount == null
            ? existing.chickenCount
            : (existing.chickenCount ?? 0) + chickenCount,
        pieceSwaps: pieceSwaps == null
            ? existing.pieceSwaps
            : [...existing.pieceSwaps, ...pieceSwaps],
      );
    } else {
      _cart.add(CartItem(
        product: product,
        quantity: quantity,
        chickenCount: chickenCount,
        pieceSwaps: pieceSwaps ?? const [],
      ));
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

  @override
  void dispose() {
    _sessionNotifier.removeListener(_onSessionChanged);
    super.dispose();
  }
}
