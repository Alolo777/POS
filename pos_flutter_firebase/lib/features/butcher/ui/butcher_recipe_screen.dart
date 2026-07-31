import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/glass_container.dart';
import '../../../core/theme/glass_theme.dart';
import '../../../shared/models/butcher_section.dart';
import '../domain/butcher_repository.dart';

class ButcherRecipeScreen extends StatefulWidget {
  const ButcherRecipeScreen({super.key, required this.businessId, this.storeId, this.storeNames});

  final String businessId;
  final String? storeId;
  final Map<String, String>? storeNames;

  @override
  State<ButcherRecipeScreen> createState() => _ButcherRecipeScreenState();
}

class _ButcherRecipeScreenState extends State<ButcherRecipeScreen> {
  ButcherRepository get _butcherService => context.read<ButcherRepository>();
  bool _isEditing = false;
  final _pctControllers = <String, TextEditingController>{};
  bool _savingEdit = false;

  @override
  void initState() {
    super.initState();
    _ensureRecipe();
  }

  @override
  void dispose() {
    for (final c in _pctControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _ensureRecipe() async {
    final sections = await _butcherService.getRecipe(widget.businessId);
    if (sections.isNotEmpty) return;
    if (!mounted) return;
    try {
      await _butcherService.saveRecipe(
        businessId: widget.businessId,
        sections: ButcherSection.defaults,
      );
    } catch (_) {}
  }

  void _startEditing(List<ButcherSection> sections) {
    _pctControllers.clear();
    for (final s in sections) {
      _pctControllers[s.name] = TextEditingController(
        text: (s.percentage * 100).toStringAsFixed(2),
      );
    }
    setState(() => _isEditing = true);
  }

  void _cancelEditing() {
    for (final c in _pctControllers.values) {
      c.dispose();
    }
    _pctControllers.clear();
    setState(() => _isEditing = false);
  }

  Future<void> _saveEdits(List<ButcherSection> sections) async {
    final updated = <ButcherSection>[];
    for (final s in sections) {
      final ctrl = _pctControllers[s.name];
      if (ctrl == null) return;
      final pct = double.tryParse(ctrl.text.trim().replaceAll(',', '.'));
      if (pct == null || pct < 0 || pct > 100) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Porcentaje invalido para "${s.name}"')),
        );
        return;
      }
      updated.add(s.copyWith(percentage: pct / 100));
    }

    final total = updated.fold<double>(0, (sum, s) => sum + s.percentage);
    if ((total - 1.0).abs() > 0.005) {
      if (!mounted) return;
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Los porcentajes no suman 100%'),
          content: Text('Suma actual: ${(total * 100).toStringAsFixed(2)}%. ¿Guardar de todas formas?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Guardar')),
          ],
        ),
      );
      if (confirm != true) return;
    }

    setState(() => _savingEdit = true);
    try {
      await _butcherService.saveRecipe(
        businessId: widget.businessId,
        sections: updated,
      );
      _cancelEditing();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _savingEdit = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return StreamBuilder<List<ButcherSection>>(
      stream: _butcherService.watchRecipe(widget.businessId),
      builder: (context, recipeSnapshot) {
        final sections = recipeSnapshot.data ?? const <ButcherSection>[];
        if (recipeSnapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            _buildRecipeCard(sections, isDark),
            const SizedBox(height: 24),
            _buildHistory(sections, isDark),
          ],
        );
      },
    );
  }

  Widget _buildRecipeCard(List<ButcherSection> sections, bool isDark) {
    final totalPct = sections.fold<double>(0, (s, section) => s + section.percentage);

    return GlassContainer(
      padding: const EdgeInsets.all(16),
      borderRadius: 0,
      blur: 10,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: GlassColors.accent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.zero,
                ),
                child: const Icon(Icons.soup_kitchen, size: 22, color: GlassColors.accent),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Receta de destazado', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                    Text('Porcentajes editables — al guardar se actualiza la receta', style: TextStyle(fontSize: 12)),
                  ],
                ),
              ),
              if (!_isEditing)
                TextButton.icon(
                  onPressed: () => _startEditing(sections),
                  icon: const Icon(Icons.edit, size: 16),
                  label: const Text('Editar'),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: isDark ? Colors.white12 : Colors.black26, width: 0.5),
            ),
            child: Column(
              children: [
                _row('Seccion', 'Porcentaje', header: true, isDark: isDark),
                if (_isEditing)
                  ...sections.map((s) => _editableRow(s, isDark))
                else
                  ...sections.map((s) => _row(s.name, '${(s.percentage * 100).toStringAsFixed(2)}%', isDark: isDark)),
                _row('TOTAL', '${(totalPct * 100).toStringAsFixed(2)}%', bold: true, isDark: isDark),
              ],
            ),
          ),
          if (_isEditing) ...[
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(onPressed: _cancelEditing, child: const Text('Cancelar')),
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: _savingEdit ? null : () => _saveEdits(sections),
                  icon: _savingEdit
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.save, size: 16),
                  label: const Text('Guardar receta'),
                ),
              ],
            ),
          ],
        ],
      ),
    ).withFadeIn();
  }

  Widget _editableRow(ButcherSection section, bool isDark) {
    final ctrl = _pctControllers[section.name];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: isDark ? Colors.white12 : Colors.black12, width: 0.5)),
      ),
      child: Row(
        children: [
          SizedBox(width: 140, child: Text(section.name, style: TextStyle(fontSize: 13, color: isDark ? Colors.white70 : Colors.grey[800]))),
          SizedBox(
            width: 80,
            child: TextField(
              controller: ctrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                isDense: true,
                contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                suffixText: '%',
              ),
              textAlign: TextAlign.right,
              style: TextStyle(fontSize: 13, color: isDark ? Colors.white70 : Colors.grey[800]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(String col1, String col2, {bool header = false, bool bold = false, required bool isDark}) {
    final style = TextStyle(
      fontSize: header ? 11 : 13,
      fontWeight: header || bold ? FontWeight.w700 : FontWeight.normal,
      color: header ? Colors.grey[500] : (isDark ? Colors.white70 : Colors.grey[800]),
    );
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: header ? 8 : 5),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: isDark ? Colors.white12 : Colors.black12, width: 0.5)),
        color: bold ? GlassColors.accent.withValues(alpha: 0.06) : null,
      ),
      child: Row(
        children: [
          SizedBox(width: 140, child: Text(col1, style: style)),
          Text(col2, style: style),
        ],
      ),
    );
  }

  Widget _buildHistory(List<ButcherSection> sections, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Historial de entradas', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        StreamBuilder<List<Map<String, dynamic>>>(
          stream: _butcherService.watchReceipts(widget.businessId, storeId: widget.storeId),
          builder: (context, snapshot) {
            final receipts = snapshot.data ?? [];
            if (receipts.isEmpty) {
              return Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    Icon(Icons.soup_kitchen, size: 40, color: Colors.grey[400]),
                    const SizedBox(height: 8),
                    Text('Sin entradas registradas.', style: TextStyle(color: Colors.grey[500])),
                    const SizedBox(height: 4),
                    Text('Los empleados pueden registrar entradas desde el POS > menu > Recibir pollo',
                      style: TextStyle(fontSize: 12, color: Colors.grey[400]), textAlign: TextAlign.center),
                  ],
                ),
              );
            }
              return Column(
                children: receipts.map((receipt) {
                final yields = (receipt['yields'] as List? ?? [])
                    .map((y) => Map<String, dynamic>.from(y as Map))
                    .toList();
                final count = receipt['chickenCount'] as int? ?? 0;
                final avg = (receipt['avgWeight'] as num? ?? 0).toDouble();
                final total = (receipt['totalWeight'] as num? ?? 0).toDouble();
                final consumed = (receipt['consumedSections'] as List? ?? []).cast<String>();
                final appliedCount = consumed.length;
                final totalSections = yields.length;
                final cancelled = receipt['cancelled'] as bool? ?? false;
                final cancelledReason = receipt['cancelledReason'] as String?;
                final storeId = receipt['storeId'] as String? ?? '';
                final sectionNames = yields.map((y) => y['name'] as String? ?? '').toList();

                final storeName = widget.storeNames?[storeId] ?? storeId;
                return _ReceiptCard(
                  key: ValueKey(receipt['id']),
                  businessId: widget.businessId,
                  receiptId: receipt['id'] as String? ?? '',
                  storeId: storeId,
                  storeName: storeName,
                  count: count,
                  avg: avg,
                  total: total,
                  yields: yields,
                  sectionNames: sectionNames,
                  consumedSections: consumed,
                  appliedCount: appliedCount,
                  totalSections: totalSections,
                  cancelled: cancelled,
                  cancelledReason: cancelledReason,
                  isDark: isDark,
                );
              }).toList(),
              );
          },
        ),
      ],
    );
  }
}

class _ReceiptCard extends StatefulWidget {
  const _ReceiptCard({
    super.key,
    required this.businessId,
    required this.receiptId,
    required this.storeId,
    this.storeName,
    required this.count,
    required this.avg,
    required this.total,
    required this.yields,
    required this.sectionNames,
    required this.consumedSections,
    required this.appliedCount,
    required this.totalSections,
    required this.cancelled,
    this.cancelledReason,
    required this.isDark,
  });

  final String businessId;
  final String receiptId;
  final String storeId;
  final String? storeName;
  final int count;
  final double avg;
  final double total;
  final List<Map<String, dynamic>> yields;
  final List<String> sectionNames;
  final List<String> consumedSections;
  final int appliedCount;
  final int totalSections;
  final bool cancelled;
  final String? cancelledReason;
  final bool isDark;

  @override
  State<_ReceiptCard> createState() => _ReceiptCardState();
}

class _ReceiptCardState extends State<_ReceiptCard> {
  ButcherRepository get _butcherService => context.read<ButcherRepository>();
  Map<String, ({double price, double stock, double sales})> _sectionData = {};
  bool _isCancelling = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void didUpdateWidget(_ReceiptCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.receiptId != widget.receiptId || oldWidget.storeId != widget.storeId) {
      _loadData();
    }
  }

  Future<void> _loadData() async {
    if (widget.storeId.isEmpty || widget.sectionNames.isEmpty) return;
    try {
      final data = await _butcherService.getSectionRealData(
        businessId: widget.businessId,
        storeId: widget.storeId,
        sectionNames: widget.sectionNames,
      );
      if (mounted) setState(() => _sectionData = data);
    } catch (_) {}
  }

  Future<void> _cancelEntry() async {
    final reasonCtrl = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancelar entrada'),
        content: TextField(
          controller: reasonCtrl,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Motivo de cancelacion',
            hintText: 'Ej: Error en peso, duplicado...',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('No')),
          FilledButton(onPressed: () => Navigator.pop(ctx, reasonCtrl.text), child: const Text('Cancelar entrada')),
        ],
      ),
    );
    reasonCtrl.dispose();
    if (reason == null || reason.trim().isEmpty || !mounted) return;

    setState(() => _isCancelling = true);
    try {
      await _butcherService.cancelEntry(
        businessId: widget.businessId,
        receiptId: widget.receiptId,
        reason: reason.trim(),
        cancelledBy: 'admin',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Entrada cancelada')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isCancelling = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.cancelled) {
      return GlassContainer(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        borderRadius: 0,
        blur: 6,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: GlassColors.danger.withValues(alpha: 0.15),
                  ),
                  child: const Icon(Icons.cancel, size: 16, color: GlassColors.danger),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${widget.count} pollos x ${widget.avg.toStringAsFixed(3)} kg',
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, decoration: TextDecoration.lineThrough)),
                      if (widget.storeName != null)
                        Text(widget.storeName!, style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                    ],
                  ),
                ),
                Text('${widget.total.toStringAsFixed(3)} kg',
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, decoration: TextDecoration.lineThrough)),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(Icons.info_outline, size: 14, color: GlassColors.danger),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Cancelada: ${widget.cancelledReason ?? 'Sin motivo'}',
                    style: TextStyle(fontSize: 12, color: GlassColors.danger),
                  ),
                ),
              ],
            ),
          ],
        ),
      ).withFadeIn();
    }

    return GlassContainer(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      borderRadius: 0,
      blur: 6,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: widget.appliedCount > 0
                      ? GlassColors.success.withValues(alpha: 0.15)
                      : GlassColors.warning.withValues(alpha: 0.15),
                ),
                child: Icon(
                  widget.appliedCount > 0 ? Icons.check_circle : Icons.pending,
                  size: 16,
                  color: widget.appliedCount > 0 ? GlassColors.success : GlassColors.warning,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${widget.count} pollos x ${widget.avg.toStringAsFixed(3)} kg',
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                    if (widget.storeName != null)
                      Text(widget.storeName!, style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                  ],
                ),
              ),
              Text('${widget.total.toStringAsFixed(3)} kg', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
            ],
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: _buildYieldTable(widget.yields, widget.isDark),
          ),
          if (widget.appliedCount < widget.totalSections) ...[
            const SizedBox(height: 6),
            Text('${widget.appliedCount} de ${widget.totalSections} secciones aplicadas a productos existentes',
              style: TextStyle(fontSize: 11, color: GlassColors.warning)),
          ],
          if (widget.appliedCount == widget.totalSections && widget.appliedCount > 0) ...[
            const SizedBox(height: 6),
            Text('Aplicado al inventario automaticamente',
              style: TextStyle(fontSize: 11, color: GlassColors.success)),
          ],
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: _isCancelling ? null : _cancelEntry,
              icon: _isCancelling
                  ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.cancel_outlined, size: 16),
              label: const Text('Cancelar entrada', style: TextStyle(fontSize: 12)),
              style: TextButton.styleFrom(foregroundColor: GlassColors.danger),
            ),
          ),
        ],
      ),
    ).withFadeIn();
  }

  Widget _buildYieldTable(List<Map<String, dynamic>> yields, bool isDark) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: isDark ? Colors.white12 : Colors.black12, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _histRow('Seccion', 'Peso aprox dia', 'Peso actual', 'Precio x kg', 'Ventas',
            header: true, isDark: isDark),
          ...yields.map((y) {
            final name = y['name'] as String? ?? '';
            final weight = (y['weight'] as num? ?? 0).toDouble();
            final real = _sectionData[name];
            final displayStock = (real != null && real.stock > 0)
                ? real.stock
                : weight;
            final stock = '${displayStock.toStringAsFixed(3)} kg';
            final price = real != null ? '\$${real.price.toStringAsFixed(2)}' : '—';
            final sales = real != null ? '${real.sales.toStringAsFixed(0)}' : '—';
            return _histRow(
              name,
              '${weight.toStringAsFixed(3)} kg',
              stock,
              price,
              sales,
              isDark: isDark,
            );
          }),
        ],
      ),
    );
  }

  Widget _histRow(String col1, String col2, String col3, String col4, String col5,
      {bool header = false, required bool isDark}) {
    final style = TextStyle(
      fontSize: header ? 11 : 13,
      fontWeight: header ? FontWeight.w700 : FontWeight.normal,
      color: header ? Colors.grey[500] : (isDark ? Colors.white70 : Colors.grey[800]),
    );
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: header ? 8 : 5),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: isDark ? Colors.white12 : Colors.black12, width: 0.5)),
      ),
      child: Row(
        children: [
          SizedBox(width: 110, child: Text(col1, style: style)),
          SizedBox(width: 120, child: Text(col2, style: style, textAlign: TextAlign.right)),
          SizedBox(width: 100, child: Text(col3, style: style, textAlign: TextAlign.right)),
          SizedBox(width: 100, child: Text(col4, style: style, textAlign: TextAlign.right)),
          SizedBox(width: 80, child: Text(col5, style: style, textAlign: TextAlign.right)),
        ],
      ),
    );
  }
}
