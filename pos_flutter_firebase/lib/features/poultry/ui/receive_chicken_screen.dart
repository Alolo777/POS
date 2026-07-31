import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../shared/models/employee.dart';
import '../domain/poultry_repository.dart';
import '../domain/chicken_receiving.dart';

class ReceiveChickenScreen extends StatefulWidget {
  const ReceiveChickenScreen({
    super.key,
    required this.businessId,
    required this.storeId,
    required this.employee,
  });

  final String businessId;
  final String storeId;
  final Employee employee;

  @override
  State<ReceiveChickenScreen> createState() => _ReceiveChickenScreenState();
}

class _ReceiveChickenScreenState extends State<ReceiveChickenScreen> {
  final _chickenCountCtrl = TextEditingController();
  final _totalWeightCtrl = TextEditingController();
  bool _saving = false;

  void _resetForm() {
    _chickenCountCtrl.clear();
    _totalWeightCtrl.clear();
  }

  Future<void> _save() async {
    final totalChickens = int.tryParse(_chickenCountCtrl.text) ?? 0;
    final totalWeight =
        double.tryParse(_totalWeightCtrl.text.replaceAll(',', '.')) ?? 0;

    if (totalChickens <= 0 || totalWeight <= 0) {
      _showError('Ingresa cantidad y peso total');
      return;
    }

    setState(() => _saving = true);

    final avgWeight = totalWeight / totalChickens;

    final receiving = ChickenReceiving(
      businessId: widget.businessId,
      storeId: widget.storeId,
      employeeId: widget.employee.id,
      employeeName: widget.employee.name,
      createdAt: DateTime.now(),
      totalChickens: totalChickens,
      totalWeightKg: totalWeight,
      avgWeightKg: avgWeight,
    );

    try {
      final repo = context.read<PoultryRepository>();
      await repo.saveReceiving(widget.businessId, receiving);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Recepción guardada correctamente')),
      );
      _resetForm();
    } catch (e) {
      if (!mounted) return;
      _showError('Error al guardar: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  void dispose() {
    _chickenCountCtrl.dispose();
    _totalWeightCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Recibir Pollo')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _chickenCountCtrl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Cantidad de pollos recibidos',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _totalWeightCtrl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Peso total (kg)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _saving ? null : _save,
            icon: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save),
            label: Text(_saving ? 'Guardando...' : 'Guardar recepción'),
          ),
        ],
      ),
    );
  }
}
