import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'package:pos_flutter_firebase/shared/models/cart_item.dart';
import 'package:pos_flutter_firebase/shared/models/product.dart';
import 'package:pos_flutter_firebase/shared/models/product_stock.dart';
import 'package:pos_flutter_firebase/features/products/domain/product_repository.dart';
import 'package:pos_flutter_firebase/features/inventory/domain/stock_repository.dart';

/// Diálogo para registrar el intercambio de piezas al vender pollo entero.
///
/// Para cada pieza se define un peso de ENTREGA (resta stock) y un peso de
/// DEVOLUCIÓN (suma stock), que pueden ser diferentes. Cada uno genera un
/// intercambio y su movimiento de inventario correspondiente.
class PieceSwapDialog extends StatefulWidget {
  const PieceSwapDialog({
    super.key,
    required this.businessId,
    required this.storeId,
    required this.wholeProductId,
    this.initialSwaps = const [],
  });

  final String businessId;
  final String storeId;
  final String? wholeProductId;
  final List<PieceSwap> initialSwaps;

  @override
  State<PieceSwapDialog> createState() => _PieceSwapDialogState();
}

class _SwapEntry {
  _SwapEntry({this.productId, this.outWeight, this.inWeight});

  final String? productId;
  Product? product;
  double? outWeight;
  double? inWeight;
  final TextEditingController outCtrl = TextEditingController();
  final TextEditingController inCtrl = TextEditingController();

  void dispose() {
    outCtrl.dispose();
    inCtrl.dispose();
  }
}

class _PieceSwapDialogState extends State<PieceSwapDialog> {
  late final List<_SwapEntry> _entries;

  @override
  void initState() {
    super.initState();
    _entries = [];
    if (widget.initialSwaps.isNotEmpty) {
      final byProduct = <String, List<PieceSwap>>{};
      for (final swap in widget.initialSwaps) {
        byProduct.putIfAbsent(swap.productId, () => []).add(swap);
      }
      for (final group in byProduct.values) {
        final entry = _SwapEntry(productId: group.first.productId);
        for (final swap in group) {
          if (swap.direction == 'out') {
            entry.outWeight = swap.weight;
            entry.outCtrl.text = _fmtWeight(swap.weight);
          } else {
            entry.inWeight = swap.weight;
            entry.inCtrl.text = _fmtWeight(swap.weight);
          }
        }
        _entries.add(entry);
      }
    } else {
      _addRow();
    }
  }

  String _fmtWeight(double value) => value == value.roundToDouble()
      ? value.toStringAsFixed(0)
      : value.toStringAsFixed(3).replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '');

  @override
  void dispose() {
    for (final entry in _entries) {
      entry.dispose();
    }
    super.dispose();
  }

  void _addRow() {
    setState(() => _entries.add(_SwapEntry()));
  }

  void _removeRow(int index) {
    setState(() => _entries.removeAt(index).dispose());
  }

  void _resolveInitialProducts(List<Product> products) {
    final byId = {for (final p in products) p.id: p};
    for (final entry in _entries) {
      if (entry.product != null || entry.productId == null) continue;
      entry.product = byId[entry.productId];
    }
  }

  double _availableStock(Map<String, ProductStock> stocks, Product product) {
    return stocks[product.id]?.stockQuantity ?? 0;
  }

  void _confirm(List<Product> products, Map<String, ProductStock> stocks) {
    final swaps = <PieceSwap>[];
    for (final entry in _entries) {
      final product = entry.product;
      if (product == null) continue;
      final out = entry.outWeight ?? 0;
      final back = entry.inWeight ?? 0;
      if (out > 0) {
        swaps.add(PieceSwap(
          productId: product.id,
          productName: product.name,
          weight: out,
          direction: 'out',
        ));
      }
      if (back > 0) {
        swaps.add(PieceSwap(
          productId: product.id,
          productName: product.name,
          weight: back,
          direction: 'in',
        ));
      }
    }

    if (swaps.isEmpty) {
      Navigator.pop(context, swaps);
      return;
    }

    final stockByProduct = <String, double>{};
    for (final entry in _entries) {
      if (entry.product == null) continue;
      stockByProduct[entry.product!.id] =
          (stockByProduct[entry.product!.id] ?? 0) + (entry.outWeight ?? 0);
    }
    for (final MapEntry(key: id, value: needed) in stockByProduct.entries) {
      final product = products.firstWhere((p) => p.id == id);
      final available = _availableStock(stocks, product);
      if (needed > available + 0.000001) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Stock insuficiente de ${product.name}: disponible ${_fmtWeight(available)} kg')),
        );
        return;
      }
    }

    Navigator.pop(context, swaps);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Intercambio de piezas'),
      contentPadding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      content: SizedBox(
        width: 620,
        height: MediaQuery.of(context).size.height * 0.72,
        child: StreamBuilder<List<Product>>(
          stream: context.read<ProductRepository>().watchProducts(businessId: widget.businessId),
          builder: (context, productsSnapshot) {
            if (productsSnapshot.connectionState == ConnectionState.waiting && !productsSnapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            if (productsSnapshot.hasError) {
              return Center(child: Text('Error: ${productsSnapshot.error}'));
            }
            return StreamBuilder<Map<String, ProductStock>>(
              stream: context.read<StockRepository>().watchStockByStore(
                businessId: widget.businessId,
                storeId: widget.storeId,
              ),
              builder: (context, stockSnapshot) {
                final stocks = stockSnapshot.data ?? const <String, ProductStock>{};
                final products = (productsSnapshot.data ?? const <Product>[])
                    .where((p) => p.active && p.trackStock && p.id != widget.wholeProductId)
                    .toList()
                  ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
                if (widget.initialSwaps.isNotEmpty && _entries.any((e) => e.product == null)) {
                  _resolveInitialProducts(products);
                }
                return _buildContent(products, stocks);
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildContent(List<Product> products, Map<String, ProductStock> stocks) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Por cada pieza define el peso que ENTREGAS al cliente (resta del stock) '
          'y el peso que el cliente DEVUELVE (suma al stock). Pueden ser diferentes.',
          style: TextStyle(color: Colors.black54, fontSize: 13),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: products.isEmpty
              ? const Center(child: Text('No hay productos para intercambiar'))
              : ListView.separated(
                  itemCount: _entries.length,
                  separatorBuilder: (_, _) => const Divider(height: 16),
                  itemBuilder: (context, index) => _buildRow(products, stocks, index),
                ),
        ),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: _addRow,
            icon: const Icon(Icons.add),
            label: const Text('Agregar pieza'),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton(
              onPressed: () => Navigator.pop(context, null),
              child: const Text('Cancelar'),
            ),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: () => _confirm(products, stocks),
              child: const Text('Aceptar'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildRow(List<Product> products, Map<String, ProductStock> stocks, int index) {
    final entry = _entries[index];
    final available = entry.product == null
        ? null
        : _availableStock(stocks, entry.product!);
    final stockText = entry.product == null
        ? ''
        : 'Stock: ${_fmtWeight(available!)} kg';

    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 2,
              child: DropdownButtonFormField<Product>(
                initialValue: entry.product,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: 'Pieza',
                  isDense: true,
                  helperText: stockText,
                  border: const OutlineInputBorder(),
                ),
                items: products.map((p) => DropdownMenuItem(value: p, child: Text(p.name, overflow: TextOverflow.ellipsis))).toList(),
                onChanged: (value) => setState(() => entry.product = value),
              ),
            ),
            IconButton(
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.remove_circle_outline, color: Colors.redAccent),
              onPressed: () => _removeRow(index),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: entry.outCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
                decoration: const InputDecoration(
                  labelText: 'Entrega kg',
                  isDense: true,
                  border: OutlineInputBorder(),
                ),
                onChanged: (value) => entry.outWeight = double.tryParse(value),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: entry.inCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
                decoration: const InputDecoration(
                  labelText: 'Devuelve kg',
                  isDense: true,
                  border: OutlineInputBorder(),
                ),
                onChanged: (value) => entry.inWeight = double.tryParse(value),
              ),
            ),
          ],
        ),
      ],
    );
  }
}