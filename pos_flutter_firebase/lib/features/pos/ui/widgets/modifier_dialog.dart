import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:pos_flutter_firebase/shared/models/cart_item.dart';
import 'package:pos_flutter_firebase/shared/models/discount.dart';
import 'package:pos_flutter_firebase/shared/models/modifier.dart';
import 'package:pos_flutter_firebase/features/pos/domain/discount_repository.dart';
import 'package:pos_flutter_firebase/features/pos/domain/modifier_repository.dart';

class ModifierSelectionDialog extends StatefulWidget {
  const ModifierSelectionDialog({
    super.key,
    required this.businessId,
    required this.currentModifiers,
    required this.currentDiscount,
    required this.itemPrice,
  });

  final String businessId;
  final List<SelectedModifier> currentModifiers;
  final double currentDiscount;
  final double itemPrice;

  @override
  State<ModifierSelectionDialog> createState() => _ModifierSelectionDialogState();
}

class _ModifierSelectionDialogState extends State<ModifierSelectionDialog> {
  ModifierRepository get _modifierService => context.read<ModifierRepository>();
  DiscountRepository get _discountService => context.read<DiscountRepository>();
  late Set<String> _selectedIds;
  final _allModifiers = <Modifier>[];
  bool _loaded = false;
  double _selectedDiscount = 0;
  String? _selectedDiscountName;

  @override
  void initState() {
    super.initState();
    _selectedIds = widget.currentModifiers.map((m) => m.id).toSet();
    _selectedDiscount = widget.currentDiscount;
  }

  void _applyDiscount(Discount discount, double itemPrice) {
    final amount = discount.isPercentage
        ? itemPrice * (discount.value / 100)
        : discount.value > itemPrice ? itemPrice : discount.value;
    setState(() {
      _selectedDiscount = amount;
      _selectedDiscountName = discount.name;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Personalizar producto'),
      content: SizedBox(
        width: 400,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Modificadores', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 4),
              _modifiersSection(),
              const Divider(),
              _discountSection(context),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        FilledButton(
          onPressed: () {
            final modifiers = _allModifiers
                .where((m) => _selectedIds.contains(m.id))
                .map((m) => SelectedModifier(id: m.id, name: m.name, price: m.price))
                .toList();
            Navigator.pop(context, (modifiers: modifiers, discount: _selectedDiscount));
          },
          child: const Text('Aceptar'),
        ),
      ],
    );
  }

  Widget _modifiersSection() {
    return StreamBuilder<List<Modifier>>(
      stream: _modifierService.watchModifiers(businessId: widget.businessId),
      builder: (context, snapshot) {
        final modifiers = snapshot.data ?? const <Modifier>[];
        if (!_loaded && modifiers.isNotEmpty) {
          _allModifiers
            ..clear()
            ..addAll(modifiers);
          _loaded = true;
        }
        if (modifiers.isEmpty) {
          return const Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: Text('No hay modificadores configurados.', style: TextStyle(color: Colors.grey)),
          );
        }
        return Column(
          children: modifiers.map((modifier) {
            final selected = _selectedIds.contains(modifier.id);
            return CheckboxListTile(
              dense: true,
              value: selected,
              title: Text(modifier.name),
              subtitle: Text(modifier.price == 0 ? 'Sin costo extra' : '+\$${modifier.price.toStringAsFixed(2)}'),
              onChanged: (checked) {
                setState(() {
                  if (checked == true) {
                    _selectedIds.add(modifier.id);
                  } else {
                    _selectedIds.remove(modifier.id);
                  }
                });
              },
            );
          }).toList(),
        );
      },
    );
  }

  Widget _discountSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('Descuento', style: Theme.of(context).textTheme.titleSmall),
            if (_selectedDiscount > 0) ...[
              const SizedBox(width: 8),
              Chip(
                label: Text('-\$${_selectedDiscount.toStringAsFixed(2)}', style: const TextStyle(fontSize: 12)),
                deleteIcon: const Icon(Icons.close, size: 16),
                onDeleted: () => setState(() {
                  _selectedDiscount = 0;
                  _selectedDiscountName = null;
                }),
              ),
            ],
          ],
        ),
        if (_selectedDiscount > 0 && _selectedDiscountName != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text('($_selectedDiscountName)', style: const TextStyle(color: Colors.grey, fontSize: 12)),
          ),
        StreamBuilder<List<Discount>>(
          stream: _discountService.watchDiscounts(businessId: widget.businessId),
          builder: (context, snapshot) {
            final discounts = snapshot.data ?? const <Discount>[];
            if (discounts.isEmpty) {
              return const Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: Text('No hay descuentos configurados.', style: TextStyle(color: Colors.grey)),
              );
            }
            return Column(
              children: discounts.map((d) {
                final displayAmount = d.isPercentage
                    ? '${d.value.toStringAsFixed(0)}% (-${(widget.itemPrice * d.value / 100).toStringAsFixed(2)})'
                    : '-\$${d.value.toStringAsFixed(2)}';
                return ListTile(
                  dense: true,
                  leading: Icon(Icons.discount, color: _selectedDiscountName == d.name ? Colors.orange : null),
                  title: Text(d.name),
                  subtitle: Text(displayAmount),
                  onTap: () => _applyDiscount(d, widget.itemPrice),
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }
}


