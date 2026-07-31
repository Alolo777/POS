import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../domain/poultry_repository.dart';
import '../domain/poultry_config.dart';
import '../domain/poultry_section.dart';

class PoultryConfigScreen extends StatefulWidget {
  const PoultryConfigScreen({super.key, required this.businessId});

  final String businessId;

  @override
  State<PoultryConfigScreen> createState() => _PoultryConfigScreenState();
}

class _PoultryConfigScreenState extends State<PoultryConfigScreen> {
  final _toleranceController = TextEditingController();
  final _wholeProductIdController = TextEditingController();
  final _sections = <_SectionForm>[];
  bool _loading = true;
  bool _loadError = false;
  String _loadErrorMessage = '';

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  Future<void> _loadConfig() async {
    try {
      final repo = context.read<PoultryRepository>();
      final config = await repo.getConfig(widget.businessId);
      if (!mounted) return;
      setState(() {
        _toleranceController.text =
            (config?.tolerancePercent ?? 5.0).toStringAsFixed(1);
        _wholeProductIdController.text = config?.wholeProductId ?? '';
        if (config != null) {
          for (final s in config.sections) {
            _sections.add(_SectionForm(s.name, s.defaultPercent, s.productId ?? ''));
          }
        }
        if (_sections.isEmpty) {
          _sections.addAll([
            _SectionForm('Pechuga', 36.55, ''),
            _SectionForm('Maciza', 25.61, ''),
            _SectionForm('Alas', 8.20, ''),
            _SectionForm('Patas', 3.68, ''),
            _SectionForm('Huacal', 8.54, ''),
            _SectionForm('Moll/Hig', 3.61, ''),
            _SectionForm('Rabadilla', 6.90, ''),
            _SectionForm('Cabeza', 2.06, ''),
          ]);
        }
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError = true;
        _loadErrorMessage = e.toString();
      });
    }
  }

  @override
  void dispose() {
    _toleranceController.dispose();
    _wholeProductIdController.dispose();
    for (final s in _sections) {
      s.name.dispose();
      s.percent.dispose();
      s.productId.dispose();
    }
    super.dispose();
  }

  bool _saving = false;

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final tolerance =
          double.tryParse(_toleranceController.text.replaceAll(',', '.')) ?? 5.0;
      final sections = _sections.asMap().entries.map((e) {
        final idx = e.key;
        final f = e.value;
        final name = f.name.text.trim();
        final pct = double.tryParse(f.percent.text.replaceAll(',', '.')) ?? 0;
        return PoultrySection(
          id: name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_'),
          name: name,
          defaultPercent: pct,
          productId: f.productId.text.trim().isEmpty ? null : f.productId.text.trim(),
          sortOrder: idx,
        );
      }).toList();

      final config = PoultryConfig(
        sections: sections,
        tolerancePercent: tolerance,
        wholeProductId: _wholeProductIdController.text.trim().isEmpty
            ? null
            : _wholeProductIdController.text.trim(),
      );

      final repo = context.read<PoultryRepository>();
      await repo.saveConfig(widget.businessId, config);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Configuración guardada')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al guardar: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _addSection() {
    setState(() => _sections.add(_SectionForm('', 0, '')));
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_loadError) {
      return Scaffold(
        appBar: AppBar(title: const Text('Configuración Pollería')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, size: 48, color: Colors.red),
                const SizedBox(height: 16),
                const Text('Error al cargar configuración',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text(_loadErrorMessage, textAlign: TextAlign.center),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: () {
                    setState(() {
                      _loading = true;
                      _loadError = false;
                    });
                    _loadConfig();
                  },
                  icon: const Icon(Icons.refresh),
                  label: const Text('Reintentar'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Configuración Pollería')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Tolerancia de advertencia (%)',
              style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 4),
          TextField(
            controller: _toleranceController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              hintText: 'Ej: 5.0',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 20),
          Text('Producto ID para Pollo Entero',
              style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 4),
          TextField(
            controller: _wholeProductIdController,
            decoration: const InputDecoration(
              hintText: 'Dejar vacío si no existe',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Secciones de corte',
                  style: Theme.of(context).textTheme.titleMedium),
              FilledButton.tonal(
                onPressed: _addSection,
                child: const Text('+ Agregar'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ..._sections.asMap().entries.map((entry) {
            final idx = entry.key;
            final s = entry.value;
            return Card(
              margin: const EdgeInsets.symmetric(vertical: 4),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: s.name,
                            decoration: const InputDecoration(
                              labelText: 'Nombre',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          width: 100,
                          child: TextField(
                            controller: s.percent,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: '%',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: s.productId,
                            decoration: const InputDecoration(
                              labelText: 'ID Producto (opcional)',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () =>
                              setState(() => _sections.removeAt(idx)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }),
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
            label: Text(_saving ? 'Guardando...' : 'Guardar configuración'),
          ),
        ],
      ),
    );
  }
}

class _SectionForm {
  final TextEditingController name;
  final TextEditingController percent;
  final TextEditingController productId;

  _SectionForm(String nameVal, double pct, String pid)
      : name = TextEditingController(text: nameVal),
        percent = TextEditingController(text: pct.toStringAsFixed(2)),
        productId = TextEditingController(text: pid);
}
