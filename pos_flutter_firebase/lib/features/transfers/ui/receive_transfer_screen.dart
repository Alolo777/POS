import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../shared/models/employee.dart';
import '../../../shared/models/store.dart';
import '../../../shared/providers/app_session_notifier.dart';
import '../domain/transfer_repository.dart';
import '../domain/transfer.dart';
import '../domain/transfer_item.dart';

class ReceiveTransferScreen extends StatefulWidget {
  const ReceiveTransferScreen({
    super.key,
    required this.businessId,
    required this.storeId,
    required this.employee,
  });

  final String businessId;
  final String storeId;
  final Employee employee;

  @override
  State<ReceiveTransferScreen> createState() => _ReceiveTransferScreenState();
}

class _ReceiveTransferScreenState extends State<ReceiveTransferScreen> {
  late final Stream<List<Transfer>> _transfers;

  @override
  void initState() {
    super.initState();
    final repo = context.read<TransferRepository>();
    _transfers = repo.watchReceivedTransfers(widget.businessId, widget.storeId);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Recibir mercancía')),
      body: StreamBuilder<List<Transfer>>(
        stream: _transfers,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final list = snapshot.data ?? <Transfer>[];
          if (list.isEmpty) {
            return const Center(child: Text('Sin transferencias pendientes'));
          }
          return ListView.builder(
            itemCount: list.length,
            itemBuilder: (context, index) {
              final transfer = list[index];
              return _TransferCard(
                transfer: transfer,
                onConfirm: () => _confirmTransfer(transfer),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _confirmTransfer(Transfer transfer) async {
    final items = transfer.items.map((item) {
      final ctrl = TextEditingController(
        text: item.sentQuantity.toStringAsFixed(2),
      );
      return _ConfirmItem(item: item, ctrl: ctrl);
    }).toList();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Confirmar recepción'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Ajusta las cantidades recibidas:'),
                const SizedBox(height: 12),
                ...items.map((e) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(e.item.productName),
                          ),
                          SizedBox(
                            width: 100,
                            child: TextField(
                              controller: e.ctrl,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                isDense: true,
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                        ],
                      ),
                    )),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Confirmar'),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true || !mounted) return;

    final updatedItems = items.map((e) {
      final qty =
          double.tryParse(e.ctrl.text.replaceAll(',', '.')) ?? e.item.sentQuantity;
      return TransferItem(
        productId: e.item.productId,
        productName: e.item.productName,
        sentQuantity: e.item.sentQuantity,
        confirmedQuantity: qty,
      );
    }).toList();

    try {
      final repo = context.read<TransferRepository>();
      await repo.confirmTransfer(
        widget.businessId,
        transfer.id!,
        updatedItems,
        widget.employee.id,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Recepción confirmada')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }
}

class _TransferCard extends StatelessWidget {
  final Transfer transfer;
  final VoidCallback onConfirm;

  const _TransferCard({required this.transfer, required this.onConfirm});

  @override
  Widget build(BuildContext context) {
    final stores = context.watch<AppSessionNotifier>().session?.stores ?? const <Store>[];
    String storeName(String? id) => stores.firstWhere((s) => s.id == id, orElse: () => const Store(id: '', name: '', address: '', phone: '', active: false)).name;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Envío de ${transfer.fromStoreName?.isNotEmpty == true ? transfer.fromStoreName : storeName(transfer.fromStoreId)}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            Text(
              'Para: ${transfer.toStoreName?.isNotEmpty == true ? transfer.toStoreName : storeName(transfer.toStoreId)}',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            Text('Artículos: ${transfer.items.length}'),
            ...transfer.items.map((item) => Text(
                  '  • ${item.productName}: ${item.sentQuantity.toStringAsFixed(2)}',
                )),
            const SizedBox(height: 8),
            if (transfer.isSent)
              FilledButton(
                onPressed: onConfirm,
                child: const Text('Confirmar recepción'),
              )
            else
              Chip(
                label: Text(transfer.status.toUpperCase()),
                backgroundColor: Colors.green.shade100,
              ),
          ],
        ),
      ),
    );
  }
}

class _ConfirmItem {
  final TransferItem item;
  final TextEditingController ctrl;

  _ConfirmItem({required this.item, required this.ctrl});
}
