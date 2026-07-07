import 'package:flutter/material.dart';

import '../../models/discount.dart';
import '../../services/discount_service.dart';

class TicketDiscountDialog extends StatefulWidget {
  const TicketDiscountDialog({
    super.key,
    required this.businessId,
    required this.currentDiscount,
    required this.subtotal,
  });

  final String businessId;
  final double currentDiscount;
  final double subtotal;

  @override
  State<TicketDiscountDialog> createState() => _TicketDiscountDialogState();
}

class _TicketDiscountDialogState extends State<TicketDiscountDialog> {
  final _discountService = DiscountService();

  ({String name, double amount}) _apply(Discount discount) {
    if (discount.isPercentage) {
      return (name: discount.name, amount: widget.subtotal * (discount.value / 100));
    }
    return (name: discount.name, amount: discount.value > widget.subtotal ? widget.subtotal : discount.value);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Descuento al ticket'),
      content: SizedBox(
        width: 400,
        child: StreamBuilder<List<Discount>>(
          stream: _discountService.watchDiscounts(businessId: widget.businessId),
          builder: (context, snapshot) {
            final discounts = snapshot.data ?? const <Discount>[];

            if (widget.currentDiscount > 0) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('Descuento actual aplicado.'),
                  const SizedBox(height: 8),
                  Text('Descuento: \$${widget.currentDiscount.toStringAsFixed(2)}'),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: () => Navigator.pop(context, (name: 'Sin descuento', amount: 0.0)),
                    child: const Text('Quitar descuento'),
                  ),
                ],
              );
            }

            if (discounts.isEmpty) {
              return const Text('No hay descuentos configurados. Crearlos en Productos > Descuentos.');
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Subtotal actual: \$${widget.subtotal.toStringAsFixed(2)}'),
                const SizedBox(height: 8),
                Expanded(
                  child: ListView(
                    shrinkWrap: true,
                    children: discounts.map((discount) {
                      final applied = _apply(discount);
                      return ListTile(
                        leading: const Icon(Icons.discount),
                        title: Text(discount.name),
                        subtitle: Text(discount.isPercentage
                            ? '${discount.value.toStringAsFixed(0)}% (-\$${applied.amount.toStringAsFixed(2)})'
                            : '-\$${discount.value.toStringAsFixed(2)}'),
                        onTap: () => Navigator.pop(context, applied),
                      );
                    }).toList(),
                  ),
                ),
              ],
            );
          },
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
      ],
    );
  }
}
