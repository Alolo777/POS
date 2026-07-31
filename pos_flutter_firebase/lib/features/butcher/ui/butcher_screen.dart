import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../shared/models/employee.dart';
import '../../../shared/models/store.dart';
import '../../../shared/models/butcher_section.dart';
import '../../../shared/models/product_stock.dart';
import '../../../core/theme/glass_container.dart';
import '../../../core/theme/glass_theme.dart';
import '../../inventory/domain/stock_repository.dart';
import '../../poultry/domain/poultry_repository.dart';
import '../domain/butcher_repository.dart';
import '../domain/butcher_record.dart';

class ButcherScreen extends StatefulWidget {
  const ButcherScreen({
    super.key,
    required this.businessId,
    required this.store,
    required this.employee,
  });

  final String businessId;
  final Store store;
  final Employee employee;

  @override
  State<ButcherScreen> createState() => _ButcherScreenState();
}

class _SectionCtrl {
  final ButcherSection section;
  final double expectedKg;
  final TextEditingController controller;

  _SectionCtrl({
    required this.section,
    required this.expectedKg,
    required this.controller,
  });
}

class _ButcherScreenState extends State<ButcherScreen> {
  final _chickenCountCtrl = TextEditingController();
  final _exactWeightCtrl = TextEditingController();
  final List<_SectionCtrl> _sectionCtrls = [];

  bool _loadingConfig = true;
  String? _wholeProductId;
  double _wholeStockKg = 0;
  int _wholeStockCount = 0;
  List<ButcherSection> _recipe = [];
  bool _saving = false;
  StreamSubscription<Map<String, ProductStock>>? _stockSub;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    try {
      final poultryRepo = context.read<PoultryRepository>();
      final butcherRepo = context.read<ButcherRepository>();

      final config = await poultryRepo.getConfig(widget.businessId);
      final recipe = await butcherRepo.getRecipe(widget.businessId);

      if (!mounted) return;
      setState(() {
        _recipe = recipe;
        _loadingConfig = false;
        if (config != null) _wholeProductId = config.wholeProductId;
      });

      // Ensure recipe exists; if empty, create defaults
      if (_recipe.isEmpty) {
        final defaults = ButcherSection.defaults;
        await butcherRepo.saveRecipe(
          businessId: widget.businessId,
          sections: defaults,
        );
        if (!mounted) return;
        setState(() => _recipe = defaults);
      }

      if (_wholeProductId != null) {
        final stockRepo = context.read<StockRepository>();
        _stockSub = stockRepo
            .watchStockByStore(
              businessId: widget.businessId,
              storeId: widget.store.id,
            )
            .listen((stockMap) {
          if (!mounted) return;
          final wholeStock = stockMap[_wholeProductId];
          if (wholeStock != null) {
            setState(() {
              _wholeStockKg = wholeStock.stockQuantity;
              _wholeStockCount = wholeStock.chickenCount ?? 0;
            });
          }
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadingConfig = false);
      _showError('Error al cargar: $e');
    }
  }

  void _resetForm() {
    _chickenCountCtrl.clear();
    _exactWeightCtrl.clear();
    for (final s in _sectionCtrls) {
      s.controller.dispose();
    }
    _sectionCtrls.clear();
    setState(() {});
  }

  void _calculate() {
    final count = int.tryParse(_chickenCountCtrl.text) ?? 0;
    final weight =
        double.tryParse(_exactWeightCtrl.text.replaceAll(',', '.')) ?? 0;

    if (count <= 0 || weight <= 0 || _recipe.isEmpty) return;

    for (final s in _sectionCtrls) {
      s.controller.dispose();
    }
    _sectionCtrls.clear();

    for (final section in _recipe) {
      if (section.percentage <= 0) continue;
      final expectedKg = weight * section.percentage;
      _sectionCtrls.add(_SectionCtrl(
        section: section,
        expectedKg: expectedKg,
        controller: TextEditingController(
          text: expectedKg.toStringAsFixed(2),
        ),
      ));
    }

    setState(() {});
  }

  Future<void> _save() async {
    final count = int.tryParse(_chickenCountCtrl.text) ?? 0;
    final weight =
        double.tryParse(_exactWeightCtrl.text.replaceAll(',', '.')) ?? 0;

    if (count <= 0 || weight <= 0) {
      _showError('Ingresa cantidad y peso de los pollos a destazar');
      return;
    }
    if (count > _wholeStockCount) {
      _showError(
        'No hay suficientes pollos. '
        'Disponibles: $_wholeStockCount pollos',
      );
      return;
    }
    if (weight > _wholeStockKg) {
      _showError(
        'No hay suficiente peso de pollo entero. '
        'Disponible: ${_wholeStockKg.toStringAsFixed(2)} kg',
      );
      return;
    }
    if (_wholeProductId == null) {
      _showError('No se encontró la configuración de pollo entero');
      return;
    }

    final sections = _sectionCtrls.map((s) {
      final actual =
          double.tryParse(s.controller.text.replaceAll(',', '.')) ?? 0;
      return ButcherSectionResult(
        sectionName: s.section.name,
        percentage: s.section.percentage * 100,
        expectedKg: s.expectedKg,
        actualKg: actual,
      );
    }).toList();

    setState(() => _saving = true);

    try {
      final butcherRepo = context.read<ButcherRepository>();
      await butcherRepo.registerButchering(
        businessId: widget.businessId,
        storeId: widget.store.id,
        employeeId: widget.employee.id,
        employeeName: widget.employee.name,
        chickenCount: count,
        exactWeightKg: weight,
        wholeProductId: _wholeProductId!,
        sections: sections,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Destazado registrado correctamente')),
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
    _exactWeightCtrl.dispose();
    for (final s in _sectionCtrls) {
      s.controller.dispose();
    }
    _stockSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Destazar Pollos'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _resetForm,
            tooltip: 'Nuevo destazado',
          ),
        ],
      ),
      body: _loadingConfig
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildStockCard(isDark),
                const SizedBox(height: 16),
                _buildFormCard(isDark),
                if (_sectionCtrls.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  _buildSectionsCard(isDark),
                  const SizedBox(height: 16),
                  _buildMermaCard(isDark),
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    onPressed: _saving ? null : _save,
                    icon: _saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child:
                                CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.save),
                    label:
                        Text(_saving ? 'Guardando...' : 'Registrar destazado'),
                  ),
                ],
              ],
            ),
    );
  }

  Widget _buildStockCard(bool isDark) {
    return GlassContainer(
      padding: const EdgeInsets.all(16),
      borderRadius: 0,
      blur: 10,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: GlassColors.accent.withValues(alpha: 0.15),
              borderRadius: BorderRadius.zero,
            ),
            child: const Icon(Icons.inventory_2,
                size: 22, color: GlassColors.accent),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Pollo Entero Disponible',
                  style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14)),
              Text(
                '${_wholeStockKg.toStringAsFixed(2)} kg',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : Colors.grey[900],
                ),
              ),
              if (_wholeStockCount > 0)
                Text('$_wholeStockCount pollos',
                    style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[500])),
            ],
          ),
        ],
      ),
    ).withFadeIn();
  }

  Widget _buildFormCard(bool isDark) {
    return GlassContainer(
      padding: const EdgeInsets.all(16),
      borderRadius: 0,
      blur: 10,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Registrar destazado',
              style: TextStyle(
                  fontWeight: FontWeight.w700, fontSize: 16)),
          const SizedBox(height: 4),
          Text('Ingresa los pollos que se destazaron y su peso exacto',
              style: TextStyle(fontSize: 12, color: Colors.grey[500])),
          const SizedBox(height: 16),
          TextField(
            controller: _chickenCountCtrl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Pollos destazados',
              border: OutlineInputBorder(),
            ),
            onChanged: (_) => _calculate(),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _exactWeightCtrl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Peso exacto (kg)',
              border: OutlineInputBorder(),
              hintText: 'Pesa los pollos y registra su peso',
            ),
            onChanged: (_) => _calculate(),
          ),
        ],
      ),
    ).withFadeIn();
  }

  Widget _buildSectionsCard(bool isDark) {
    final totalActual = _sectionCtrls.fold<double>(
        0, (sum, s) => sum + (double.tryParse(s.controller.text.replaceAll(',', '.')) ?? 0));

    return GlassContainer(
      padding: const EdgeInsets.all(16),
      borderRadius: 0,
      blur: 10,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('Secciones',
                  style: TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 16)),
              const Spacer(),
              Text('Total real: ${totalActual.toStringAsFixed(2)} kg',
                  style: TextStyle(fontSize: 12, color: Colors.grey[500])),
            ],
          ),
          const SizedBox(height: 12),
          ..._sectionCtrls.map((s) {
            final actual =
                double.tryParse(s.controller.text.replaceAll(',', '.')) ?? 0;
            final deviation = s.expectedKg > 0
                ? ((actual - s.expectedKg) / s.expectedKg * 100)
                : 0.0;

            return Card(
              margin: const EdgeInsets.symmetric(vertical: 4),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(s.section.name,
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold)),
                          Text(
                            'Esperado: ${s.expectedKg.toStringAsFixed(2)} kg '
                            '(${(s.section.percentage * 100).toStringAsFixed(1)}%)',
                            style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600]),
                          ),
                          if (deviation.abs() > 5)
                            Text(
                              '${deviation.toStringAsFixed(1)}%',
                              style: const TextStyle(
                                  color: Colors.orange,
                                  fontSize: 12),
                            ),
                        ],
                      ),
                    ),
                    SizedBox(
                      width: 120,
                      child: TextField(
                        controller: s.controller,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          isDense: true,
                          labelText: 'Real (kg)',
                          border: OutlineInputBorder(),
                          suffixText: 'kg',
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    ).withFadeIn();
  }

  Widget _buildMermaCard(bool isDark) {
    final totalExpected = _sectionCtrls.fold<double>(
        0, (sum, s) => sum + s.expectedKg);
    final totalActual = _sectionCtrls.fold<double>(
        0, (sum, s) => sum + (double.tryParse(s.controller.text.replaceAll(',', '.')) ?? 0));
    final merma = (totalExpected - totalActual).clamp(0.0, double.infinity);
    final mermaPct = totalExpected > 0 ? (merma / totalExpected) * 100 : 0.0;

    return GlassContainer(
      padding: const EdgeInsets.all(16),
      borderRadius: 0,
      blur: 10,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Merma',
              style: TextStyle(
                  fontWeight: FontWeight.w700, fontSize: 16)),
          const SizedBox(height: 8),
          Row(
            children: [
              Text('Esperado: ${totalExpected.toStringAsFixed(2)} kg',
                  style: TextStyle(fontSize: 13, color: Colors.grey[600])),
              const SizedBox(width: 16),
              Text('Real: ${totalActual.toStringAsFixed(2)} kg',
                  style: TextStyle(fontSize: 13, color: Colors.grey[600])),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Merma: ${merma.toStringAsFixed(2)} kg (${mermaPct.toStringAsFixed(1)}%)',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: merma > 0 ? Colors.red.shade700 : Colors.green.shade700,
            ),
          ),
        ],
      ),
    ).withFadeIn();
  }
}
