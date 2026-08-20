import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../shared/models/cart_item.dart';
import '../../../shared/models/category.dart' as app_models;
import '../../../shared/models/employee.dart';
import '../../../shared/models/open_ticket.dart';
import '../../../shared/models/product.dart';
import '../../../shared/models/shift.dart';
import '../../../shared/models/store.dart';
import '../../../shared/providers/cart_provider.dart';
import '../../../core/logger/logger_service.dart';
import '../domain/open_ticket_repository.dart';
import '../../sales/domain/sale_repository.dart';
import '../../shift/domain/shift_repository.dart';
import '../../poultry/domain/poultry_repository.dart';
import '../domain/category_repository.dart';
import 'widgets/modifier_dialog.dart';
import 'widgets/piece_swap_dialog.dart';
import 'widgets/product_grid.dart';
import 'widgets/ticket_discount_dialog.dart';

class PosScreen extends StatefulWidget {
  const PosScreen({
    super.key,
    required this.businessId,
    required this.store,
    required this.employee,
  });

  final String businessId;
  final Store store;
  final Employee employee;

  @override
  State<PosScreen> createState() => _PosScreenState();
}

class _PosScreenState extends State<PosScreen> {
  bool _isCharging = false;
  String _searchQuery = '';
  String? _selectedCategoryId;

  late final SaleRepository _saleService;
  late final ShiftRepository _shiftService;
  late final OpenTicketRepository _openTicketService;
  late final CartProvider _cartProvider;
  late final Stream<Shift?> _shiftStream;
  final LoggerService _logger = LoggerService();
  String? _wholeProductId;

  double get _subtotal => _cartProvider.subtotal;
  double get _total => _cartProvider.total;

  @override
  void initState() {
    super.initState();
    _saleService = context.read<SaleRepository>();
    _shiftService = context.read<ShiftRepository>();
    _openTicketService = context.read<OpenTicketRepository>();
    _cartProvider = context.read<CartProvider>();
    _shiftStream = _shiftService.watchOpenShift(
      businessId: widget.businessId,
      storeId: widget.store.id,
      employeeId: widget.employee.id,
    );
    _loadWholeProductId();
  }

  Future<void> _loadWholeProductId() async {
    try {
      final config = await context
          .read<PoultryRepository>()
          .getConfig(widget.businessId);
      if (!mounted) return;
      _wholeProductId = config?.wholeProductId;
    } catch (_) {
      // Sin config de pollo: no hay producto de pollo entero que detectar.
    }
  }

  Future<void> _addToCart(Product product) async {
    double? quantity;
    int? chickenCount;
    var pieceSwaps = const <PieceSwap>[];
    if (product.sellBy == 'weight') {
      final result = await _askWeightQuantity(product);
      if (result == null || !mounted) return;
      quantity = result.weight;
      chickenCount = result.chickenCount;
      if (product.id == _wholeProductId) {
        final swaps = await showDialog<List<PieceSwap>>(
          context: context,
          builder: (context) => PieceSwapDialog(
            businessId: widget.businessId,
            storeId: widget.store.id,
            wholeProductId: _wholeProductId,
          ),
        );
        if (swaps == null || !mounted) return;
        pieceSwaps = swaps;
      }
    } else {
      quantity = 1.0;
    }

    if (product.trackStock && product.stockQuantity <= 0) {
      _showMessage('${product.name} no tiene stock disponible');
      return;
    }

    final currentQuantity = _cartProvider.containsProduct(product.id)
        ? _cartProvider.cart.firstWhere((item) => item.product.id == product.id).quantity
        : 0.0;
    final nextQuantity = currentQuantity + quantity;

    if (product.trackStock && nextQuantity > product.stockQuantity + 0.000001) {
      _showMessage('No hay suficiente stock de ${product.name}');
      return;
    }

    if (chickenCount != null) {
      final currentChickens = _cartProvider.containsProduct(product.id)
          ? _cartProvider.cart.firstWhere((item) => item.product.id == product.id).chickenCount ?? 0
          : 0;
      final nextChickens = currentChickens + chickenCount;
      if (product.chickenCount != null && nextChickens > product.chickenCount!) {
        _showMessage('No hay suficientes pollos enteros de ${product.name}');
        return;
      }
    }

    _cartProvider.addToCart(
      product,
      quantity,
      chickenCount: chickenCount,
      pieceSwaps: pieceSwaps,
    );
  }

  void _removeFromCart(CartItem item) {
    final index = _cartProvider.indexOf(item.product.id);
    if (index == -1) return;
    final existing = _cartProvider.cart[index];
    if (existing.product.sellBy == 'weight' || existing.quantity <= 1) {
      _cartProvider.removeFromCart(index);
    } else {
      _cartProvider.updateItem(index, existing.copyWith(quantity: existing.quantity - 1));
    }
  }

  Future<({double weight, int? chickenCount})?> _askWeightQuantity(Product product) async {
    return showDialog<({double weight, int? chickenCount})>(
      context: context,
      builder: (context) => _WeightQuantityDialog(
        product: product,
        askChickenCount: product.id == _wholeProductId,
      ),
    );
  }

  Future<void> _clearCurrentTicket() async {
    if (_cartProvider.isEmpty) {
      _showMessage('No hay ticket activo para borrar');
      return;
    }

    final openTicketId = _cartProvider.currentOpenTicketId;
    if (openTicketId != null) {
      try {
        await _openTicketService.cancelOpenTicket(
          businessId: widget.businessId,
          ticketId: openTicketId,
        );
      } catch (e) {
        if (!mounted) return;
        _showMessage(e.toString());
        return;
      }
    }

    _cartProvider.clear();
    _showMessage('Ticket actual borrado');
  }

  void _syncReceipts() {
    // En Fase K esto se conectara a la cola offline-first. Por ahora dejamos
    // la accion visible para mantener el flujo real del POS sin fingir sync.
    _showMessage('Sincronizacion en linea pendiente para la fase offline');
  }

  Future<void> _charge(
    String paymentMethod, {
    required Shift shift,
    double? cashReceived,
    double? changeDue,
  }) async {
    if (_cartProvider.isEmpty || _isCharging) return;

    setState(() => _isCharging = true);

    try {
      final folio = await _saleService.createSale(
        businessId: widget.businessId,
        storeId: widget.store.id,
        employeeId: widget.employee.id,
        shiftId: shift.id,
        items: List<CartItem>.from(_cartProvider.cart),
        subtotal: _subtotal,
        discountTotal: _cartProvider.ticketDiscount,
        total: _total,
        paymentMethod: paymentMethod,
        cashReceived: cashReceived,
        changeDue: changeDue,
      );
      _logger.info('Venta creada: $folio', tag: 'Sale');

      if (!mounted) return;
      final openTicketId = _cartProvider.currentOpenTicketId;
      if (openTicketId != null) {
        await _openTicketService.closeOpenTicket(
          businessId: widget.businessId,
          ticketId: openTicketId,
        );
        if (!mounted) return;
      }

      _cartProvider.clear();
      _showMessage(
        paymentMethod == 'cash'
            ? 'Venta $folio guardada. Cambio: \$${(changeDue ?? 0).toStringAsFixed(2)}'
            : 'Venta $folio con tarjeta guardada',
      );
    } catch (e) {
      _logger.error('Error al crear venta: $e', tag: 'Sale');
      if (!mounted) return;
      _showMessage(e.toString());
    } finally {
      if (mounted) {
        setState(() => _isCharging = false);
      }
    }
  }

  Future<void> _showPaymentDialog(Shift shift) async {
    if (_cartProvider.isEmpty) {
      _showMessage('Agrega productos al carrito');
      return;
    }

    final payment = await showDialog<({String method, double? received, double? change})>(
      context: context,
      builder: (context) => _CashPaymentDialog(total: _total),
    );

    if (payment == null) return;

    if (payment.method == 'card') {
      await _charge('card', shift: shift);
      return;
    }

    await _charge(
      'cash',
      shift: shift,
      cashReceived: payment.received,
      changeDue: payment.change,
    );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _showTicketDiscountDialog() async {
    final result = await showDialog<({String name, double amount})>(
      context: context,
      builder: (context) => TicketDiscountDialog(
        businessId: widget.businessId,
        currentDiscount: _cartProvider.ticketDiscount,
        subtotal: _subtotal,
      ),
    );
    if (result == null || !mounted) return;
    _cartProvider.setTicketDiscount(result.amount, result.name);
    _showMessage('Descuento aplicado: ${result.name}');
  }

  Future<void> _suspendCurrentTicket() async {
    if (_cartProvider.isEmpty) {
      _showMessage('Agrega productos antes de suspender');
      return;
    }

    final name = await showDialog<String>(
      context: context,
      builder: (context) => _OpenTicketNameDialog(initialName: _cartProvider.currentOpenTicketName),
    );
    if (name == null || !mounted) return;

    try {
      await _openTicketService.saveOpenTicket(
        businessId: widget.businessId,
        storeId: widget.store.id,
        employeeId: widget.employee.id,
        name: name,
        items: List<CartItem>.from(_cartProvider.cart),
        total: _total,
        ticketId: _cartProvider.currentOpenTicketId,
      );
      if (!mounted) return;
      _cartProvider.clear();
      _showMessage('Ticket suspendido');
    } catch (e) {
      if (!mounted) return;
      _showMessage(e.toString());
    }
  }

  Future<void> _showOpenTicketsDialog() async {
    final ticket = await showDialog<OpenTicket>(
      context: context,
      builder: (context) => _OpenTicketsDialog(
        businessId: widget.businessId,
        storeId: widget.store.id,
        openTicketService: _openTicketService,
      ),
    );
    if (ticket == null || !mounted) return;

    if (_cartProvider.isNotEmpty) {
      final replace = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Reemplazar ticket actual'),
          content: const Text('Tienes productos en el carrito. Si recuperas otro ticket, se perdera el ticket actual no suspendido.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Reemplazar')),
          ],
        ),
      );
      if (replace != true || !mounted) return;
    }

    _cartProvider.restoreCart(_cartFromOpenTicket(ticket));
    _cartProvider.setOpenTicket(ticket.id, ticket.name);
    _showMessage('Ticket recuperado: ${ticket.name}');
  }

  List<CartItem> _cartFromOpenTicket(OpenTicket ticket) {
    return ticket.items.map((item) {
      final product = Product(
        id: item['productId'] as String? ?? '',
        name: item['name'] as String? ?? 'Producto',
        categoryId: item['categoryId'] as String?,
        categoryName: item['categoryName'] as String?,
        sellBy: 'unit',
        price: (item['unitPrice'] as num? ?? 0).toDouble(),
        cost: 0,
        ref: '',
        trackStock: false,
        stockQuantity: 0,
        lowStockAlertQuantity: 0,
        presentationType: 'shape',
        presentationShape: 'square',
        presentationColor: 0xFF9E9E9E,
        imageUrl: null,
        localImagePath: null,
        active: true,
      );
      return CartItem(
        product: product,
        quantity: (item['quantity'] as num? ?? 0).toDouble(),
        modifiers: parseModifiers(item['modifiers']),
        discount: (item['discount'] as num? ?? 0).toDouble(),
        chickenCount: item['chickenCount'] as int?,
        pieceSwaps: parsePieceSwaps(item['pieceSwaps']),
      );
    }).toList();
  }

  Future<void> _editCartItem(CartItem item) async {
    final result = await showDialog<({List<SelectedModifier> modifiers, double discount})>(
      context: context,
      builder: (context) => ModifierSelectionDialog(
        businessId: widget.businessId,
        currentModifiers: item.modifiers,
        currentDiscount: item.discount,
        itemPrice: item.product.price * item.quantity,
        quantity: item.quantity,
      ),
    );
    if (result == null || !mounted) return;
    final index = _cartProvider.indexOf(item.product.id);
    if (index == -1) return;
    _cartProvider.updateItem(index, item.copyWith(modifiers: result.modifiers, discount: result.discount));
  }

  Future<void> _showCartDetails() async {
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Desglose del carrito'),
        content: SizedBox(
          width: 420,
          child: _cartProvider.isEmpty
              ? const Text('No hay productos en el carrito.')
              : SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ..._cartProvider.cart.map(
                        (item) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(item.product.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                                    Text(
                                      '${item.formattedQuantity} x \$${item.product.price.toStringAsFixed(2)}',
                                    ),
                                    if (item.modifiers.isNotEmpty)
                                      Text(
                                        item.modifiers.map((m) => m.price == 0 ? m.name : '${m.name} +\$${m.price.toStringAsFixed(2)}').join(', '),
                                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
                                      ),
                                    if (item.discount > 0)
                                      Text('Descuento: -\$${item.discount.toStringAsFixed(2)}', style: const TextStyle(color: Colors.orange, fontSize: 12)),
                                    if (item.product.trackStock)
                                      Text('Stock actual: ${_formatQuantity(item.product.stockQuantity)}'),
                                  ],
                                ),
                              ),
                              Text('\$${item.subtotal.toStringAsFixed(2)}'),
                            ],
                          ),
                        ),
                      ),
                      const Divider(),
                      if (_cartProvider.hasDiscount)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(_cartProvider.ticketDiscountName ?? 'Descuento'),
                            Text('-\$${_cartProvider.ticketDiscount.toStringAsFixed(2)}'),
                          ],
                        ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Total', style: TextStyle(fontWeight: FontWeight.w700)),
                          Text('\$${_total.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.w700)),
                        ],
                      ),
                    ],
                  ),
                ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cerrar')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Shift?>(
      stream: _shiftStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final shift = snapshot.data;
        if (shift == null) {
          return _OpenShiftView(
            businessId: widget.businessId,
            store: widget.store,
            employee: widget.employee,
            shiftService: _shiftService,
          );
        }

        return _buildSellingLayout(shift);
      },
    );
  }

  Widget _buildSellingLayout(Shift shift) {
    final isWide = MediaQuery.sizeOf(context).width >= 700;

    return Scaffold(
      body: isWide
          ? Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Column(
                    children: [
                      _buildPosToolbar(shift),
                      Expanded(
                        child: ProductGrid(
                          businessId: widget.businessId,
                          storeId: widget.store.id,
                          searchQuery: _searchQuery,
                          selectedCategoryId: _selectedCategoryId,
                          onTap: _addToCart,
                        ),
                      ),
                    ],
                  ),
                ),
                const VerticalDivider(width: 1),
                Expanded(
                  child: Consumer<CartProvider>(
                    builder: (context, cartProvider, _) => _buildCartPanel(shift),
                  ),
                ),
              ],
            )
          : Column(
              children: [
                _buildPosToolbar(shift),
                Expanded(
                  child: ProductGrid(
                    businessId: widget.businessId,
                    storeId: widget.store.id,
                    searchQuery: _searchQuery,
                    selectedCategoryId: _selectedCategoryId,
                    onTap: _addToCart,
                  ),
                ),
                SizedBox(
                  height: 260,
                  child: Consumer<CartProvider>(
                    builder: (context, cartProvider, _) => _buildCartPanel(shift),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildPosToolbar(Shift shift) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  key: const Key('searchField'),
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    hintText: 'Buscar productos o REF',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  onChanged: (value) => setState(() => _searchQuery = value.trim()),
                ),
              ),
              const SizedBox(width: 8),
               PopupMenuButton<String>(
                tooltip: 'Mas opciones',
                onSelected: (value) {
                  if (value == 'clear_ticket') {
                    _clearCurrentTicket();
                  } else if (value == 'suspend_ticket') {
                    _suspendCurrentTicket();
                  } else if (value == 'open_tickets') {
                    _showOpenTicketsDialog();
                  } else if (value == 'sync_receipts') {
                    _syncReceipts();
                  } else if (value == 'ticket_discount') {
                    _showTicketDiscountDialog();
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'ticket_discount',
                    child: ListTile(leading: Icon(Icons.discount), title: Text('Descuento ticket'), dense: true, contentPadding: EdgeInsets.zero),
                  ),
                  const PopupMenuItem(
                    value: 'suspend_ticket',
                    child: Text('Suspender ticket'),
                  ),
                  PopupMenuItem(
                    value: 'open_tickets',
                    child: Text('Tickets abiertos'),
                  ),
                  PopupMenuItem(
                    value: 'clear_ticket',
                    child: Text('Borrar ticket actual'),
                  ),
                  PopupMenuItem(
                    value: 'sync_receipts',
                    child: Text('Sincronizar recibos en linea'),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          _CategoryFilter(
            businessId: widget.businessId,
            selectedCategoryId: _selectedCategoryId,
            onChanged: (value) => setState(() => _selectedCategoryId = value),
          ),
        ],
      ),
    );
  }

  String _formatQuantity(double value) {
    if (value % 1 == 0) {
      return value.toStringAsFixed(0);
    }

    return value.toStringAsFixed(3).replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '');
  }

  Widget _buildCartPanel(Shift shift) {
    return Card(
      margin: const EdgeInsets.all(12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            InkWell(
              onTap: _showCartDetails,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        _cartProvider.currentOpenTicketName == null ? 'Carrito' : 'Carrito ┬╖ ${_cartProvider.currentOpenTicketName}',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    const Icon(Icons.receipt_long),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: _cartProvider.isEmpty
                  ? const Center(child: Text('Sin productos'))
                  : ListView.builder(
                      itemCount: _cartProvider.cart.length,
                      itemBuilder: (context, index) {
                        final item = _cartProvider.cart[index];
                        final modifierText = item.modifiers.isEmpty
                            ? null
                            : item.modifiers.map((m) => m.price == 0 ? m.name : '${m.name} +\$${m.price.toStringAsFixed(2)}').join(', ');
                        return ListTile(
                          dense: true,
                          onTap: () => _editCartItem(item),
                          title: Text(item.product.name),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('${item.formattedQuantity} x \$${item.product.price.toStringAsFixed(2)}'),
                              if (modifierText != null)
                                Text(modifierText, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey[600])),
                              if (item.discount > 0)
                                Text('Descuento: -\$${item.discount.toStringAsFixed(2)}', style: const TextStyle(color: Colors.orange, fontSize: 11)),
                            ],
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('\$${item.subtotal.toStringAsFixed(2)}'),
                              const SizedBox(width: 4),
                              IconButton(
                                icon: const Icon(Icons.remove_circle_outline, size: 20),
                                onPressed: () => _removeFromCart(item),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
            const Divider(),
            if (_cartProvider.hasDiscount) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Subtotal'),
                  Text('\$${_subtotal.toStringAsFixed(2)}'),
                ],
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(_cartProvider.ticketDiscountName ?? 'Descuento'),
                  Text('-\$${_cartProvider.ticketDiscount.toStringAsFixed(2)}'),
                ],
              ),
              const SizedBox(height: 4),
            ],
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Total'),
                Text(
                  '\$${_total.toStringAsFixed(2)}',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ],
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _isCharging ? null : () => _showPaymentDialog(shift),
              icon: _isCharging
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.payments),
              label: const Text('Cobrar'),
            ),
          ],
        ),
      ),
    );
  }
}

class _OpenShiftView extends StatefulWidget {
  const _OpenShiftView({
    required this.businessId,
    required this.store,
    required this.employee,
    required this.shiftService,
  });

  final String businessId;
  final Store store;
  final Employee employee;
  final ShiftRepository shiftService;

  @override
  State<_OpenShiftView> createState() => _OpenShiftViewState();
}

class _OpenShiftViewState extends State<_OpenShiftView> {
  final _openingCashController = TextEditingController(text: '0.00');
  bool _isOpening = false;
  String? _errorMessage;

  @override
  void dispose() {
    _openingCashController.dispose();
    super.dispose();
  }

  Future<void> _openShift() async {
    final openingCash = double.tryParse(_openingCashController.text.trim().replaceAll(',', '.'));
    if (openingCash == null || openingCash < 0) {
      setState(() => _errorMessage = 'Ingresa un efectivo inicial valido');
      return;
    }

    setState(() {
      _isOpening = true;
      _errorMessage = null;
    });

    try {
      await widget.shiftService.openShift(
        businessId: widget.businessId,
        storeId: widget.store.id,
        employeeId: widget.employee.id,
        openingCash: openingCash,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = e.toString());
    } finally {
      if (mounted) {
        setState(() => _isOpening = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(Icons.point_of_sale, size: 56, color: Theme.of(context).colorScheme.primary),
                  const SizedBox(height: 12),
                  Text(
                    'Abre caja para vender',
                    style: Theme.of(context).textTheme.titleLarge,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Sucursal: ${widget.store.name}',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _openingCashController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Efectivo inicial',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  if (_errorMessage != null) ...[
                    const SizedBox(height: 12),
                    Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
                  ],
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: _isOpening ? null : _openShift,
                    icon: _isOpening
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.lock_open),
                    label: const Text('Abrir caja'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CategoryFilter extends StatefulWidget {
  const _CategoryFilter({
    required this.businessId,
    required this.selectedCategoryId,
    required this.onChanged,
  });

  final String businessId;
  final String? selectedCategoryId;
  final ValueChanged<String?> onChanged;

  @override
  State<_CategoryFilter> createState() => _CategoryFilterState();
}

class _CategoryFilterState extends State<_CategoryFilter> {
  late Stream<List<app_models.Category>> _categoriesStream;

  @override
  void initState() {
    super.initState();
    _categoriesStream = context
        .read<CategoryRepository>()
        .watchCategories(businessId: widget.businessId);
  }

  @override
  void didUpdateWidget(_CategoryFilter oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.businessId != widget.businessId) {
      _categoriesStream = context
          .read<CategoryRepository>()
          .watchCategories(businessId: widget.businessId);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<app_models.Category>>(
      stream: _categoriesStream,
      builder: (context, snapshot) {
        final categories = snapshot.data ?? const <app_models.Category>[];
        if (categories.isEmpty) {
          return const SizedBox.shrink();
        }

        return SizedBox(
          height: 42,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: categories.length + 1,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              if (index == 0) {
                return ChoiceChip(
                  selected: widget.selectedCategoryId == null,
                  label: const Text('Todas'),
                  onSelected: (_) => widget.onChanged(null),
                );
              }

              final category = categories[index - 1];
              return ChoiceChip(
                selected: widget.selectedCategoryId == category.id,
                avatar: CircleAvatar(backgroundColor: Color(category.color)),
                label: Text(category.name),
                onSelected: (_) => widget.onChanged(category.id),
              );
            },
          ),
        );
      },
    );
  }
}

class _OpenTicketNameDialog extends StatefulWidget {
  const _OpenTicketNameDialog({this.initialName});

  final String? initialName;

  @override
  State<_OpenTicketNameDialog> createState() => _OpenTicketNameDialogState();
}

class _OpenTicketNameDialogState extends State<_OpenTicketNameDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialName ?? '');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Suspender ticket'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        decoration: const InputDecoration(
          labelText: 'Nombre del ticket',
          helperText: 'Ejemplo: Cliente Juan, Mesa 1, Pedido mostrador',
          border: OutlineInputBorder(),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        FilledButton(
          onPressed: () => Navigator.pop(context, _controller.text.trim().isEmpty ? 'Ticket abierto' : _controller.text.trim()),
          child: const Text('Guardar'),
        ),
      ],
    );
  }
}

class _OpenTicketsDialog extends StatelessWidget {
  const _OpenTicketsDialog({
    required this.businessId,
    required this.storeId,
    required this.openTicketService,
  });

  final String businessId;
  final String storeId;
  final OpenTicketRepository openTicketService;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Tickets abiertos'),
      content: SizedBox(
        width: 460,
        child: StreamBuilder<List<OpenTicket>>(
          stream: openTicketService.watchOpenTickets(businessId: businessId, storeId: storeId),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const SizedBox(height: 120, child: Center(child: CircularProgressIndicator()));
            }
            if (snapshot.hasError) {
              return Text('Error: ${snapshot.error}');
            }
            final tickets = snapshot.data ?? const <OpenTicket>[];
            if (tickets.isEmpty) {
              return const Text('No hay tickets abiertos en esta sucursal.');
            }

            return ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 360),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: tickets.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final ticket = tickets[index];
                  return ListTile(
                    leading: const Icon(Icons.pending_actions),
                    title: Text(ticket.name),
                    subtitle: Text('${ticket.items.length} productos ┬╖ ${_formatDate(ticket.updatedAt ?? ticket.createdAt)}'),
                    trailing: Text('\$${ticket.total.toStringAsFixed(2)}'),
                    onTap: () => Navigator.pop(context, ticket),
                  );
                },
              ),
            );
          },
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cerrar')),
      ],
    );
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'Fecha pendiente';
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')} '
        '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }
}

class _WeightQuantityDialog extends StatefulWidget {
  const _WeightQuantityDialog({
    required this.product,
    this.askChickenCount = false,
  });

  final Product product;
  final bool askChickenCount;

  @override
  State<_WeightQuantityDialog> createState() => _WeightQuantityDialogState();
}

class _WeightQuantityDialogState extends State<_WeightQuantityDialog> {
  final _controller = TextEditingController(text: '1');
  final _chickenCountCtrl = TextEditingController();
  String? _errorMessage;

  @override
  void dispose() {
    _controller.dispose();
    _chickenCountCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Cantidad de ${widget.product.name}'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _controller,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'Peso/volumen',
                helperText: widget.product.trackStock
                    ? 'Disponible: ${_formatQuantity(widget.product.stockQuantity)}'
                    : 'Ejemplo: 0.250, 1.5, 2',
                errorText: _errorMessage,
                border: const OutlineInputBorder(),
              ),
            ),
            if (widget.askChickenCount) ...[
              const SizedBox(height: 16),
              TextField(
                controller: _chickenCountCtrl,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Cantidad de pollos',
                  helperText: widget.product.chickenCount != null
                      ? 'Pollos disponibles: ${widget.product.chickenCount}'
                      : 'Número de pollos vendidos',
                  border: const OutlineInputBorder(),
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        FilledButton(onPressed: _submit, child: const Text('Agregar')),
      ],
    );
  }

  void _submit() {
    final value = double.tryParse(_controller.text.trim().replaceAll(',', '.'));
    if (value == null || value <= 0) {
      setState(() => _errorMessage = 'Ingresa una cantidad mayor a cero');
      return;
    }
    if (widget.product.trackStock && value > widget.product.stockQuantity + 0.000001) {
      setState(() => _errorMessage = 'La cantidad supera el stock disponible');
      return;
    }

    int? chickenCount;
    if (widget.askChickenCount) {
      final count = int.tryParse(_chickenCountCtrl.text.trim());
      if (count == null || count <= 0) {
        setState(() => _errorMessage = 'Indica cuántos pollos se venden');
        return;
      }
      if (widget.product.chickenCount != null && count > widget.product.chickenCount!) {
        setState(() => _errorMessage = 'Solo hay ${widget.product.chickenCount} pollos disponibles');
        return;
      }
      chickenCount = count;
    }

    Navigator.pop(context, (weight: value, chickenCount: chickenCount));
  }

  String _formatQuantity(double value) {
    if (value % 1 == 0) return value.toStringAsFixed(0);
    return value.toStringAsFixed(3).replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '');
  }
}

class _CashPaymentDialog extends StatefulWidget {
  const _CashPaymentDialog({required this.total});

  final double total;

  @override
  State<_CashPaymentDialog> createState() => _CashPaymentDialogState();
}

class _CashPaymentDialogState extends State<_CashPaymentDialog> {
  late final TextEditingController _receivedController;
  late double _received;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _received = widget.total;
    _receivedController = TextEditingController(text: widget.total.toStringAsFixed(2));
  }

  @override
  void dispose() {
    _receivedController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final change = _received - widget.total;
    final suggestions = _cashSuggestions(widget.total);

    return AlertDialog(
      title: const Text('Cobrar venta'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Total: \$${widget.total.toStringAsFixed(2)}'),
            const SizedBox(height: 12),
            TextField(
              controller: _receivedController,
              autofocus: false,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'Dinero recibido',
                helperText: 'Por defecto viene el total exacto. Puedes editarlo.',
                errorText: _errorMessage,
                border: const OutlineInputBorder(),
              ),
              onChanged: (value) {
                final parsed = double.tryParse(value.trim().replaceAll(',', '.'));
                setState(() {
                  _received = parsed ?? 0;
                  _errorMessage = null;
                });
              },
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: suggestions
                  .map(
                    (value) => ActionChip(
                      label: Text('Recibi \$${value.toStringAsFixed(0)}'),
                      onPressed: () => _setReceived(value),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 16),
            Text(
              'Cambio: \$${change < 0 ? 0.toStringAsFixed(2) : change.toStringAsFixed(2)}',
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        FilledButton.tonalIcon(
          onPressed: _submitCard,
          icon: const Icon(Icons.credit_card),
          label: const Text('Cobrar con tarjeta'),
        ),
        FilledButton(
          onPressed: _submit,
          child: const Text('Cobrar efectivo'),
        ),
      ],
    );
  }

  void _setReceived(double value) {
    _receivedController.text = value.toStringAsFixed(2);
    setState(() {
      _received = value;
      _errorMessage = null;
    });
  }

  void _submit() {
    final parsed = double.tryParse(_receivedController.text.trim().replaceAll(',', '.'));
    if (parsed == null || parsed < widget.total) {
      setState(() {
        _received = parsed ?? 0;
        _errorMessage = 'El dinero recibido no cubre el total';
      });
      return;
    }

    Navigator.pop(
      context,
      (method: 'cash', received: parsed, change: parsed - widget.total),
    );
  }

  void _submitCard() {
    Navigator.pop(
      context,
      (method: 'card', received: null, change: null),
    );
  }

  List<double> _cashSuggestions(double total) {
    final suggestions = <double>{};
    final roundedTo50 = (total / 50).ceil() * 50.0;
    if (roundedTo50 > total) {
      suggestions.add(roundedTo50);
    }

    for (final bill in const [20, 50, 100, 200, 500, 1000]) {
      if (bill >= total) {
        suggestions.add(bill.toDouble());
      }
      if (suggestions.length >= 3) break;
    }

    var next = roundedTo50 + 50;
    while (suggestions.length < 3 && next <= 2000) {
      suggestions.add(next);
      next += 50;
    }

    return suggestions.take(3).toList()..sort();
  }
}


