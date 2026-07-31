import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

import '../../../shared/models/cart_item.dart';
import '../../../shared/models/sale.dart';
import '../../../shared/models/store.dart';
import '../../../features/sales/data/pdf_service.dart';

class TicketDetailScreen extends StatelessWidget {
  const TicketDetailScreen({
    super.key,
    required this.businessName,
    required this.store,
    required this.sale,
  });

  final String businessName;
  final Store store;
  final Sale sale;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(sale.isRefund ? 'Devolucion ${sale.folio}' : 'Ticket ${sale.folio}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            tooltip: 'PDF',
            onPressed: () => _generatePdf(context),
          ),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      businessName,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 4),
                    Text(store.name, textAlign: TextAlign.center),
                    const Divider(height: 28),
                    _row('Folio', sale.folio),
                    _row('Estado', _statusLabel(sale)),
                    _row('Fecha', _formatDate(sale.createdAt ?? sale.clientCreatedAt)),
                    _row('Pago', _paymentLabel(sale.paymentMethod)),
                    if (sale.originalSaleId != null) _row('Ticket original', sale.originalSaleId!),
                    if (sale.cashReceived != null) _row('Recibido', '\$${sale.cashReceived!.toStringAsFixed(2)}'),
                    if (sale.changeDue != null) _row('Cambio', '\$${sale.changeDue!.toStringAsFixed(2)}'),
                    if (sale.cancelReason != null) _row('Motivo', sale.cancelReason!),
                    const Divider(height: 28),
                    ...sale.items.map(_itemRow),
                    const Divider(height: 28),
                    _row('Subtotal', '\$${sale.subtotal.toStringAsFixed(2)}'),
                    if (sale.discountTotal > 0) _row('Descuentos', '-\$${sale.discountTotal.toStringAsFixed(2)}'),
                    _row(
                      sale.isRefund ? 'Total devuelto' : 'Total',
                      '\$${sale.total.toStringAsFixed(2)}',
                      bold: true,
                    ),
                    if (sale.returnedItems.isNotEmpty) ...[
                      const Divider(height: 28),
                      const Text('Productos devueltos', style: TextStyle(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 8),
                      ...sale.returnedItems.map(
                        (item) => Text(
                          '- ${item['name'] ?? 'Producto'}: ${_formatQuantity((item['quantity'] as num? ?? 0).toDouble())}',
                        ),
                      ),
                    ],
                    const Divider(height: 28),
                    Text(
                      sale.isRefund ? 'Comprobante de devolucion' : 'Gracias por su compra',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _itemRow(Map<String, dynamic> item) {
    final name = item['name'] as String? ?? 'Producto';
    final quantity = (item['quantity'] as num? ?? 0).toDouble();
    final unitPrice = (item['unitPrice'] as num? ?? 0).toDouble();
    final subtotal = (item['subtotal'] as num? ?? 0).toDouble();
    final modifiers = parseModifiers(item['modifiers']);
    final modifierLabels = modifiers.map((m) => m.price == 0 ? m.name : '${m.name} +\$${m.price.toStringAsFixed(2)}').toList();
    final discount = (item['discount'] as num? ?? 0).toDouble();

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
                if (discount > 0) Text('Descuento: \$${discount.toStringAsFixed(2)}'),
              ],
            ),
          ),
          Text('\$${subtotal.toStringAsFixed(2)}'),
        ],
      ),
    );
  }

  Widget _row(String label, String value, {bool bold = false}) {
    final style = bold ? const TextStyle(fontWeight: FontWeight.w800) : null;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: Text(label, style: style)),
          const SizedBox(width: 12),
          Flexible(child: Text(value, textAlign: TextAlign.end, style: style)),
        ],
      ),
    );
  }

  String _statusLabel(Sale sale) {
    if (sale.isRefund) return 'Devolucion';
    if (sale.isCancelled) return 'Cancelado total';
    if (sale.isPartiallyCancelled) return 'Cancelado parcial';
    return 'Pagado';
  }

  String _paymentLabel(String value) => value == 'card' ? 'Tarjeta' : 'Efectivo';

  String _formatDate(DateTime? date) {
    if (date == null) return 'Fecha pendiente';
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year} '
        '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  String _formatQuantity(double value) {
    if (value % 1 == 0) return value.toStringAsFixed(0);
    return value.toStringAsFixed(3).replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '');
  }

  Future<void> _generatePdf(BuildContext context) async {
    final pdfService = PdfService();
    final pdfBytes = await pdfService.generateTicketPdf(
      businessName: businessName,
      store: store,
      sale: sale,
    );
    if (!context.mounted) return;
    await Printing.layoutPdf(onLayout: (_) => pdfBytes);
  }
}
