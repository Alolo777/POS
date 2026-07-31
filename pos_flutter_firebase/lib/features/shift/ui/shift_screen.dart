import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../shared/models/employee.dart';
import '../../../shared/models/sale.dart';
import '../../../shared/models/shift.dart';
import '../../../shared/models/store.dart';
import '../../../features/sales/domain/sale_repository.dart';
import '../../../features/shift/domain/shift_repository.dart';

class ShiftScreen extends StatelessWidget {
  const ShiftScreen({
    super.key,
    required this.businessId,
    required this.store,
    required this.employee,
  });

  final String businessId;
  final Store store;
  final Employee employee;

  @override
  Widget build(BuildContext context) {
    final shiftService = context.read<ShiftRepository>();
    final saleService = context.read<SaleRepository>();

    return Scaffold(
      appBar: AppBar(automaticallyImplyLeading: false, title: const Text('Turno')),
      body: StreamBuilder<Shift?>(
        stream: shiftService.watchOpenShift(
          businessId: businessId,
          storeId: store.id,
          employeeId: employee.id,
        ),
        builder: (context, shiftSnapshot) {
          if (shiftSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final shift = shiftSnapshot.data;
          if (shift == null) {
            return const Center(child: Text('No hay turno abierto. Abre caja desde Punto de venta.'));
          }

          return StreamBuilder<List<Sale>>(
            stream: saleService.watchSalesByShift(
              businessId: businessId,
              storeId: store.id,
              shiftId: shift.id,
            ),
            builder: (context, salesSnapshot) {
              final sales = salesSnapshot.data ?? const <Sale>[];
              final summary = _ShiftSummary.fromSales(shift, sales);

                  return StreamBuilder<List<Shift>>(
                stream: shiftService.watchShifts(businessId: businessId, storeId: store.id),
                builder: (context, shiftsSnapshot) {
                  final allShifts = shiftsSnapshot.data ?? const <Shift>[];
                  final closedShifts = allShifts.where((s) => s.status == 'closed').take(10).toList();
                  final closeCount = closedShifts.length;

                  return ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      _sectionCard(
                        context,
                        title: 'Informacion del turno',
                        children: [
                          _infoRow('Numero de cierres de caja', closeCount.toString()),
                          _infoRow('Abierto por', employee.name),
                          _infoRow('Fecha de apertura', _formatDate(shift.openedAt)),
                        ],
                      ),
                  _sectionCard(
                    context,
                    title: 'Cajon de efectivo',
                    children: [
                      _moneyRow('Fondo de caja', shift.openingCash),
                      _moneyRow('Cobros en efectivo', summary.cashSales),
                      _moneyRow('Reembolsos en efectivo', summary.cashRefunds),
                      _moneyRow('Depositos', shift.depositsTotal),
                      _moneyRow('Pagos/Salidas', shift.payoutsTotal),
                      const Divider(),
                      _moneyRow('Efectivo teorico en caja', summary.expectedCash, bold: true),
                      if (summary.cashShortage > 0) ...[
                        const SizedBox(height: 8),
                        Text(
                          'Falto efectivo para cubrir devoluciones: \$${summary.cashShortage.toStringAsFixed(2)}',
                          style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w700),
                        ),
                      ],
                    ],
                  ),
                  _sectionCard(
                    context,
                    title: 'Resumen de ventas',
                    children: [
                      _moneyRow('Ventas brutas', summary.grossSales),
                      _moneyRow('Reembolsos', summary.refunds),
                      _moneyRow('Descuentos', summary.discounts),
                      const Divider(),
                      _moneyRow('Ventas netas', summary.netSales, bold: true),
                    ],
                  ),
                  _PoultryMovementCard(
                    businessId: businessId,
                    storeId: store.id,
                    openedAt: shift.openedAt,
                  ),
                  _sectionCard(
                    context,
                    title: 'Tesoreria',
                    children: [
                      FilledButton.icon(
                        onPressed: () => _showMovementDialog(context, shiftService, shift, 'deposit'),
                        icon: const Icon(Icons.add),
                        label: const Text('Deposito'),
                      ),
                      const SizedBox(height: 8),
                      FilledButton.tonalIcon(
                        onPressed: () => _showMovementDialog(context, shiftService, shift, 'payout'),
                        icon: const Icon(Icons.remove),
                        label: const Text('Pagos/Salidas'),
                      ),
                      if (shift.cashMovements.isNotEmpty) ...[
                        const Divider(),
                        ...shift.cashMovements.reversed.map((movement) {
                          final type = movement['type'] == 'deposit' ? 'Deposito' : 'Salida';
                          final amount = (movement['amount'] as num? ?? 0).toDouble();
                          final comment = movement['comment'] as String? ?? '';
                          return ListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            leading: Icon(movement['type'] == 'deposit' ? Icons.arrow_downward : Icons.arrow_upward),
                            title: Text('$type · \$${amount.toStringAsFixed(2)}'),
                            subtitle: Text(comment.isEmpty ? 'Sin comentario' : comment),
                          );
                        }),
                      ],
                    ],
                  ),
                  FilledButton.icon(
                    onPressed: () => _showCloseShiftDialog(context, shiftService, shift, summary),
                    icon: const Icon(Icons.lock),
                    label: const Text('Cerrar turno'),
                  ),
                  if (closedShifts.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    _sectionCard(
                      context,
                      title: 'Historial de turnos',
                      children: [
                        ...closedShifts.map((closedShift) {
                          final diff = (closedShift.closingCash ?? 0) - closedShift.expectedCash;
                          return ListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            leading: Icon(diff >= 0 ? Icons.check_circle : Icons.warning,
                                color: diff >= 0 ? Colors.green : Colors.orange),
                            title: Text(_formatDate(closedShift.openedAt)),
                            subtitle: Text('Ventas: \$${closedShift.totalSales.toStringAsFixed(2)}'),
                            trailing: Text(
                              diff == 0 ? 'Cuadrado' : '${diff >= 0 ? '+' : ''}\$${diff.toStringAsFixed(2)}',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: diff == 0 ? Colors.green : (diff > 0 ? Colors.green : Colors.red),
                              ),
                            ),
                            onTap: () => _showClosedShiftDetail(context, closedShift),
                          );
                        }),
                      ],
                    ),
                  ],
                    ],
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _showMovementDialog(
    BuildContext context,
    ShiftRepository shiftService,
    Shift shift,
    String type,
  ) async {
    final result = await showDialog<({double amount, String comment})>(
      context: context,
      builder: (context) => _CashMovementDialog(type: type),
    );
    if (result == null || !context.mounted) return;

    try {
      await shiftService.addCashMovement(
        businessId: businessId,
        shift: shift,
        type: type,
        amount: result.amount,
        comment: result.comment,
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> _showCloseShiftDialog(
    BuildContext context,
    ShiftRepository shiftService,
    Shift shift,
    _ShiftSummary summary,
  ) async {
    final closingCash = await showDialog<double>(
      context: context,
      builder: (context) => _CloseShiftDialog(
        expectedCash: summary.expectedCash,
        openingCash: shift.openingCash,
        cashSales: summary.cashSales,
        cashRefunds: summary.cashRefunds,
        deposits: shift.depositsTotal,
        payouts: shift.payoutsTotal,
      ),
    );
    if (closingCash == null || !context.mounted) return;

    try {
      await shiftService.closeShift(businessId: businessId, shift: shift, closingCash: closingCash);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Turno cerrado')));
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  void _showClosedShiftDetail(BuildContext context, Shift closedShift) {
    final diff = (closedShift.closingCash ?? 0) - closedShift.expectedCash;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Turno - ${_formatDate(closedShift.openedAt)}'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _moneyRow('Fondo de caja', closedShift.openingCash),
              _moneyRow('Efectivo cobrado', closedShift.cashSales),
              _moneyRow('Reembolsos', -closedShift.cashRefunds),
              _moneyRow('Depositos', closedShift.depositsTotal),
              _moneyRow('Salidas', -closedShift.payoutsTotal),
              const Divider(),
              _moneyRow('Efectivo teorico', closedShift.expectedCash, bold: true),
              _moneyRow('Efectivo contado', closedShift.closingCash ?? 0, bold: true),
              _moneyRow('Diferencia', diff, bold: true),
              const Divider(),
              _moneyRow('Ventas total', closedShift.totalSales),
              _moneyRow('Tarjeta', closedShift.cardSales),
              if (closedShift.chickensReceived > 0 || closedShift.chickensButchered > 0 || closedShift.transfersSent > 0 || closedShift.transfersReceived > 0) ...[
                const Divider(),
                Text('Movimiento de inventario', style: TextStyle(fontWeight: FontWeight.w700, color: Colors.grey[600])),
                const SizedBox(height: 4),
                if (closedShift.chickensReceived > 0)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Text('Pollos recibidos: ${closedShift.chickensReceived} (${closedShift.kgReceived.toStringAsFixed(2)} kg)'),
                  ),
                if (closedShift.chickensButchered > 0)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Text('Pollos destazados: ${closedShift.chickensButchered} (${closedShift.kgButchered.toStringAsFixed(2)} kg)'),
                  ),
                if (closedShift.transfersSent > 0)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Text('Traspasos enviados: ${closedShift.transfersSent}'),
                  ),
                if (closedShift.transfersReceived > 0)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Text('Traspasos recibidos: ${closedShift.transfersReceived}'),
                  ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cerrar')),
        ],
      ),
    );
  }

  Widget _sectionCard(BuildContext context, {required String title, required List<Widget> children}) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(label), Flexible(child: Text(value, textAlign: TextAlign.end))]),
    );
  }

  Widget _moneyRow(String label, double value, {bool bold = false}) {
    final style = bold ? const TextStyle(fontWeight: FontWeight.w700) : null;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(label, style: style), Text('\$${value.toStringAsFixed(2)}', style: style)]),
    );
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'Fecha pendiente';
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }
}

class _ShiftSummary {
  const _ShiftSummary({
    required this.cashSales,
    required this.cashRefunds,
    required this.grossSales,
    required this.refunds,
    required this.discounts,
    required this.netSales,
    required this.expectedCash,
    required this.cashShortage,
  });

  final double cashSales;
  final double cashRefunds;
  final double grossSales;
  final double refunds;
  final double discounts;
  final double netSales;
  final double expectedCash;
  final double cashShortage;

  factory _ShiftSummary.fromSales(Shift shift, List<Sale> sales) {
    final originalSales = sales.where((sale) => !sale.isRefund).toList();
    final refunds = sales.where((sale) => sale.isRefund).toList();
    final cashSales = originalSales.where((sale) => sale.paymentMethod == 'cash').fold<double>(0, (total, sale) => total + sale.total);
    final cashRefunds = refunds.where((sale) => sale.paymentMethod == 'cash').fold<double>(0, (total, sale) => total + sale.total);
    final grossSales = originalSales.fold<double>(0, (total, sale) => total + _grossSale(sale));
    final refundTotal = refunds.fold<double>(0, (total, sale) => total + sale.total);
    final discounts = originalSales.fold<double>(0, (total, sale) => total + sale.discountTotal + _lineDiscounts(sale));
    final netSales = originalSales.fold<double>(0, (total, sale) => total + sale.total) - refundTotal;
    final expectedCash = shift.openingCash + cashSales - cashRefunds + shift.depositsTotal - shift.payoutsTotal;
    final cashShortage = expectedCash < 0 ? expectedCash.abs() : 0.0;

    return _ShiftSummary(
      cashSales: cashSales,
      cashRefunds: cashRefunds,
      grossSales: grossSales,
      refunds: refundTotal,
      discounts: discounts,
      netSales: netSales,
      expectedCash: expectedCash,
      cashShortage: cashShortage,
    );
  }

  static double _grossSale(Sale sale) {
    return sale.items.fold<double>(0, (total, item) {
      final quantity = (item['quantity'] as num? ?? 0).toDouble();
      final unitPrice = (item['unitPrice'] as num? ?? 0).toDouble();
      return total + (quantity * unitPrice);
    });
  }

  static double _lineDiscounts(Sale sale) {
    return sale.items.fold<double>(0, (total, item) => total + (item['discount'] as num? ?? 0).toDouble());
  }
}

class _CashMovementDialog extends StatefulWidget {
  const _CashMovementDialog({required this.type});

  final String type;

  @override
  State<_CashMovementDialog> createState() => _CashMovementDialogState();
}

class _CashMovementDialogState extends State<_CashMovementDialog> {
  final _amountController = TextEditingController();
  final _commentController = TextEditingController();
  String? _errorMessage;

  @override
  void dispose() {
    _amountController.dispose();
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.type == 'deposit' ? 'Registrar deposito' : 'Registrar pago/salida'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _amountController,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: 'Cantidad',
              errorText: _errorMessage,
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _commentController,
            decoration: const InputDecoration(labelText: 'Comentario', border: OutlineInputBorder()),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        FilledButton(onPressed: _submit, child: const Text('Guardar')),
      ],
    );
  }

  void _submit() {
    final amount = double.tryParse(_amountController.text.trim().replaceAll(',', '.'));
    if (amount == null || amount <= 0) {
      setState(() => _errorMessage = 'Ingresa una cantidad mayor a cero');
      return;
    }
    Navigator.pop(context, (amount: amount, comment: _commentController.text));
  }
}

class _CloseShiftDialog extends StatefulWidget {
  const _CloseShiftDialog({
    required this.expectedCash,
    required this.openingCash,
    required this.cashSales,
    required this.cashRefunds,
    required this.deposits,
    required this.payouts,
  });

  final double expectedCash;
  final double openingCash;
  final double cashSales;
  final double cashRefunds;
  final double deposits;
  final double payouts;

  @override
  State<_CloseShiftDialog> createState() => _CloseShiftDialogState();
}

class _CloseShiftDialogState extends State<_CloseShiftDialog> {
  late final TextEditingController _controller;
  late double _realCash;

  @override
  void initState() {
    super.initState();
    _realCash = widget.expectedCash;
    _controller = TextEditingController(text: widget.expectedCash.toStringAsFixed(2));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final difference = _realCash - widget.expectedCash;
    return AlertDialog(
      title: const Text('Cerrar turno'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Desglose de efectivo teorico:',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            _row('Fondo inicial', widget.openingCash),
            _row('+ Efectivo cobrado', widget.cashSales),
            _row('- Reembolsos', -widget.cashRefunds),
            _row('+ Depositos', widget.deposits),
            _row('- Salidas', -widget.payouts),
            const Divider(),
            _row('Efectivo teorico esperado', widget.expectedCash, bold: true, divider: false),
            const SizedBox(height: 16),
            TextField(
              controller: _controller,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Efectivo real contado', border: OutlineInputBorder()),
              onChanged: (value) {
                setState(() => _realCash = double.tryParse(value.trim().replaceAll(',', '.')) ?? 0);
              },
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Descuadre:', style: TextStyle(fontWeight: FontWeight.w700)),
                Text(
                  difference == 0 ? 'Cuadrado' : '${difference >= 0 ? '+' : ''}\$${difference.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: difference == 0 ? Colors.green : (difference > 0 ? Colors.orange : Colors.red),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        FilledButton(onPressed: () => Navigator.pop(context, _realCash), child: const Text('Cerrar turno')),
      ],
    );
  }

  Widget _row(String label, double value, {bool bold = false, bool divider = true}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: bold ? const TextStyle(fontWeight: FontWeight.w700) : null),
          Text(
            value >= 0 ? '\$${value.toStringAsFixed(2)}' : '-\$${(-value).toStringAsFixed(2)}',
            style: TextStyle(
              fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
              color: value >= 0 ? null : Colors.red,
            ),
          ),
        ],
      ),
    );
  }
}

class _PoultryMovementCard extends StatelessWidget {
  const _PoultryMovementCard({
    required this.businessId,
    required this.storeId,
    required this.openedAt,
  });

  final String businessId;
  final String storeId;
  final DateTime? openedAt;

  @override
  Widget build(BuildContext context) {
    final start = openedAt ?? DateTime.now().subtract(const Duration(days: 1));
    final end = DateTime.now();

    return FutureBuilder<PoultryMovementData>(
      future: _loadData(start, end),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Card(
            margin: EdgeInsets.only(bottom: 16),
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))),
            ),
          );
        }
        final data = snapshot.data;
        if (data == null || (data.chickensReceived == 0 && data.chickensButchered == 0 && data.transfersSent == 0 && data.transfersReceived == 0)) {
          return const SizedBox.shrink();
        }
        return Card(
          margin: const EdgeInsets.only(bottom: 16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Movimiento de inventario', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                if (data.chickensReceived > 0) ...[
                  Text('Pollos recibidos: ${data.chickensReceived} (${data.kgReceived.toStringAsFixed(2)} kg)'),
                  const SizedBox(height: 4),
                ],
                if (data.chickensButchered > 0) ...[
                  Text('Pollos destazados: ${data.chickensButchered} (${data.kgButchered.toStringAsFixed(2)} kg)'),
                  if (data.butcherMermaKg > 0)
                    Text('Merma: ${data.butcherMermaKg.toStringAsFixed(2)} kg', style: const TextStyle(color: Colors.orange)),
                  const SizedBox(height: 4),
                ],
                if (data.transfersSent > 0) Text('Traspasos enviados: ${data.transfersSent}'),
                if (data.transfersReceived > 0) Text('Traspasos recibidos: ${data.transfersReceived}'),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<PoultryMovementData> _loadData(DateTime start, DateTime end) async {
    final db = FirebaseFirestore.instance;

    final receivingsDocs = await db
        .collection('businesses').doc(businessId)
        .collection('poultryReceivings')
        .where('storeId', isEqualTo: storeId)
        .get();
    int chickensReceived = 0;
    double kgReceived = 0;
    for (final doc in receivingsDocs.docs) {
      final data = doc.data();
      final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
      if (createdAt != null && (createdAt.isBefore(start) || createdAt.isAfter(end))) continue;
      chickensReceived += (data['totalChickens'] as num? ?? 0).toInt();
      kgReceived += (data['totalWeightKg'] as num? ?? 0).toDouble();
    }

    final butcheringDocs = await db
        .collection('businesses').doc(businessId)
        .collection('butchering')
        .where('storeId', isEqualTo: storeId)
        .get();
    int chickensButchered = 0;
    double kgButchered = 0;
    double butcherMermaKg = 0;
    for (final doc in butcheringDocs.docs) {
      final data = doc.data();
      final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
      if (createdAt != null && (createdAt.isBefore(start) || createdAt.isAfter(end))) continue;
      chickensButchered += (data['chickenCount'] as num? ?? 0).toInt();
      kgButchered += (data['exactWeightKg'] as num? ?? 0).toDouble();
      butcherMermaKg += (data['mermaKg'] as num? ?? 0).toDouble();
    }

    final transfersDocs = await db
        .collection('businesses').doc(businessId)
        .collection('transfers')
        .get();
    int transfersSent = 0;
    int transfersReceived = 0;
    for (final doc in transfersDocs.docs) {
      final data = doc.data();
      final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
      if (createdAt != null && (createdAt.isBefore(start) || createdAt.isAfter(end))) continue;
      if (data['fromStoreId'] == storeId) transfersSent++;
      if (data['toStoreId'] == storeId) transfersReceived++;
    }

    return PoultryMovementData(
      chickensReceived: chickensReceived,
      kgReceived: kgReceived,
      chickensButchered: chickensButchered,
      kgButchered: kgButchered,
      butcherMermaKg: butcherMermaKg,
      transfersSent: transfersSent,
      transfersReceived: transfersReceived,
    );
  }
}

class PoultryMovementData {
  const PoultryMovementData({
    required this.chickensReceived,
    required this.kgReceived,
    required this.chickensButchered,
    required this.kgButchered,
    required this.butcherMermaKg,
    required this.transfersSent,
    required this.transfersReceived,
  });

  final int chickensReceived;
  final double kgReceived;
  final int chickensButchered;
  final double kgButchered;
  final double butcherMermaKg;
  final int transfersSent;
  final int transfersReceived;
}
