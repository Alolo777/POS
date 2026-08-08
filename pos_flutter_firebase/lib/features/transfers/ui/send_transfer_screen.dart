import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../shared/models/employee.dart';
import '../../../shared/models/product.dart';
import '../../../shared/models/product_stock.dart';
import '../../../shared/models/store.dart';
import '../../../shared/providers/app_session_notifier.dart';
import '../../products/domain/product_repository.dart';
import '../../inventory/domain/stock_repository.dart';
import '../domain/transfer_repository.dart';
import '../domain/transfer.dart';
import '../domain/transfer_item.dart';

class SendTransferScreen extends StatefulWidget {
  const SendTransferScreen({
    super.key,
    required this.businessId,
    required this.fromStore,
    required this.employee,
    this.onTransferSent,
  });

  final String businessId;
  final Store fromStore;
  final Employee employee;
  final VoidCallback? onTransferSent;

  @override
  State<SendTransferScreen> createState() => _SendTransferScreenState();
}

class _SendTransferScreenState extends State<SendTransferScreen> {
  Store? _selectedStore;
  final _items = <_TransferItemEntry>[];
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final session = context.read<AppSessionNotifier>().session;
    if (session != null && mounted) {
      setState(() => _loading = false);
    }
  }

  void _addItem(Product product, ProductStock stock) {
    setState(() {
      _items.add(_TransferItemEntry(
        product: product,
        stock: stock,
        quantityCtrl: TextEditingController(),
      ));
    });
  }

  void _removeItem(int index) {
    setState(() {
      _items[index].quantityCtrl.dispose();
      _items.removeAt(index);
    });
  }

  Future<void> _send() async {
    if (_selectedStore == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Selecciona sucursal destino')));
      return;
    }
    if (_items.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Agrega al menos un producto')));
      return;
    }

    final items = <TransferItem>[];
    for (final e in _items) {
      final qty = double.tryParse(e.quantityCtrl.text.replaceAll(',', '.')) ?? 0;
      if (qty <= 0) continue;
      if (qty > e.stock.stockQuantity) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Stock insuficiente de ${e.product.name}: disponible ${e.stock.stockQuantity.toStringAsFixed(2)}')),
        );
        return;
      }
      items.add(TransferItem(
        productId: e.product.id,
        productName: e.product.name,
        sentQuantity: qty,
      ));
    }

    if (items.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Ingresa cantidades mayores a 0')));
      return;
    }

    setState(() => _saving = true);

    final transfer = Transfer(
      businessId: widget.businessId,
      fromStoreId: widget.fromStore.id,
      fromStoreName: widget.fromStore.name,
      toStoreId: _selectedStore!.id,
      toStoreName: _selectedStore!.name,
      fromEmployeeId: widget.employee.id,
      items: items,
      createdAt: DateTime.now(),
    );

    try {
      final repo = context.read<TransferRepository>();
      await repo.sendTransfer(widget.businessId, transfer);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Transferencia enviada')),
      );
      widget.onTransferSent?.call();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    for (final e in _items) {
      e.quantityCtrl.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<AppSessionNotifier>().session;
    final stores = session?.stores.where((s) => s.id != widget.fromStore.id).toList() ?? [];

    final productsProvider = context.watch<ProductRepository>();
    final stockProvider = context.watch<StockRepository>();
    final allStock = stockProvider.getCachedStock(widget.businessId) ?? {};
    final allProducts = productsProvider.getCachedProducts(widget.businessId) ?? [];

    final storeProducts = allProducts
        .where((p) => p.trackStock)
        .map((p) => MapEntry(p, allStock[p.id]))
        .where((e) => e.value != null)
        .toList();

    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Enviar mercancía')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          DropdownButtonFormField<Store>(
            initialValue: _selectedStore,
            decoration: const InputDecoration(
              labelText: 'Sucursal destino',
              border: OutlineInputBorder(),
            ),
            items: stores
                .map((s) => DropdownMenuItem(value: s, child: Text(s.name)))
                .toList(),
            onChanged: (s) => setState(() => _selectedStore = s),
          ),
          const SizedBox(height: 20),
          Text('Agregar productos',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          ...storeProducts.take(20).map((e) {
            final product = e.key;
            final stock = e.value!;
            final added = _items.any((i) => i.product.id == product.id);
            if (added) return const SizedBox.shrink();
            return Card(
              child: ListTile(
                title: Text(product.name),
                subtitle: Text('Stock: ${stock.stockQuantity.toStringAsFixed(2)}'),
                trailing: FilledButton.tonal(
                  onPressed: () => _addItem(product, stock),
                  child: const Text('Agregar'),
                ),
              ),
            );
          }),
          if (_items.isNotEmpty) ...[
            const SizedBox(height: 20),
            Text('Productos a enviar',
                style: Theme.of(context).textTheme.titleMedium),
            ..._items.asMap().entries.map((entry) {
              final idx = entry.key;
              final e = entry.value;
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(e.product.name,
                                style: const TextStyle(fontWeight: FontWeight.bold)),
                            Text('Stock: ${e.stock.stockQuantity.toStringAsFixed(2)}'),
                          ],
                        ),
                      ),
                      SizedBox(
                        width: 100,
                        child: TextField(
                          controller: e.quantityCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            isDense: true,
                            labelText: 'Cant.',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () => _removeItem(idx),
                      ),
                    ],
                  ),
                ),
              );
            }),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _saving ? null : _send,
              icon: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.send),
              label: Text(_saving ? 'Enviando...' : 'Enviar transferencia'),
            ),
          ],
        ],
      ),
    );
  }
}

class _TransferItemEntry {
  final Product product;
  final ProductStock stock;
  final TextEditingController quantityCtrl;

  _TransferItemEntry({
    required this.product,
    required this.stock,
    required this.quantityCtrl,
  });
}
