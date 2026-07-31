import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/glass_container.dart';
import '../../core/theme/glass_theme.dart';
import '../../features/employees/domain/employee_repository.dart';
import '../../features/sales/domain/sale_repository.dart';
import '../../features/shift/domain/shift_repository.dart';
import '../models/employee.dart';
import '../models/sale.dart';
import '../models/shift.dart';

class ReportsDashboard extends StatefulWidget {
  const ReportsDashboard({
    super.key,
    required this.businessId,
    required this.selectedStoreId,
  });

  final String businessId;
  final String? selectedStoreId;

  @override
  State<ReportsDashboard> createState() => _ReportsDashboardState();
}

class _ReportsDashboardState extends State<ReportsDashboard> {
  late DateTime _startDate;
  late DateTime _endDate;
  int _selectedIndex = 0;
  int _page = 0;
  String? _activeRange;
  static const int _pageSize = 10;

  static const _tabs = ['Resumen', 'Articulos', 'Categorias', 'Empleados', 'Pagos', 'Recibos', 'Cortes'];

  @override
  void initState() {
    super.initState();
    _applyQuickRange('today');
  }

  void _applyQuickRange(String range) {
    final now = DateTime.now();
    setState(() {
      _page = 0;
      _activeRange = range;
      switch (range) {
        case 'today':
          _startDate = DateTime(now.year, now.month, now.day);
          _endDate = DateTime(now.year, now.month, now.day, 23, 59, 59);
        case 'yesterday':
          final y = now.subtract(const Duration(days: 1));
          _startDate = DateTime(y.year, y.month, y.day);
          _endDate = DateTime(y.year, y.month, y.day, 23, 59, 59);
        case 'thisWeek':
          _startDate = now.subtract(Duration(days: now.weekday - 1));
          _endDate = DateTime(now.year, now.month, now.day, 23, 59, 59);
        case 'lastWeek':
          final lastWeek = now.subtract(const Duration(days: 7));
          _startDate = lastWeek.subtract(Duration(days: lastWeek.weekday - 1));
          _endDate = _startDate.add(const Duration(days: 6, hours: 23, minutes: 59, seconds: 59));
        case 'thisMonth':
          _startDate = DateTime(now.year, now.month);
          _endDate = DateTime(now.year, now.month, now.day, 23, 59, 59);
        case 'all':
          _startDate = DateTime(2000);
          _endDate = DateTime(2100);
      }
    });
  }

  Future<void> _pickCustomRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      initialDateRange: DateTimeRange(start: _startDate, end: _endDate),
    );
    if (picked != null) {
      setState(() {
        _page = 0;
        _activeRange = null;
        _startDate = picked.start;
        _endDate = DateTime(picked.end.year, picked.end.month, picked.end.day, 23, 59, 59);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Sale>>(
      stream: context.read<SaleRepository>().watchBusinessSales(businessId: widget.businessId),
      builder: (context, salesSnapshot) {
        if (salesSnapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (salesSnapshot.hasError) {
          return Center(child: Text('Error: ${salesSnapshot.error}'));
        }
        return StreamBuilder<List<Employee>>(
          stream: context.read<EmployeeRepository>().watchEmployees(businessId: widget.businessId),
          builder: (context, employeesSnapshot) {
            final employeeNames = {for (final e in employeesSnapshot.data ?? const <Employee>[]) e.id: e.name};
            final allSales = salesSnapshot.data ?? const <Sale>[];
            final sales = allSales.where((sale) {
              final date = sale.createdAt ?? sale.clientCreatedAt;
              if (date == null) return false;
              final matchesStore = widget.selectedStoreId == null || sale.storeId == widget.selectedStoreId;
              return matchesStore && !date.isBefore(_startDate) && !date.isAfter(_endDate);
            }).toList();

            final summary = _ReportSummary.fromSales(sales, employeeNames: employeeNames);

            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              children: [
                _buildReportSelector(),
                const SizedBox(height: 16),
                _buildFilterCard(),
                const SizedBox(height: 16),
                _buildReportBody(summary, sales),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildReportSelector() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GlassContainer(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      borderRadius: 0,
      blur: 10,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: List.generate(_tabs.length, (i) {
            final selected = _selectedIndex == i;
            return Padding(
              padding: const EdgeInsets.only(right: 4),
              child: GestureDetector(
                onTap: () => setState(() { _selectedIndex = i; _page = 0; }),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: selected
                        ? (isDark ? GlassColors.accentDark.withValues(alpha: 0.3) : GlassColors.accent.withValues(alpha: 0.2))
                        : Colors.transparent,
                    borderRadius: BorderRadius.zero,
                  ),
                  child: Text(
                    _tabs[i],
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                      color: selected ? GlassColors.accent : (isDark ? Colors.white60 : Colors.grey[600]),
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    ).withFadeIn();
  }

  Widget _buildFilterCard() {
    return GlassContainer(
      padding: const EdgeInsets.all(16),
      borderRadius: 0,
      blur: 12,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.date_range, size: 18, color: GlassColors.accent),
              const SizedBox(width: 8),
              Text('Rango de fechas', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${_formatDate(_startDate)} — ${_formatDate(_endDate)}',
            style: TextStyle(fontSize: 12, color: Colors.grey[500]),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _chip('Hoy', 'today', () => _applyQuickRange('today')),
              _chip('Ayer', 'yesterday', () => _applyQuickRange('yesterday')),
              _chip('Semana', 'thisWeek', () => _applyQuickRange('thisWeek')),
              _chip('Sem. pasada', 'lastWeek', () => _applyQuickRange('lastWeek')),
              _chip('Mes', 'thisMonth', () => _applyQuickRange('thisMonth')),
              _chip('Todo', 'all', () => _applyQuickRange('all')),
              FilledButton.tonalIcon(
                onPressed: _pickCustomRange,
                icon: const Icon(Icons.date_range, size: 16),
                label: const Text('Personalizado'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                ),
              ),
            ],
          ),
        ],
      ),
    ).withFadeIn();
  }

  Widget _chip(String label, String range, VoidCallback onPressed) {
    final isActive = _activeRange == range;
    return ActionChip(
      label: Text(label, style: TextStyle(fontSize: 12, color: isActive ? Colors.white : null)),
      onPressed: onPressed,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      backgroundColor: isActive ? GlassColors.accent : null,
      side: isActive ? BorderSide.none : null,
    );
  }

  Widget _buildReportBody(_ReportSummary summary, List<Sale> sales) {
    switch (_selectedIndex) {
      case 0: return _buildSalesSummary(summary);
      case 1: return _buildSalesByItem(summary);
      case 2: return _buildSalesByCategory(summary);
      case 3: return _buildSalesByEmployee(summary);
      case 4: return _buildSalesByPayment(summary);
      case 5: return _buildReceipts(sales);
      case 6: return _buildCortesDeCaja();
      default: return const SizedBox.shrink();
    }
  }

  Widget _buildSalesSummary(_ReportSummary summary) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildKpiGrid(summary),
        const SizedBox(height: 16),
        _buildDailyChart(summary),
        const SizedBox(height: 16),
        _buildDailyTable(summary),
      ],
    );
  }

  Widget _buildKpiGrid(_ReportSummary summary) {
    final kpis = [
      _KpiData('Ventas brutas', summary.grossSales, Icons.trending_up, GlassColors.success, true),
      _KpiData('Ventas netas', summary.netSales, Icons.account_balance_wallet, GlassColors.accent, true),
      _KpiData('Efectivo', summary.cashSales, Icons.money, Colors.teal, true),
      _KpiData('Tarjeta', summary.cardSales, Icons.credit_card, Colors.indigo, true),
      _KpiData('Devoluciones', summary.refunds, Icons.undo, GlassColors.warning, true),
      _KpiData('Descuentos', summary.discounts, Icons.discount, GlassColors.danger, true),
      _KpiData('Ticket prom.', summary.averageTicket, Icons.receipt_long, Colors.purple, true),
      _KpiData('Transacciones', summary.transactionCount.toDouble(), Icons.shopping_cart_checkout, Colors.cyan, false),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth > 600 ? 4 : (constraints.maxWidth > 400 ? 3 : 2);
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 1.3,
          ),
          itemCount: kpis.length,
          itemBuilder: (context, index) => _KpiCard(kpi: kpis[index]),
        );
      },
    );
  }

  Widget _buildDailyChart(_ReportSummary summary) {
    final entries = summary.dailySales.entries.toList()..sort((a, b) => a.key.compareTo(b.key));

    return GlassContainer(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      borderRadius: 0,
      blur: 12,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.bar_chart, size: 18, color: GlassColors.accent),
            const SizedBox(width: 8),
            Text('Ventas por dia', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
          ]),
          const SizedBox(height: 16),
          if (entries.isEmpty)
            const Padding(padding: EdgeInsets.only(bottom: 16), child: Center(child: Text('Sin ventas en el rango seleccionado.')))
          else
            SizedBox(
              height: 200,
              child: BarChart(_buildBarChartData(entries)),
            ),
        ],
      ),
    ).withFadeIn();
  }

  BarChartData _buildBarChartData(List<MapEntry<String, double>> entries) {
    final maxValue = entries.map((e) => e.value).reduce((a, b) => a > b ? a : b);
    return BarChartData(
      alignment: BarChartAlignment.spaceAround,
      maxY: maxValue * 1.15,
      barTouchData: BarTouchData(
        touchTooltipData: BarTouchTooltipData(
          getTooltipItem: (group, groupIndex, rod, rodIndex) {
            return BarTooltipItem(
              '${entries[group.x.toInt()].key.substring(5)}\n\$${rod.toY.toStringAsFixed(2)}',
              TextStyle(color: Theme.of(context).colorScheme.onPrimary, fontWeight: FontWeight.bold),
            );
          },
        ),
      ),
      titlesData: FlTitlesData(
        show: true,
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 45,
            getTitlesWidget: (value, meta) {
              if (value == 0) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(right: 4),
                child: Text('\$${value.toInt()}', style: const TextStyle(fontSize: 10)),
              );
            },
          ),
        ),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 28,
            getTitlesWidget: (value, meta) {
              final index = value.toInt();
              if (index < 0 || index >= entries.length) return const SizedBox.shrink();
              final label = entries[index].key.substring(5);
              return SideTitleWidget(meta: meta, child: Text(label, style: const TextStyle(fontSize: 9)));
            },
            interval: (entries.length / 7).ceil().toDouble().clamp(1, double.infinity),
          ),
        ),
      ),
      borderData: FlBorderData(show: false),
      gridData: FlGridData(
        show: true,
        horizontalInterval: maxValue / 4,
        getDrawingHorizontalLine: (value) => FlLine(color: Colors.grey.withValues(alpha: 0.3), strokeWidth: 1),
      ),
      barGroups: entries.asMap().entries.map((entry) {
        return BarChartGroupData(
          x: entry.key,
          barRods: [
            BarChartRodData(
              toY: entry.value.value,
              color: GlassColors.accent,
              width: 16,
              borderRadius: BorderRadius.zero,
            ),
          ],
        );
      }).toList(),
    );
  }

  Widget _buildDailyTable(_ReportSummary summary) {
    final entries = summary.dailySales.entries.toList()..sort((a, b) => b.key.compareTo(a.key));
    final totalPages = (entries.length / _pageSize).ceil().clamp(1, 999);
    final currentPage = _page.clamp(0, totalPages - 1);
    final pageEntries = entries.skip(currentPage * _pageSize).take(_pageSize).toList();

    return GlassContainer(
      padding: const EdgeInsets.all(16),
      borderRadius: 0,
      blur: 12,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [
            Icon(Icons.table_chart, size: 18, color: GlassColors.accent),
            const SizedBox(width: 8),
            Text('Detalle por dia', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
          ]),
          const SizedBox(height: 12),
          if (entries.isEmpty)
            const Padding(padding: EdgeInsets.all(16), child: Center(child: Text('Sin datos')))
          else ...[
            _tableHeader(['Fecha', 'Ventas']),
            const SizedBox(height: 4),
            ...pageEntries.map((e) => _tableRow([
              e.key,
              '\$${e.value.toStringAsFixed(2)}',
            ], e.value > 0)),
            const SizedBox(height: 12),
            _buildPagination(currentPage, totalPages),
          ],
        ],
      ),
    ).withFadeIn();
  }

  Widget _buildSalesByItem(_ReportSummary summary) {
    final entries = summary.products.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final total = entries.fold<double>(0, (sum, e) => sum + e.value);
    final totalPages = (entries.length / _pageSize).ceil().clamp(1, 999);
    final currentPage = _page.clamp(0, totalPages - 1);
    final pageEntries = entries.skip(currentPage * _pageSize).take(_pageSize).toList();

    return GlassContainer(
      padding: const EdgeInsets.all(16),
      borderRadius: 0,
      blur: 12,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [
            Icon(Icons.inventory_2, size: 18, color: GlassColors.accent),
            const SizedBox(width: 8),
            Text('Ventas por articulo', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
          ]),
          const SizedBox(height: 4),
          Text('${entries.length} articulos vendidos', style: TextStyle(fontSize: 12, color: Colors.grey[500])),
          const SizedBox(height: 12),
          if (entries.isEmpty)
            const Padding(padding: EdgeInsets.all(16), child: Center(child: Text('Sin datos')))
          else ...[
            _tableHeader(['#', 'Articulo', 'Total', '%']),
            const SizedBox(height: 4),
            ...pageEntries.asMap().entries.map((e) {
              final rank = currentPage * _pageSize + e.key + 1;
              final pct = total > 0 ? (e.value.value / total * 100) : 0.0;
              return _tableRow([
                '$rank',
                e.value.key,
                '\$${e.value.value.toStringAsFixed(2)}',
                '${pct.toStringAsFixed(1)}%',
              ], e.value.value > 0);
            }),
            const SizedBox(height: 12),
            _buildPagination(currentPage, totalPages),
          ],
        ],
      ),
    ).withFadeIn();
  }

  Widget _buildSalesByCategory(_ReportSummary summary) {
    final entries = summary.categories.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final total = entries.fold<double>(0, (sum, e) => sum + e.value);
    final totalPages = (entries.length / _pageSize).ceil().clamp(1, 999);
    final currentPage = _page.clamp(0, totalPages - 1);
    final pageEntries = entries.skip(currentPage * _pageSize).take(_pageSize).toList();
    final maxValue = entries.isEmpty ? 1.0 : entries.first.value;

    return GlassContainer(
      padding: const EdgeInsets.all(16),
      borderRadius: 0,
      blur: 12,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [
            Icon(Icons.category, size: 18, color: GlassColors.accent),
            const SizedBox(width: 8),
            Text('Ventas por categoria', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
          ]),
          const SizedBox(height: 12),
          if (entries.isEmpty)
            const Padding(padding: EdgeInsets.all(16), child: Center(child: Text('Sin datos')))
          else ...[
            ...pageEntries.map((e) {
              final pct = maxValue > 0 ? e.value / maxValue : 0.0;
              final share = total > 0 ? (e.value / total * 100) : 0.0;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(child: Text(e.key, style: const TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis)),
                        Text('\$${e.value.toStringAsFixed(2)}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                        const SizedBox(width: 8),
                        Text('${share.toStringAsFixed(1)}%', style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                      ],
                    ),
                    const SizedBox(height: 4),
                    ClipRRect(
                      borderRadius: BorderRadius.zero,
                      child: LinearProgressIndicator(
                        value: pct.clamp(0.0, 1.0),
                        backgroundColor: Colors.grey.withValues(alpha: 0.2),
                        color: GlassColors.accent,
                        minHeight: 6,
                      ),
                    ),
                  ],
                ),
              );
            }),
            const SizedBox(height: 12),
            _buildPagination(currentPage, totalPages),
          ],
        ],
      ),
    ).withFadeIn();
  }

  Widget _buildSalesByEmployee(_ReportSummary summary) {
    final entries = summary.employees.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final total = entries.fold<double>(0, (sum, e) => sum + e.value);
    final totalPages = (entries.length / _pageSize).ceil().clamp(1, 999);
    final currentPage = _page.clamp(0, totalPages - 1);
    final pageEntries = entries.skip(currentPage * _pageSize).take(_pageSize).toList();

    return GlassContainer(
      padding: const EdgeInsets.all(16),
      borderRadius: 0,
      blur: 12,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [
            Icon(Icons.person, size: 18, color: GlassColors.accent),
            const SizedBox(width: 8),
            Text('Ventas por empleado', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
          ]),
          const SizedBox(height: 4),
          Text('${entries.length} empleados', style: TextStyle(fontSize: 12, color: Colors.grey[500])),
          const SizedBox(height: 12),
          if (entries.isEmpty)
            const Padding(padding: EdgeInsets.all(16), child: Center(child: Text('Sin datos')))
          else ...[
            _tableHeader(['#', 'Empleado', 'Total', '%']),
            const SizedBox(height: 4),
            ...pageEntries.asMap().entries.map((e) {
              final rank = currentPage * _pageSize + e.key + 1;
              final pct = total > 0 ? (e.value.value / total * 100) : 0.0;
              return _tableRow([
                '$rank',
                e.value.key,
                '\$${e.value.value.toStringAsFixed(2)}',
                '${pct.toStringAsFixed(1)}%',
              ], e.value.value > 0);
            }),
            const SizedBox(height: 12),
            _buildPagination(currentPage, totalPages),
          ],
        ],
      ),
    ).withFadeIn();
  }

  Widget _buildSalesByPayment(_ReportSummary summary) {
    final paymentData = summary.paymentTypes.entries
        .where((e) => e.value != 0)
        .toList()..sort((a, b) => b.value.compareTo(a.value));
    final total = paymentData.fold<double>(0, (sum, e) => sum + e.value.abs());
    final colors = [Colors.teal, Colors.indigo, GlassColors.warning, GlassColors.danger, Colors.grey];

    return GlassContainer(
      padding: const EdgeInsets.all(16),
      borderRadius: 0,
      blur: 12,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Row(children: [
            Icon(Icons.pie_chart, size: 18, color: GlassColors.accent),
            const SizedBox(width: 8),
            Text('Metodos de pago', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
          ]),
          const SizedBox(height: 16),
          if (paymentData.isEmpty)
            const Padding(padding: EdgeInsets.all(16), child: Center(child: Text('Sin datos')))
          else ...[
            Center(
              child: SizedBox(
                width: 200,
                height: 200,
                child: PieChart(
                  PieChartData(
                    sections: paymentData.asMap().entries.map((entry) {
                      final pct = total > 0 ? entry.value.value.abs() / total * 100 : 0;
                      return PieChartSectionData(
                        value: entry.value.value.abs(),
                        color: colors[entry.key % colors.length],
                        radius: 60,
                        title: '${pct.toStringAsFixed(1)}%',
                        titleStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                      );
                    }).toList(),
                    sectionsSpace: 2,
                    centerSpaceRadius: 35,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            ...paymentData.asMap().entries.map((entry) {
              final pct = total > 0 ? entry.value.value.abs() / total * 100 : 0;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: colors[entry.key % colors.length],
                        borderRadius: BorderRadius.zero,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(child: Text(entry.value.key, style: const TextStyle(fontSize: 12))),
                    Text('\$${entry.value.value.toStringAsFixed(2)}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                    const SizedBox(width: 8),
                    Text('${pct.toStringAsFixed(1)}%', style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                  ],
                ),
              );
            }),
          ],
        ],
      ),
    ).withFadeIn();
  }

  Widget _buildReceipts(List<Sale> sales) {
    final sorted = [...sales]..sort((a, b) {
      final aDate = a.createdAt ?? a.clientCreatedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bDate = b.createdAt ?? b.clientCreatedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bDate.compareTo(aDate);
    });
    final totalPages = (sorted.length / _pageSize).ceil().clamp(1, 999);
    final currentPage = _page.clamp(0, totalPages - 1);
    final pageEntries = sorted.skip(currentPage * _pageSize).take(_pageSize).toList();

    return GlassContainer(
      padding: const EdgeInsets.all(16),
      borderRadius: 0,
      blur: 12,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [
            Icon(Icons.receipt, size: 18, color: GlassColors.accent),
            const SizedBox(width: 8),
            Text('Recibos', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
          ]),
          const SizedBox(height: 4),
          Text('${sorted.length} recibos en total', style: TextStyle(fontSize: 12, color: Colors.grey[500])),
          const SizedBox(height: 12),
          if (sorted.isEmpty)
            const Padding(padding: EdgeInsets.all(16), child: Center(child: Text('Sin recibos')))
          else ...[
            _tableHeader(['Folio', 'Fecha', 'Metodo', 'Total']),
            const SizedBox(height: 4),
            ...pageEntries.map((sale) {
              final date = sale.createdAt ?? sale.clientCreatedAt;
              final dateStr = date != null ? '${date.day}/${date.month}/${date.year}' : '--';
              final method = sale.paymentMethod == 'card' ? 'Tarjeta' : 'Efectivo';
              final label = sale.isRefund ? 'Devolucion' : sale.folio;
              final color = sale.isRefund ? GlassColors.danger : null;
              return GestureDetector(
                onTap: () => _showReceiptDetail(sale),
                child: _tableRow([label, dateStr, method, '\$${sale.total.toStringAsFixed(2)}'], !sale.isRefund, valueColor: color),
              );
            }),
            const SizedBox(height: 12),
            _buildPagination(currentPage, totalPages),
          ],
        ],
      ),
    ).withFadeIn();
  }

  Widget _buildCortesDeCaja() {
    return StreamBuilder<List<Shift>>(
      stream: context.read<ShiftRepository>().watchAllClosedShifts(businessId: widget.businessId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return GlassContainer(
            padding: const EdgeInsets.all(16),
            borderRadius: 0,
            blur: 8,
            child: const Center(child: CircularProgressIndicator()),
          );
        }
        final allShifts = snapshot.data ?? const <Shift>[];
        final shifts = allShifts.where((s) {
          final matchesStore = widget.selectedStoreId == null || s.storeId == widget.selectedStoreId;
          final matchesDate = s.closedAt != null && !s.closedAt!.isBefore(_startDate) && !s.closedAt!.isAfter(_endDate);
          return matchesStore && matchesDate;
        }).toList();
        final totalPages = (shifts.length / _pageSize).ceil().clamp(1, 999);
        final currentPage = _page.clamp(0, totalPages - 1);
        final pageEntries = shifts.skip(currentPage * _pageSize).take(_pageSize).toList();

        return GlassContainer(
          padding: const EdgeInsets.all(16),
          borderRadius: 0,
          blur: 12,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(children: [
                Icon(Icons.calculate, size: 18, color: GlassColors.accent),
                const SizedBox(width: 8),
                Text('Cortes de caja', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
              ]),
              const SizedBox(height: 4),
              Text('${shifts.length} cortes', style: TextStyle(fontSize: 12, color: Colors.grey[500])),
              const SizedBox(height: 12),
              if (shifts.isEmpty)
                const Padding(padding: EdgeInsets.all(16), child: Center(child: Text('Sin cortes en el rango seleccionado.')))
              else ...[
                _tableHeader(['Fecha', 'Efectivo inicial', 'Total ventas', 'Diferencia']),
                const SizedBox(height: 4),
                ...pageEntries.map((shift) {
                  final diff = shift.cashDifference;
                  return GestureDetector(
                    onTap: () => _showShiftDetail(shift),
                    child: _tableRow([
                      _formatDate(shift.closedAt),
                      '\$${shift.openingCash.toStringAsFixed(2)}',
                      '\$${shift.totalSales.toStringAsFixed(2)}',
                      '${diff >= 0 ? '+' : ''}\$${diff.toStringAsFixed(2)}',
                    ], diff >= 0, valueColor: diff >= 0 ? GlassColors.success : GlassColors.danger),
                  );
                }),
                const SizedBox(height: 12),
                _buildPagination(currentPage, totalPages),
              ],
            ],
          ),
        ).withFadeIn();
      },
    );
  }

  void _showReceiptDetail(Sale sale) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: GlassContainer(
          padding: const EdgeInsets.all(20),
          borderRadius: 0,
          blur: 20,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(children: [
                  Icon(sale.isRefund ? Icons.undo : Icons.receipt, size: 20, color: sale.isRefund ? GlassColors.danger : GlassColors.accent),
                  const SizedBox(width: 8),
                  Text(sale.isRefund ? 'Devolucion' : 'Recibo', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                  const Spacer(),
                  TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cerrar')),
                ]),
                const Divider(),
                _detailRow('Folio', sale.folio),
                _detailRow('Estado', sale.status),
                _detailRow('Metodo', sale.paymentMethod == 'card' ? 'Tarjeta' : 'Efectivo'),
                _detailRow('Subtotal', '\$${sale.subtotal.toStringAsFixed(2)}'),
                _detailRow('Descuento', '\$${sale.discountTotal.toStringAsFixed(2)}'),
                _detailRow('Total', '\$${sale.total.toStringAsFixed(2)}'),
                if (sale.createdAt != null) _detailRow('Fecha', _formatDate(sale.createdAt)),
                if (sale.items.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  const Text('Articulos', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  const SizedBox(height: 4),
                  ...sale.items.map((item) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Text(
                      '${item['name'] ?? 'Producto'} x${item['quantity'] ?? 0} = \$${(item['subtotal'] as num? ?? 0).toStringAsFixed(2)}',
                      style: const TextStyle(fontSize: 13),
                    ),
                  )),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showShiftDetail(Shift shift) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: GlassContainer(
          padding: const EdgeInsets.all(20),
          borderRadius: 0,
          blur: 20,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(children: [
                  const Icon(Icons.calculate, size: 20, color: GlassColors.accent),
                  const SizedBox(width: 8),
                  const Text('Corte de caja', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                  const Spacer(),
                  TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cerrar')),
                ]),
                const Divider(),
                _detailRow('Efectivo inicial', '\$${shift.openingCash.toStringAsFixed(2)}'),
                _detailRow('Ventas efectivo', '\$${shift.cashSales.toStringAsFixed(2)}'),
                _detailRow('Ventas tarjeta', '\$${shift.cardSales.toStringAsFixed(2)}'),
                _detailRow('Total ventas', '\$${shift.totalSales.toStringAsFixed(2)}'),
                _detailRow('Efectivo esperado', '\$${shift.expectedCash.toStringAsFixed(2)}'),
                _detailRow('Efectivo final', '\$${shift.closingCash?.toStringAsFixed(2) ?? '—'}'),
                _detailRow('Diferencia', '${shift.cashDifference >= 0 ? '+' : ''}\$${shift.cashDifference.toStringAsFixed(2)}'),
                if (shift.closedAt != null) _detailRow('Cerrado', _formatDate(shift.closedAt)),
                if (shift.chickensReceived > 0 || shift.chickensButchered > 0 || shift.transfersSent > 0 || shift.transfersReceived > 0) ...[
                  const Divider(),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text('Movimiento de inventario', style: TextStyle(fontWeight: FontWeight.w700, color: GlassColors.accent)),
                  ),
                  if (shift.chickensReceived > 0)
                    _detailRow('Pollos recibidos', '${shift.chickensReceived} (${shift.kgReceived.toStringAsFixed(2)} kg)'),
                  if (shift.chickensButchered > 0)
                    _detailRow('Pollos destazados', '${shift.chickensButchered} (${shift.kgButchered.toStringAsFixed(2)} kg)'),
                  if (shift.transfersSent > 0)
                    _detailRow('Traspasos enviados', '${shift.transfersSent}'),
                  if (shift.transfersReceived > 0)
                    _detailRow('Traspasos recibidos', '${shift.transfersReceived}'),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(width: 140, child: Text(label, style: TextStyle(fontSize: 13, color: Colors.grey[600]))),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600), textAlign: TextAlign.right)),
        ],
      ),
    );
  }

  Widget _buildPagination(int currentPage, int totalPages) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        FilledButton.tonal(
          onPressed: currentPage > 0 ? () => setState(() => _page = currentPage - 1) : null,
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.zero),
          ),
          child: const Text('Anterior', style: TextStyle(fontSize: 12)),
        ),
        const SizedBox(width: 12),
        Text('Pagina ${currentPage + 1} de $totalPages', style: TextStyle(fontSize: 12, color: Colors.grey[500])),
        const SizedBox(width: 12),
        FilledButton.tonal(
          onPressed: currentPage < totalPages - 1 ? () => setState(() => _page = currentPage + 1) : null,
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.zero),
          ),
          child: const Text('Siguiente', style: TextStyle(fontSize: 12)),
        ),
      ],
    );
  }

  Widget _tableHeader(List<String> columns) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.withValues(alpha: 0.08),
        borderRadius: BorderRadius.zero,
      ),
      child: Row(
        children: columns.map((col) {
          final flex = col == '#' || col == '%' || col == 'Fecha' || col == 'Metodo' ? 1 : (col == 'Articulo' || col == 'Empleado' ? 3 : 2);
          return Expanded(
            flex: flex,
            child: Text(col, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: isDark ? Colors.white60 : Colors.grey[600])),
          );
        }).toList(),
      ),
    );
  }

  Widget _tableRow(List<String> cells, bool isPositive, {Color? valueColor}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
      child: Row(
        children: cells.asMap().entries.map((entry) {
          final i = entry.key;
          final cell = entry.value;
          final flex = i == 0 ? 1 : (i == 1 ? 3 : (i == cells.length - 1 ? 2 : 1));
          final isLast = i == cells.length - 1;
          return Expanded(
            flex: flex,
            child: Text(
              cell,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isLast ? FontWeight.w600 : FontWeight.normal,
                color: isLast ? (valueColor ?? (isDark ? Colors.white : Colors.black)) : (isDark ? Colors.white70 : Colors.black87),
              ),
              overflow: TextOverflow.ellipsis,
            ),
          );
        }).toList(),
      ),
    );
  }

  String _formatDate(DateTime? date) {
    if (date == null) return '';
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }
}

class _KpiData {
  const _KpiData(this.label, this.value, this.icon, this.color, this.isCurrency);
  final String label;
  final double value;
  final IconData icon;
  final Color color;
  final bool isCurrency;
}

class _KpiCard extends StatelessWidget {
  const _KpiCard({required this.kpi});
  final _KpiData kpi;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final formatted = kpi.isCurrency
        ? '\$${kpi.value.toStringAsFixed(2)}'
        : kpi.value.toStringAsFixed(0);
    return GlassContainer(
      padding: const EdgeInsets.all(12),
      borderRadius: 0,
      blur: 8,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: kpi.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.zero,
                ),
                child: Icon(kpi.icon, size: 16, color: kpi.color),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Flexible(
            child: Text(kpi.label, style: TextStyle(fontSize: 10, color: isDark ? Colors.white60 : Colors.black54), overflow: TextOverflow.ellipsis, maxLines: 1),
          ),
          const SizedBox(height: 2),
          Flexible(
            child: Text(formatted, style: TextStyle(fontSize: kpi.isCurrency ? 15 : 18, fontWeight: FontWeight.w700), overflow: TextOverflow.ellipsis, maxLines: 1),
          ),
        ],
      ),
    ).withFadeIn();
  }
}

class _ReportSummary {
  const _ReportSummary({
    required this.grossSales,
    required this.netSales,
    required this.cashSales,
    required this.cardSales,
    required this.refunds,
    required this.discounts,
    required this.averageTicket,
    required this.transactionCount,
    required this.products,
    required this.categories,
    required this.employees,
    required this.paymentTypes,
    required this.dailySales,
  });

  final double grossSales;
  final double netSales;
  final double cashSales;
  final double cardSales;
  final double refunds;
  final double discounts;
  final double averageTicket;
  final int transactionCount;
  final Map<String, double> products;
  final Map<String, double> categories;
  final Map<String, double> employees;
  final Map<String, double> paymentTypes;
  final Map<String, double> dailySales;

  factory _ReportSummary.fromSales(List<Sale> sales, {required Map<String, String> employeeNames}) {
    final originalSales = sales.where((sale) => !sale.isRefund).toList();
    final refunds = sales.where((sale) => sale.isRefund).toList();
    final grossSales = originalSales.fold<double>(0, (total, sale) => total + sale.items.fold<double>(0, (sum, item) {
      final quantity = (item['quantity'] as num? ?? 0).toDouble();
      final unitPrice = (item['unitPrice'] as num? ?? 0).toDouble();
      return sum + (quantity * unitPrice);
    }));
    final refundTotal = refunds.fold<double>(0, (total, sale) => total + sale.total);
    final paidTotal = originalSales.fold<double>(0, (total, sale) => total + sale.total);
    final discounts = originalSales.fold<double>(0, (total, sale) => total + sale.discountTotal);
    final cashSales = originalSales.where((sale) => sale.paymentMethod == 'cash').fold<double>(0, (total, sale) => total + sale.total);
    final cardSales = originalSales.where((sale) => sale.paymentMethod == 'card').fold<double>(0, (total, sale) => total + sale.total);
    final products = <String, double>{};
    final categories = <String, double>{};
    final employees = <String, double>{};
    final paymentTypes = <String, double>{};
    final dailySales = <String, double>{};

    for (final sale in originalSales) {
      final employeeName = employeeNames[sale.employeeId] ?? sale.employeeId;
      employees[employeeName] = (employees[employeeName] ?? 0) + sale.total;
      final paymentLabel = sale.paymentMethod == 'card' ? 'Tarjeta' : 'Efectivo';
      paymentTypes[paymentLabel] = (paymentTypes[paymentLabel] ?? 0) + sale.total;
      final date = sale.createdAt ?? sale.clientCreatedAt;
      if (date != null) {
        final key = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
        dailySales[key] = (dailySales[key] ?? 0) + sale.total;
      }
      for (final item in sale.items) {
        final name = item['name'] as String? ?? 'Producto';
        final itemTotal = (item['subtotal'] as num? ?? 0).toDouble();
        final categoryName = item['categoryName'] as String? ?? 'Sin categoria';
        products[name] = (products[name] ?? 0) + itemTotal;
        categories[categoryName.isEmpty ? 'Sin categoria' : categoryName] =
            (categories[categoryName.isEmpty ? 'Sin categoria' : categoryName] ?? 0) + itemTotal;
      }
    }

    for (final refund in refunds) {
      final paymentLabel = refund.paymentMethod == 'card' ? 'Devolucion tarjeta' : 'Devolucion efectivo';
      paymentTypes[paymentLabel] = (paymentTypes[paymentLabel] ?? 0) - refund.total;
      final date = refund.createdAt ?? refund.clientCreatedAt;
      if (date != null) {
        final key = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
        dailySales[key] = (dailySales[key] ?? 0) - refund.total;
      }
    }

    return _ReportSummary(
      grossSales: grossSales,
      netSales: paidTotal - refundTotal,
      cashSales: cashSales,
      cardSales: cardSales,
      refunds: refundTotal,
      discounts: discounts,
      averageTicket: originalSales.isNotEmpty ? paidTotal / originalSales.length : 0,
      transactionCount: originalSales.length,
      products: products,
      categories: categories,
      employees: employees,
      paymentTypes: paymentTypes,
      dailySales: dailySales,
    );
  }
}
