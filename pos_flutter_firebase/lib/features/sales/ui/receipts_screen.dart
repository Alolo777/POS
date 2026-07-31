import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/models/cart_item.dart';
import '../../../shared/models/sale.dart';
import '../../../shared/models/employee.dart';
import '../../../shared/models/store.dart';
import '../../../features/sales/domain/pdf_repository.dart';
import '../../../features/sales/domain/sale_repository.dart';
import '../../../features/shift/domain/shift_repository.dart';

class ReceiptsScreen extends StatelessWidget {
  const ReceiptsScreen({
    super.key,
    required this.businessId,
    required this.businessName,
    required this.store,
    required this.employee,
  });

  final String businessId;
  final String businessName;
  final Store store;
  final Employee employee;

  @override
  Widget build(BuildContext context) {
    final saleService = context.read<SaleRepository>();

    return Scaffold(
      appBar: AppBar(automaticallyImplyLeading: false, title: const Text('Recibos')),
      body: StreamBuilder<List<Sale>>(
        stream: saleService.watchSales(businessId: businessId, storeId: store.id),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}'));

          final sales = snapshot.data ?? const <Sale>[];
          if (sales.isEmpty) return const Center(child: Text('Todavia no hay recibos en esta sucursal.'));
          final entries = _groupSalesByDay(sales);

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: entries.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final entry = entries[index];
              if (entry.header != null) {
                return Padding(
                  padding: const EdgeInsets.fromLTRB(4, 16, 4, 8),
                  child: Text(
                    entry.header!,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                );
              }

              final sale = entry.sale!;
              return Card(
                color: _statusColor(context, sale),
                child: ListTile(
                  leading: Icon(_saleIcon(sale), color: _iconColor(sale)),
                  title: Text('${_folioLabel(sale)} ${sale.folio}'),
                  subtitle: Text(
                    '${_formatDate(_saleDate(sale))} · ${_paymentLabel(sale.paymentMethod)} · ${_statusLabel(sale)} · ID ${_shortFolio(sale.id)}',
                  ),
                  trailing: Text('\$${sale.total.toStringAsFixed(2)}'),
                  onTap: () => _showSaleDetails(context, sale),
                ),
              );
            },
          );
        },
      ),
    );
  }

  List<_ReceiptEntry> _groupSalesByDay(List<Sale> sales) {
    final entries = <_ReceiptEntry>[];
    String? currentHeader;

    for (final sale in sales) {
      final header = _dayHeader(_saleDate(sale));
      if (header != currentHeader) {
        currentHeader = header;
        entries.add(_ReceiptEntry.header(header));
      }
      entries.add(_ReceiptEntry.sale(sale));
    }

    return entries;
  }

  String _dayHeader(DateTime? date) {
    if (date == null) return 'Fecha pendiente';
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  DateTime? _saleDate(Sale sale) => sale.createdAt ?? sale.clientCreatedAt;

  Future<void> _generatePdf(BuildContext context, Sale sale) async {
    final pdfService = context.read<PdfRepository>();
    final pdfBytes = await pdfService.generateTicketPdf(
      businessName: businessName,
      store: store,
      sale: sale,
    );
    if (!context.mounted) return;
    await Printing.layoutPdf(onLayout: (_) => pdfBytes);
  }

  Future<void> _openTicketDetail(BuildContext context, Sale sale) async {
    await context.push('/home/tickets/${sale.id}', extra: {
      'businessName': businessName,
      'store': store,
      'sale': sale,
    });
  }

  Future<void> _showSaleDetails(BuildContext context, Sale sale) async {
    final screenContext = context;
    await showDialog<void>(
      context: screenContext,
      builder: (dialogContext) => AlertDialog(
        title: Text('${_folioLabel(sale)} ${_shortFolio(sale.id)}'),
        content: SizedBox(
          width: 480,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Sucursal: ${store.name}'),
                Text('Fecha: ${_formatDate(_saleDate(sale))}'),
                Text('Metodo: ${_paymentLabel(sale.paymentMethod)}'),
                Text('Estado: ${_statusLabel(sale)}'),
                if (sale.originalSaleId != null) Text('Ticket original: ${_shortFolio(sale.originalSaleId!)}'),
                if (sale.cashReceived != null) Text('Recibido: \$${sale.cashReceived!.toStringAsFixed(2)}'),
                if (sale.changeDue != null) Text('Cambio: \$${sale.changeDue!.toStringAsFixed(2)}'),
                if (sale.cancelReason != null) Text('Motivo: ${sale.cancelReason}'),
                if (sale.returnedItems.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  const Text('Productos devueltos:', style: TextStyle(fontWeight: FontWeight.w700)),
                  ...sale.returnedItems.map((item) => Text('- ${item['name']}: ${_formatQuantity((item['quantity'] as num? ?? 0).toDouble())}')),
                ],
                const Divider(),
                ...sale.items.map(_lineItem),
                const Divider(),
                _totalRow('Subtotal', sale.subtotal),
                if (sale.discountTotal > 0) _totalRow('Descuentos', -sale.discountTotal),
                _totalRow(sale.isRefund ? 'Total devuelto' : 'Total', sale.total, bold: true),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cerrar')),
          FilledButton.tonal(
            onPressed: () async {
              await _generatePdf(screenContext, sale);
            },
            child: const Text('PDF'),
          ),
          FilledButton.tonal(
            onPressed: () async {
              Navigator.pop(dialogContext);
              await _openTicketDetail(screenContext, sale);
            },
            child: const Text('Ver ticket'),
          ),
          if (!sale.isCancelled && !sale.isRefund)
            FilledButton.tonal(
              onPressed: () async {
                Navigator.pop(dialogContext);
                await _showReturnDialog(screenContext, sale);
              },
              child: const Text('Devolver productos'),
            ),
        ],
      ),
    );
  }

  Widget _lineItem(Map<String, dynamic> item) {
    final name = item['name'] as String? ?? 'Producto';
    final quantity = (item['quantity'] as num? ?? 0).toDouble();
    final unitPrice = (item['unitPrice'] as num? ?? 0).toDouble();
    final subtotal = (item['subtotal'] as num? ?? 0).toDouble();
    final modifiers = parseModifiers(item['modifiers']);
    final discount = (item['discount'] as num? ?? 0).toDouble();
    final modifierLabels = modifiers.map((m) => m.price == 0 ? m.name : '${m.name} +\$${m.price.toStringAsFixed(2)}').toList();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(fontWeight: FontWeight.w700)),
                Text('${_formatQuantity(quantity)} x \$${unitPrice.toStringAsFixed(2)}'),
                if (modifierLabels.isNotEmpty) Text('+ ${modifierLabels.join(', ')}'),
                if (discount > 0) Text('Descuento producto: \$${discount.toStringAsFixed(2)}'),
              ],
            ),
          ),
          Text('\$${subtotal.toStringAsFixed(2)}'),
        ],
      ),
    );
  }

  Future<void> _showReturnDialog(BuildContext context, Sale sale) async {
    final result = await showDialog<({List<Map<String, dynamic>> items, bool returnInventory, String reason})>(
      context: context,
      builder: (context) => _ReturnDialog(sale: sale),
    );
    if (result == null || !context.mounted) return;

    try {
      final shiftService = context.read<ShiftRepository>();
      final currentShift = await shiftService.getOpenShift(
        businessId: businessId,
        storeId: store.id,
        employeeId: employee.id,
      );
      final saleService = context.read<SaleRepository>();
      final refundId = await saleService.cancelSale(
        businessId: businessId,
        sale: sale,
        returnItems: result.items,
        returnInventory: result.returnInventory,
        reason: result.reason,
        refundShiftId: currentShift?.id,
        refundEmployeeId: employee.id,
      );
      final exists = await saleService.refundExists(businessId: businessId, refundId: refundId);
      if (!context.mounted) return;
      if (!exists) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se encontro el ticket de devolucion ${_shortFolio(refundId)} despues de crearlo')),
        );
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Devolucion registrada: ${_shortFolio(refundId)}')),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Widget _totalRow(String label, double value, {bool bold = false}) {
    final style = bold ? const TextStyle(fontWeight: FontWeight.w700) : null;
    return Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(label, style: style), Text('\$${value.toStringAsFixed(2)}', style: style)]);
  }

  IconData _saleIcon(Sale sale) {
    if (sale.isRefund) return Icons.assignment_return;
    if (sale.paymentMethod == 'card') return Icons.credit_card;
    if (sale.isCancelled) return Icons.cancel;
    if (sale.isPartiallyCancelled) return Icons.remove_shopping_cart;
    return Icons.receipt_long;
  }

  Color? _iconColor(Sale sale) {
    if (sale.isCancelled || sale.isRefund) return Colors.red;
    if (sale.isPartiallyCancelled) return Colors.orange;
    return null;
  }

  Color _statusColor(BuildContext context, Sale sale) {
    if (sale.isCancelled || sale.isRefund) return Colors.red.withValues(alpha: 0.08);
    if (sale.isPartiallyCancelled) return Colors.orange.withValues(alpha: 0.10);
    return Theme.of(context).cardColor;
  }

  String _folioLabel(Sale sale) => sale.isRefund ? 'Devolucion' : 'Ticket';
  String _shortFolio(String value) => value.substring(0, value.length.clamp(0, 6)).toUpperCase();
  String _paymentLabel(String value) => value == 'card' ? 'Tarjeta' : 'Efectivo';
  String _statusLabel(Sale sale) {
    if (sale.isRefund) return 'Devolucion';
    if (sale.isCancelled) return 'Cancelado total';
    if (sale.isPartiallyCancelled) return 'Cancelado parcial';
    return 'Pagado';
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'Fecha pendiente';
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  String _formatQuantity(double value) {
    if (value % 1 == 0) return value.toStringAsFixed(0);
    return value.toStringAsFixed(3).replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '');
  }
}

class _ReceiptEntry {
  const _ReceiptEntry._({this.header, this.sale});

  factory _ReceiptEntry.header(String value) => _ReceiptEntry._(header: value);
  factory _ReceiptEntry.sale(Sale value) => _ReceiptEntry._(sale: value);

  final String? header;
  final Sale? sale;
}

class _ReturnDialog extends StatefulWidget {
  const _ReturnDialog({required this.sale});

  final Sale sale;

  @override
  State<_ReturnDialog> createState() => _ReturnDialogState();
}

class _ReturnDialogState extends State<_ReturnDialog> {
  final _reasonController = TextEditingController();
  late final List<double> _quantities;
  bool _returnInventory = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _quantities = widget.sale.items.map((_) => 0.0).toList();
  }

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Devolver productos'),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Regresar al inventario'),
                value: _returnInventory,
                onChanged: (value) => setState(() => _returnInventory = value),
              ),
              ...widget.sale.items.asMap().entries.map((entry) {
                final index = entry.key;
                final item = entry.value;
                final name = item['name'] as String? ?? 'Producto';
                final originalQuantity = (item['quantity'] as num? ?? 0).toDouble();
                final alreadyReturned = _returnedQuantity(item['productId'] as String? ?? '');
                final maxQuantity = (originalQuantity - alreadyReturned).clamp(0, double.infinity).toDouble();
                final selectedQuantity = _quantities[index].clamp(0, maxQuantity).toDouble();
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(name, style: const TextStyle(fontWeight: FontWeight.w700)),
                          Text('Disponible para devolver: ${_formatQuantity(maxQuantity)}'),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              IconButton.filledTonal(
                                onPressed: selectedQuantity <= 0 ? null : () => _setQuantity(index, selectedQuantity - _stepFor(maxQuantity)),
                                icon: const Icon(Icons.remove),
                              ),
                              Expanded(
                                child: Text(
                                  _formatQuantity(selectedQuantity),
                                  textAlign: TextAlign.center,
                                  style: Theme.of(context).textTheme.titleMedium,
                                ),
                              ),
                              IconButton.filledTonal(
                                onPressed: selectedQuantity >= maxQuantity ? null : () => _setQuantity(index, selectedQuantity + _stepFor(maxQuantity)),
                                icon: const Icon(Icons.add),
                              ),
                              const SizedBox(width: 8),
                              TextButton(
                                onPressed: maxQuantity <= 0 ? null : () => _setQuantity(index, maxQuantity),
                                child: const Text('Todo'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
              TextField(
                controller: _reasonController,
                decoration: const InputDecoration(labelText: 'Motivo opcional', border: OutlineInputBorder()),
              ),
              if (_errorMessage != null) ...[
                const SizedBox(height: 8),
                Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        FilledButton(onPressed: _submit, child: const Text('Registrar devolucion')),
      ],
    );
  }

  void _submit() {
    final items = <Map<String, dynamic>>[];
    for (var index = 0; index < widget.sale.items.length; index++) {
      final original = widget.sale.items[index];
      final quantity = _quantities[index];
      final originalQuantity = (original['quantity'] as num? ?? 0).toDouble();
      final productId = original['productId'] as String? ?? '';
      final maxQuantity = originalQuantity - _returnedQuantity(productId);
      if (quantity < 0 || quantity > maxQuantity) {
        setState(() => _errorMessage = 'Revisa las cantidades a devolver');
        return;
      }
      if (quantity == 0) continue;

      final lineSubtotal = (original['subtotal'] as num? ?? 0).toDouble();
      final unitSubtotal = originalQuantity <= 0 ? 0 : lineSubtotal / originalQuantity;
      items.add({
        ...original,
        'quantity': quantity,
        'subtotal': unitSubtotal * quantity,
      });
    }

    if (items.isEmpty) {
      setState(() => _errorMessage = 'Selecciona al menos una cantidad');
      return;
    }

    Navigator.pop(context, (items: items, returnInventory: _returnInventory, reason: _reasonController.text));
  }

  String _formatQuantity(double value) {
    if (value % 1 == 0) return value.toStringAsFixed(0);
    return value.toStringAsFixed(3).replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '');
  }

  double _returnedQuantity(String productId) {
    return widget.sale.returnedItems
        .where((item) => item['productId'] == productId)
        .fold<double>(0, (total, item) => total + (item['quantity'] as num? ?? 0).toDouble());
  }

  void _setQuantity(int index, double value) {
    final original = widget.sale.items[index];
    final originalQuantity = (original['quantity'] as num? ?? 0).toDouble();
    final productId = original['productId'] as String? ?? '';
    final maxQuantity = originalQuantity - _returnedQuantity(productId);
    setState(() {
      _quantities[index] = value.clamp(0, maxQuantity).toDouble();
      _errorMessage = null;
    });
  }

  double _stepFor(double maxQuantity) {
    if (maxQuantity % 1 == 0) return 1;
    return 0.1;
  }
}
