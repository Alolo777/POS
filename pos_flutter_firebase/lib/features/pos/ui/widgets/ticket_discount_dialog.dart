import 'package:flutter/material.dart';

import 'package:pos_flutter_firebase/shared/models/discount.dart';
import 'package:pos_flutter_firebase/features/pos/data/discount_service.dart';

typedef TicketDiscountSelection = ({
  String id,
  String name,
  String type,
  double value,
  double amount,
});

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

  TicketDiscountSelection _apply(Discount discount) {
    if (discount.isPercentage) {
      return (
        id: discount.id,
        name: discount.name,
        type: discount.type,
        value: discount.value,
        amount: widget.subtotal * (discount.value / 100),
      );
    }
    return (
      id: discount.id,
      name: discount.name,
      type: discount.type,
      value: discount.value,
      amount: discount.value > widget.subtotal ? widget.subtotal : discount.value,
    );
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
                    onPressed: () => Navigator.pop(context, (
                      id: '',
                      name: 'Sin descuento',
                      type: '',
                      value: 0,
                      amount: 0.0,
                    )),
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


