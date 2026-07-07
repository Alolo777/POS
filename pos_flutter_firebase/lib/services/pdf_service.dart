import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../models/sale.dart';
import '../models/store.dart';

class PdfService {
  Future<Uint8List> generateTicketPdf({
    required String businessName,
    required Store store,
    required Sale sale,
  }) async {
    final doc = pw.Document();

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.roll80,
        margin: const pw.EdgeInsets.all(16),
        build: (context) => [
          _header(businessName, store),
          pw.Divider(),
          _info(sale),
          pw.Divider(),
          _items(sale),
          pw.Divider(),
          _totals(sale),
          if (sale.paymentMethod == 'cash' && sale.cashReceived != null) ...[
            pw.SizedBox(height: 4),
            _paymentRow('Recibido', sale.cashReceived!),
            _paymentRow('Cambio', sale.changeDue ?? 0),
          ],
          if (sale.returnedItems.isNotEmpty) ...[
            pw.SizedBox(height: 8),
            _returnedItems(sale),
          ],
          pw.SizedBox(height: 16),
          pw.Center(child: pw.Text('Gracias por su compra', style: pw.TextStyle(fontSize: 10))),
        ],
      ),
    );

    return doc.save();
  }

  pw.Widget _header(String businessName, Store store) {
    return pw.Column(
      children: [
        pw.Center(child: pw.Text(businessName, style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold))),
        pw.Center(child: pw.Text(store.name, style: pw.TextStyle(fontSize: 10))),
        if (store.address.isNotEmpty)
          pw.Center(child: pw.Text(store.address, style: pw.TextStyle(fontSize: 8))),
        if (store.phone.isNotEmpty)
          pw.Center(child: pw.Text('Tel: ${store.phone}', style: pw.TextStyle(fontSize: 8))),
      ],
    );
  }

  pw.Widget _info(Sale sale) {
    final date = sale.createdAt ?? sale.clientCreatedAt;
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _row('Folio', sale.folio),
        _row('Fecha', _formatDate(date)),
        _row('Metodo', sale.paymentMethod == 'cash' ? 'Efectivo' : 'Tarjeta'),
        if (sale.status == 'cancelled')
          _row('Estado', 'CANCELADO'),
        if (sale.status == 'partially_cancelled')
          _row('Estado', 'CANCELADO PARCIAL'),
        if (sale.cancelReason != null && sale.cancelReason!.isNotEmpty)
          _row('Motivo', sale.cancelReason!),
        if (sale.originalSaleId != null)
          _row('Ticket origen', sale.folio),
      ],
    );
  }

  pw.Widget _items(Sale sale) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text('Producto', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
            pw.Text('Total', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
          ],
        ),
        pw.SizedBox(height: 4),
        ...sale.items.map((item) {
          final name = item['name'] as String? ?? '';
          final quantity = (item['quantity'] as num? ?? 0).toDouble();
          final unitPrice = (item['unitPrice'] as num? ?? 0).toDouble();
          final modifiers = item['modifiers'] as List<dynamic>? ?? [];
          final discount = (item['discount'] as num? ?? 0).toDouble();
          final subtotal = (item['subtotal'] as num? ?? 0).toDouble();

          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Expanded(child: pw.Text('${_formatQty(quantity)} x $name', style: pw.TextStyle(fontSize: 8))),
                  pw.Text('\$${subtotal.toStringAsFixed(2)}', style: pw.TextStyle(fontSize: 8)),
                ],
              ),
              if (unitPrice > 0 && quantity != 0)
                pw.Padding(
                  padding: const pw.EdgeInsets.only(left: 8),
                  child: pw.Text('\$${unitPrice.toStringAsFixed(2)} c/u', style: pw.TextStyle(fontSize: 7, color: PdfColors.grey)),
                ),
              ...modifiers.map((m) {
                final mod = m as Map<String, dynamic>;
                final modName = mod['name'] as String? ?? '';
                final modPrice = (mod['price'] as num? ?? 0).toDouble();
                return pw.Padding(
                  padding: const pw.EdgeInsets.only(left: 8),
                  child: pw.Text(
                    modPrice > 0 ? '$modName +\$${modPrice.toStringAsFixed(2)}' : modName,
                    style: pw.TextStyle(fontSize: 7, color: PdfColors.grey),
                  ),
                );
              }),
              if (discount > 0)
                pw.Padding(
                  padding: const pw.EdgeInsets.only(left: 8),
                  child: pw.Text('Descuento: -\$${discount.toStringAsFixed(2)}', style: pw.TextStyle(fontSize: 7, color: PdfColors.orange)),
                ),
            ],
          );
        }),
      ],
    );
  }

  pw.Widget _totals(Sale sale) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _row('Subtotal', '\$${sale.subtotal.toStringAsFixed(2)}'),
        if (sale.discountTotal > 0)
          _row('Descuento', '-\$${sale.discountTotal.toStringAsFixed(2)}'),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text('Total', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
            pw.Text('\$${sale.total.toStringAsFixed(2)}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
          ],
        ),
      ],
    );
  }

  pw.Widget _returnedItems(Sale sale) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text('Productos devueltos:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
        ...sale.returnedItems.map((item) {
          final name = item['name'] as String? ?? '';
          final qty = (item['quantity'] as num? ?? 0).toDouble();
          return pw.Padding(
            padding: const pw.EdgeInsets.only(left: 8),
            child: pw.Text('$name x ${_formatQty(qty)}', style: pw.TextStyle(fontSize: 8)),
          );
        }),
      ],
    );
  }

  pw.Widget _row(String label, String value) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(label, style: pw.TextStyle(fontSize: 8, color: PdfColors.grey)),
        pw.Text(value, style: pw.TextStyle(fontSize: 8)),
      ],
    );
  }

  pw.Widget _paymentRow(String label, double amount) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(label, style: pw.TextStyle(fontSize: 8)),
        pw.Text('\$${amount.toStringAsFixed(2)}', style: pw.TextStyle(fontSize: 8)),
      ],
    );
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'N/A';
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  String _formatQty(double qty) {
    return qty == qty.roundToDouble() ? qty.toInt().toString() : qty.toStringAsFixed(3);
  }
}
