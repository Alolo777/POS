import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../shared/models/employee.dart';
import '../../../shared/models/inventory_movement.dart';
import '../../../shared/models/product.dart';
import '../../../shared/models/product_stock.dart';
import '../../../shared/models/sale.dart';
import '../../../shared/models/shift.dart';
import '../../../shared/models/store.dart';
import '../../../shared/providers/app_session_notifier.dart';
import '../../../features/employees/domain/employee_repository.dart';
import '../../../features/inventory/domain/inventory_repository.dart';
import '../../../features/products/domain/product_repository.dart';
import '../../../features/sales/domain/sale_repository.dart';
import '../../../features/shift/domain/shift_repository.dart';
import '../../../features/inventory/domain/stock_repository.dart';

class BackOfficeScreen extends StatefulWidget {
  const BackOfficeScreen({
    super.key,
    required this.businessId,
    required this.stores,
    required this.currentEmployee,
  });

  final String businessId;
  final List<Store> stores;
  final Employee currentEmployee;

  @override
  State<BackOfficeScreen> createState() => _BackOfficeScreenState();
}

class _BackOfficeScreenState extends State<BackOfficeScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  String? _selectedStoreId;

  bool get _canUseBackOffice => widget.currentEmployee.isOwner || widget.currentEmployee.role == 'admin';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_canUseBackOffice) {
      return const Center(child: Text('Solo administrador o dueno puede entrar a Back Office.'));
    }

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Back Office'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: DropdownButton<String?>(
              value: _selectedStoreId,
              underline: const SizedBox.shrink(),
              items: [
                const DropdownMenuItem<String?>(value: null, child: Text('Todas las sucursales')),
                ...widget.stores.map((store) => DropdownMenuItem<String?>(value: store.id, child: Text(store.name))),
              ],
              onChanged: (value) => setState(() => _selectedStoreId = value),
            ),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Reportes'),
            Tab(text: 'Inventario'),
            Tab(text: 'Empleados'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _ReportsTab(businessId: widget.businessId, selectedStoreId: _selectedStoreId, stores: widget.stores),
          _InventoryTab(
            businessId: widget.businessId,
            selectedStoreId: _selectedStoreId,
            currentEmployee: widget.currentEmployee,
            stores: widget.stores,
          ),
          _EmployeesTab(
            businessId: widget.businessId,
            stores: widget.stores,
          ),
        ],
      ),
    );
  }
}

class _ReportsTab extends StatefulWidget {
  const _ReportsTab({
    required this.businessId,
    required this.selectedStoreId,
    required this.stores,
  });

  final String businessId;
  final String? selectedStoreId;
  final List<Store> stores;

  @override
  State<_ReportsTab> createState() => _ReportsTabState();
}

class _ReportsTabState extends State<_ReportsTab> {
  late DateTime _startDate;
  late DateTime _endDate;
  String? _selectedRange;

  String _storeName(String? id) =>
      widget.stores.firstWhere((s) => s.id == id, orElse: () => const Store(id: '', name: '', address: '', phone: '', active: false)).name;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _startDate = DateTime(now.year, now.month);
    _endDate = DateTime(now.year, now.month, now.day, 23, 59, 59);
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Sale>>(
      stream: context.read<SaleRepository>().watchBusinessSales(businessId: widget.businessId),
      builder: (context, salesSnapshot) {
        if (salesSnapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        if (salesSnapshot.hasError) return Center(child: Text('Error: ${salesSnapshot.error}'));

        return StreamBuilder<List<Employee>>(
          stream: context.read<EmployeeRepository>().watchEmployees(businessId: widget.businessId),
          builder: (context, employeesSnapshot) {
            final employeeNames = {
              for (final employee in employeesSnapshot.data ?? const <Employee>[]) employee.id: employee.name,
            };
            final allSales = salesSnapshot.data ?? const <Sale>[];
            final sales = allSales.where((sale) {
              final date = sale.clientCreatedAt ?? sale.createdAt;
              if (date == null) return false;
              final matchesStore = widget.selectedStoreId == null || sale.storeId == widget.selectedStoreId;
              return matchesStore && !date.isBefore(_startDate) && !date.isAfter(_endDate);
            }).toList();
            final summary = _ReportSummary.fromSales(sales, employeeNames: employeeNames);

            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _filterCard(context),
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text('Recibos leidos: ${allSales.length} · En filtro actual: ${sales.length}'),
                  ),
                ),
                const SizedBox(height: 12),
                if (sales.isEmpty)
                  const Card(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Text('No hay ventas en este rango. Prueba con "Todo" o cambia de sucursal.'),
                    ),
                  ),
                if (sales.isEmpty) const SizedBox(height: 12),
                _metricGrid(context, summary),
                const SizedBox(height: 16),
                if (summary.discountBreakdown.isNotEmpty) ...[
                  _sectionCard(context, 'Descuentos por promocion', summary.discountBreakdown),
                  const SizedBox(height: 16),
                ],
                _dailyChart(context, summary),
                const SizedBox(height: 16),
                _sectionCard(context, 'Ventas por articulo', summary.products),
                _sectionCard(context, 'Ventas por categoria', summary.categories),
                _sectionCard(context, 'Ventas por empleado', summary.employees),
                _sectionCard(context, 'Ventas por tipo de pago', summary.paymentTypes),
                _receiptsCard(context, sales),
                const SizedBox(height: 16),
                _cortesDeCajaCard(context, employeeNames),
              ],
            );
          },
        );
      },
    );
  }

  Widget _filterCard(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Rango de fechas', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text('${_formatDate(_startDate)} - ${_formatDate(_endDate)}'),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ActionChip(
                  label: const Text('Hoy'),
                  backgroundColor: _selectedRange == 'today' ? Colors.orange : null,
                  onPressed: () => _applyQuickRange('today'),
                ),
                ActionChip(
                  label: const Text('Ayer'),
                  backgroundColor: _selectedRange == 'yesterday' ? Colors.orange : null,
                  onPressed: () => _applyQuickRange('yesterday'),
                ),
                ActionChip(
                  label: const Text('Esta semana'),
                  backgroundColor: _selectedRange == 'thisWeek' ? Colors.orange : null,
                  onPressed: () => _applyQuickRange('thisWeek'),
                ),
                ActionChip(
                  label: const Text('Semana pasada'),
                  backgroundColor: _selectedRange == 'lastWeek' ? Colors.orange : null,
                  onPressed: () => _applyQuickRange('lastWeek'),
                ),
                ActionChip(
                  label: const Text('Este mes'),
                  backgroundColor: _selectedRange == 'thisMonth' ? Colors.orange : null,
                  onPressed: () => _applyQuickRange('thisMonth'),
                ),
                ActionChip(
                  label: const Text('Todo'),
                  backgroundColor: _selectedRange == 'all' ? Colors.orange : null,
                  onPressed: () => _applyQuickRange('all'),
                ),
                FilledButton.tonalIcon(
                  onPressed: _pickCustomRange,
                  icon: const Icon(Icons.date_range),
                  label: const Text('Personalizado'),
                  style: _selectedRange == 'custom'
                      ? FilledButton.styleFrom(
                          backgroundColor: Colors.orange,
                          foregroundColor: Colors.white,
                        )
                      : null,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _metricGrid(BuildContext context, _ReportSummary summary) {
    final metrics = [
      ('Ventas brutas', summary.grossSales),
      ('Ventas netas', summary.netSales),
      ('Efectivo', summary.cashSales),
      ('Tarjeta', summary.cardSales),
      ('Devoluciones', summary.refunds),
      ('Descuentos', summary.discounts),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 220,
        mainAxisExtent: 110,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: metrics.length,
      itemBuilder: (context, index) {
        final metric = metrics[index];
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(metric.$1),
                const SizedBox(height: 8),
                Text('\$${metric.$2.toStringAsFixed(2)}', style: Theme.of(context).textTheme.titleLarge),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _sectionCard(BuildContext context, String title, Map<String, double> values) {
    final entries = values.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            if (entries.isEmpty)
              const Text('Sin datos en el rango seleccionado.')
            else
              ...entries.take(20).map(
                    (entry) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(entry.key),
                      trailing: Text('\$${entry.value.toStringAsFixed(2)}'),
                    ),
                  ),
          ],
        ),
      ),
    );
  }

  Widget _dailyChart(BuildContext context, _ReportSummary summary) {
    final maxValue = summary.dailySales.values.fold<double>(0, (max, value) => value > max ? value : max);
    final entries = summary.dailySales.entries.toList()..sort((a, b) => a.key.compareTo(b.key));

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Ventas por dia', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            if (entries.isEmpty)
              const Text('Sin ventas en el rango seleccionado.')
            else
              SizedBox(
                height: 220,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: entries.map((entry) {
                    final heightFactor = maxValue == 0 ? 0.0 : entry.value / maxValue;
                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 3),
                        child: Column(
                          children: [
                            Text('\$${entry.value.toStringAsFixed(0)}', style: const TextStyle(fontSize: 10)),
                            const SizedBox(height: 4),
                            Expanded(
                              child: Align(
                                alignment: Alignment.bottomCenter,
                                child: FractionallySizedBox(
                                  heightFactor: heightFactor.clamp(0.05, 1),
                                  child: Container(
                                    width: double.infinity,
                                    decoration: BoxDecoration(
                                      color: Theme.of(context).colorScheme.primary,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(entry.key.substring(5), style: const TextStyle(fontSize: 10)),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _receiptsCard(BuildContext context, List<Sale> sales) {
    final sorted = [...sales]
      ..sort((a, b) {
        final aDate = a.createdAt ?? a.clientCreatedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bDate = b.createdAt ?? b.clientCreatedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return bDate.compareTo(aDate);
      });

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Recibos', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            if (sorted.isEmpty)
              const Text('Sin recibos en el rango seleccionado.')
            else
              ...sorted.take(30).map(
                    (sale) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(sale.folio),
                      subtitle: Text(_formatDate(sale.createdAt ?? sale.clientCreatedAt)),
                      trailing: Text('\$${sale.total.toStringAsFixed(2)}'),
                    ),
                  ),
          ],
        ),
      ),
    );
  }

  Widget _cortesDeCajaCard(BuildContext context, Map<String, String> employeeNames) {
    return StreamBuilder<List<Shift>>(
      stream: context.read<ShiftRepository>().watchAllClosedShifts(businessId: widget.businessId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Card(child: Center(child: CircularProgressIndicator()));
        }

        final allShifts = snapshot.data ?? const <Shift>[];
        final shifts = allShifts.where((s) {
          final matchesStore = widget.selectedStoreId == null || s.storeId == widget.selectedStoreId;
          final matchesDate = !s.closedAt!.isBefore(_startDate) && !s.closedAt!.isAfter(_endDate);
          return matchesStore && matchesDate;
        }).toList();

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Icon(Icons.account_balance, size: 20),
                    const SizedBox(width: 8),
                    Text('Cortes de Caja', style: Theme.of(context).textTheme.titleMedium),
                  ],
                ),
                const SizedBox(height: 8),
                if (shifts.isEmpty)
                  const Text('Sin cortes en el rango seleccionado.')
                else
                  ...shifts.map((s) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text('Cierre ${_formatDate(s.closedAt)}'),
                    subtitle: Text('Sucursal: ${_storeName(s.storeId)} | Efectivo: \$${s.expectedCash.toStringAsFixed(2)}'),
                    trailing: Text('\$${s.totalSales.toStringAsFixed(2)}'),
                    onTap: () => _showCorteDetail(context, s, employeeNames),
                  )),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showCorteDetail(BuildContext context, Shift shift, Map<String, String> employeeNames) {
    final employeeName = employeeNames[shift.employeeId] ?? shift.employeeId;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Corte ${_formatDate(shift.closedAt)}'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _detailRow('Sucursal', _storeName(shift.storeId)),
              _detailRow('Empleado', employeeName),
              _detailRow('Abierto', _formatDate(shift.openedAt)),
              _detailRow('Cerrado', _formatDate(shift.closedAt)),
              const Divider(),
              _detailRow('Fondo inicial', '\$${(shift.openingCash).toStringAsFixed(2)}'),
              _detailRow('Total ventas', '\$${(shift.totalSales).toStringAsFixed(2)}'),
              _detailRow('Total reembolsos', '-\$${(shift.cashRefunds).toStringAsFixed(2)}'),
              _detailRow('Depositos', '\$${(shift.depositsTotal).toStringAsFixed(2)}'),
              _detailRow('Salidas', '-\$${(shift.payoutsTotal).toStringAsFixed(2)}'),
              const Divider(),
              _detailRow('Efectivo esperado', '\$${(shift.expectedCash).toStringAsFixed(2)}'),
              _detailRow('Efectivo contado', '\$${(shift.closingCash ?? 0).toStringAsFixed(2)}'),
              _detailRow('Diferencia', '\$${(shift.cashDifference).toStringAsFixed(2)}',
                  valueStyle: TextStyle(
                    color: shift.cashDifference >= 0 ? Colors.green : Colors.red,
                    fontWeight: FontWeight.bold,
                  )),
              if (shift.chickensReceived > 0 || shift.chickensButchered > 0 || shift.transfersSent > 0 || shift.transfersReceived > 0) ...[
                const Divider(),
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text('Movimiento de inventario', style: const TextStyle(fontWeight: FontWeight.w700)),
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
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cerrar'))],
      ),
    );
  }

  Widget _detailRow(String label, String value, {TextStyle? valueStyle}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey)),
          Text(value, style: valueStyle),
        ],
      ),
    );
  }

  void _applyQuickRange(String value) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    setState(() {
      _selectedRange = value;
      switch (value) {
        case 'yesterday':
          _startDate = today.subtract(const Duration(days: 1));
          _endDate = DateTime(_startDate.year, _startDate.month, _startDate.day, 23, 59, 59);
          break;
        case 'thisWeek':
          _startDate = today.subtract(Duration(days: today.weekday - 1));
          _endDate = DateTime(now.year, now.month, now.day, 23, 59, 59);
          break;
        case 'lastWeek':
          final thisWeekStart = today.subtract(Duration(days: today.weekday - 1));
          _startDate = thisWeekStart.subtract(const Duration(days: 7));
          _endDate = thisWeekStart.subtract(const Duration(seconds: 1));
          break;
        case 'thisMonth':
          _startDate = DateTime(now.year, now.month);
          _endDate = DateTime(now.year, now.month, now.day, 23, 59, 59);
          break;
        case 'all':
          _startDate = DateTime(2020);
          _endDate = DateTime(now.year, now.month, now.day, 23, 59, 59);
          break;
        default:
          _startDate = today;
          _endDate = DateTime(now.year, now.month, now.day, 23, 59, 59);
      }
    });
  }

  Future<void> _pickCustomRange() async {
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDateRange: DateTimeRange(start: _startDate, end: _endDate),
    );
    if (range == null) return;
    setState(() {
      _selectedRange = 'custom';
      _startDate = DateTime(range.start.year, range.start.month, range.start.day);
      _endDate = DateTime(range.end.year, range.end.month, range.end.day, 23, 59, 59);
    });
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'Fecha pendiente';
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }
}

class _InventoryTab extends StatefulWidget {
  const _InventoryTab({
    required this.businessId,
    required this.selectedStoreId,
    required this.currentEmployee,
    required this.stores,
  });

  final String businessId;
  final String? selectedStoreId;
  final Employee currentEmployee;
  final List<Store> stores;

  @override
  State<_InventoryTab> createState() => _InventoryTabState();
}

class _InventoryTabState extends State<_InventoryTab> {
  late final Stream<List<InventoryMovement>> _movementsStream;

  String _storeName(String? id) =>
      widget.stores.firstWhere((s) => s.id == id, orElse: () => const Store(id: '', name: '', address: '', phone: '', active: false)).name;

  @override
  void initState() {
    super.initState();
    _movementsStream = context.read<InventoryRepository>().watchMovements(businessId: widget.businessId);
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Product>>(
      stream: context.read<ProductRepository>().watchProducts(businessId: widget.businessId),
      builder: (context, productsSnapshot) {
        if (productsSnapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        if (productsSnapshot.hasError) return Center(child: Text('Error: ${productsSnapshot.error}'));
        return StreamBuilder<Map<String, ProductStock>>(
          stream: widget.selectedStoreId == null
              ? const Stream<Map<String, ProductStock>>.empty()
              : context.read<StockRepository>().watchStockByStore(businessId: widget.businessId, storeId: widget.selectedStoreId!),
          builder: (context, stockSnapshot) {
            final stocks = stockSnapshot.data ?? const <String, ProductStock>{};
            final products = (productsSnapshot.data ?? const <Product>[]).map((product) {
              final stock = stocks[product.id];
              return Product(
                id: product.id,
                name: product.name,
                categoryId: product.categoryId,
                categoryName: product.categoryName,
                sellBy: product.sellBy,
                price: product.price,
                cost: product.cost,
                ref: product.ref,
                trackStock: product.trackStock,
                stockQuantity: stock?.stockQuantity ?? 0,
                lowStockAlertQuantity: stock?.lowStockAlertQuantity ?? product.lowStockAlertQuantity,
                presentationType: product.presentationType,
                presentationShape: product.presentationShape,
                presentationColor: product.presentationColor,
                imageUrl: product.imageUrl,
                localImagePath: product.localImagePath,
                active: product.active,
              );
            }).toList();
            final tracked = products.where((product) => product.trackStock).toList();
            final lowStock = tracked.where((product) => product.stockQuantity <= product.lowStockAlertQuantity).toList();

            return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: ListTile(
                leading: const Icon(Icons.warning_amber),
                title: const Text('Alertas de bajo stock'),
                subtitle: Text(
                  widget.selectedStoreId == null
                      ? '${lowStock.length} productos requieren revision. Selecciona una sucursal para ajustar inventario.'
                      : '${lowStock.length} productos requieren revision',
                ),
              ),
            ),
            const SizedBox(height: 12),
            ...tracked.map(
              (product) => Card(
                child: ListTile(
                  title: Text(product.name),
                  subtitle: Text('Stock: ${_formatQuantity(product.stockQuantity)} · Bajo: ${_formatQuantity(product.lowStockAlertQuantity)}'),
                  trailing: FilledButton.tonal(
                    onPressed: widget.selectedStoreId == null
                        ? null
                        : () => _showAdjustDialog(context, product),
                    child: const Text('Ajustar'),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text('Movimientos recientes', style: Theme.of(context).textTheme.titleMedium),
            StreamBuilder<List<InventoryMovement>>(
              stream: _movementsStream,
              builder: (context, snapshot) {
                final movements = (snapshot.data ?? const <InventoryMovement>[])
                    .where((movement) => widget.selectedStoreId == null || movement.storeId == widget.selectedStoreId)
                    .toList();
                if (movements.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.all(12),
                    child: Text('Sin movimientos.'),
                  );
                }
                return Column(
                  children: movements.take(20).map((movement) {
                    String subtitle = movement.typeLabel;
                    if (movement.reason.isNotEmpty) subtitle = '$subtitle · ${movement.reason}';
                    if (movement.type == 'transfer') {
                      final from = (movement.fromStoreName?.isNotEmpty == true)
                          ? movement.fromStoreName!
                          : _storeName(movement.fromStoreId);
                      final to = (movement.toStoreName?.isNotEmpty == true)
                          ? movement.toStoreName!
                          : _storeName(movement.toStoreId);
                      if (from.isNotEmpty && to.isNotEmpty) {
                        subtitle = '$subtitle\nDe $from → Para $to';
                      }
                    }
                    return ListTile(
                      title: Text(movement.productName),
                      subtitle: Text(subtitle),
                      trailing: Text(movement.difference >= 0 ? '+${_formatQuantity(movement.difference)}' : _formatQuantity(movement.difference)),
                    );
                  }).toList(),
                );
              },
            ),
            const SizedBox(height: 24),
            Text('Anomalías de destazado', style: Theme.of(context).textTheme.titleMedium),
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('businesses').doc(widget.businessId)
                  .collection('butcherAnomalies')
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) return const Padding(padding: EdgeInsets.all(12), child: Text('Error al cargar anomalías.'));
                final docs = snapshot.data?.docs ?? [];
                final filtered = docs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  return widget.selectedStoreId == null || data['storeId'] == widget.selectedStoreId;
                }).toList();
                if (filtered.isEmpty) return const Padding(padding: EdgeInsets.all(12), child: Text('Sin anomalías.'));
                return Column(
                  children: filtered.take(20).map((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    final type = data['type'] as String? ?? '';
                    final remainingKg = (data['remainingKg'] as num? ?? 0).toDouble();
                    final remainingChickens = (data['remainingChickens'] as num? ?? 0).toInt();
                    final butcheredKg = (data['butcheredKg'] as num? ?? 0).toDouble();
                    final butcheredChickens = (data['butcheredChickens'] as num? ?? 0).toInt();
                    final employeeName = data['employeeName'] as String? ?? '';
                    final typeLabel = type == 'excess_kg'
                        ? 'Sobran kg'
                        : type == 'excess_chickens'
                            ? 'Sobran pollos'
                            : type;
                    final subtitle = type == 'excess_kg'
                        ? 'Quedan ${remainingKg.toStringAsFixed(2)} kg · 0 pollos'
                        : 'Quedan $remainingChickens pollos · 0 kg';

                    return Card(
                      child: ListTile(
                        leading: Icon(
                          type == 'excess_kg' ? Icons.scale : Icons.format_list_numbered,
                          color: Colors.orange,
                        ),
                        title: Text('$typeLabel · $employeeName'),
                        subtitle: Text(subtitle),
                        trailing: Text('${butcheredKg.toStringAsFixed(1)} kg / $butcheredChickens pollos',
                            style: const TextStyle(fontSize: 12)),
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ],
            );
          },
        );
      },
    );
  }

  Future<void> _showAdjustDialog(BuildContext context, Product product) async {
    final storeId = widget.selectedStoreId;
    if (storeId == null) return;

    final result = await showDialog<({double quantity, String reason})>(
      context: context,
      builder: (context) => _InventoryAdjustDialog(product: product),
    );
    if (result == null || !context.mounted) return;

    try {
      await context.read<InventoryRepository>().adjustStock(
        businessId: widget.businessId,
        storeId: storeId,
        product: product,
        newQuantity: result.quantity,
        reason: result.reason,
        employeeId: widget.currentEmployee.id,
      );
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Inventario ajustado')));
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  String _formatQuantity(double value) {
    if (value % 1 == 0) return value.toStringAsFixed(0);
    return value.toStringAsFixed(2);
  }
}

class _EmployeesTab extends StatelessWidget {
  const _EmployeesTab({required this.businessId, required this.stores});

  final String businessId;
  final List<Store> stores;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showEmployeeDialog(context),
        child: const Icon(Icons.add),
      ),
      body: StreamBuilder<List<Employee>>(
        stream: context.read<EmployeeRepository>().watchEmployees(businessId: businessId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}'));
          final employees = snapshot.data ?? const <Employee>[];
          if (employees.isEmpty) return const Center(child: Text('Todavia no hay empleados registrados.'));
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: employees.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final employee = employees[index];
              return ListTile(
                leading: Icon(employee.active ? Icons.person : Icons.person_off),
                title: Text(employee.name),
                subtitle: Text('${employee.email} · ${employee.role}'),
                trailing: employee.isOwner ? const Text('Dueno') : null,
                onTap: () => _showEmployeeDialog(context, employee: employee),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _showEmployeeDialog(BuildContext context, {Employee? employee}) async {
    final result = await showDialog<_EmployeeDialogResult>(
      context: context,
      builder: (context) => _EmployeeDialog(employee: employee, stores: stores),
    );
    if (result == null || !context.mounted) return;

    try {
      if (result.deactivate) {
        await context.read<EmployeeRepository>().deactivateEmployee(
          businessId: businessId,
          employeeId: employee!.id,
        );
      } else if (employee == null) {
        await context.read<EmployeeRepository>().addEmployee(
          businessId: businessId,
          name: result.name,
          email: result.email,
          role: result.role,
          pin: result.pin,
          storeIds: result.storeIds,
          permissions: result.permissions,
        );
      } else {
        final pin = result.pin.isNotEmpty ? result.pin : employee.pin;
        await context.read<EmployeeRepository>().updateEmployee(
          businessId: businessId,
          employee: employee,
          role: result.role,
          pin: pin,
          storeIds: result.storeIds,
          permissions: result.permissions,
          active: result.active,
        );
      }
      if (!context.mounted) return;
      context.read<AppSessionNotifier>().refreshSession();
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
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
    required this.discountBreakdown,
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
  final Map<String, double> discountBreakdown;
  final Map<String, double> products;
  final Map<String, double> categories;
  final Map<String, double> employees;
  final Map<String, double> paymentTypes;
  final Map<String, double> dailySales;

  factory _ReportSummary.fromSales(List<Sale> sales, {required Map<String, String> employeeNames}) {
    final originalSales = sales.where((sale) => !sale.isRefund && !sale.isCancelled).toList();
    final refunds = sales.where((sale) => sale.isRefund).toList();
    final grossSales = originalSales.fold<double>(0, (total, sale) => total + sale.items.fold<double>(0, (sum, item) {
          final quantity = (item['quantity'] as num? ?? 0).toDouble();
          final returned = _returnedQuantity(item, quantity);
          final unitPrice = (item['unitPrice'] as num? ?? 0).toDouble();
          return sum + (quantity - returned) * unitPrice;
        }));
    final refundTotal = refunds.fold<double>(0, (total, sale) => total + sale.total);
    final paidTotal = originalSales.fold<double>(0, (total, sale) => total + sale.total);
    final discounts = originalSales.fold<double>(0, (total, sale) {
      final factor = 1 - _returnedRatio(sale);
      return total + (sale.discountTotal + _lineDiscounts(sale)) * factor;
    });
    final cashSales = originalSales.where((sale) => sale.paymentMethod == 'cash').fold<double>(0, (total, sale) => total + sale.total);
    final cardSales = originalSales.where((sale) => sale.paymentMethod == 'card').fold<double>(0, (total, sale) => total + sale.total);
    final products = <String, double>{};
    final categories = <String, double>{};
    final employees = <String, double>{};
    final paymentTypes = <String, double>{};
    final dailySales = <String, double>{};
    final discountBreakdown = <String, double>{};

    for (final sale in originalSales) {
      final employeeName = employeeNames[sale.employeeId] ?? sale.employeeId;
      employees[employeeName] = (employees[employeeName] ?? 0) + sale.total;
      final paymentLabel = sale.paymentMethod == 'card' ? 'Tarjeta' : 'Efectivo';
      paymentTypes[paymentLabel] = (paymentTypes[paymentLabel] ?? 0) + sale.total;
      if (sale.discountTotal > 0) {
        final label = sale.discountName.isNotEmpty ? sale.discountName : 'Descuento sin nombre';
        discountBreakdown[label] = (discountBreakdown[label] ?? 0) + sale.discountTotal * (1 - _returnedRatio(sale));
      }
      for (final item in sale.items) {
        final lineDiscount = (item['discount'] as num? ?? 0).toDouble();
        if (lineDiscount > 0) {
          final lineName = item['discountName'] as String? ?? '';
          final label = lineName.isNotEmpty ? lineName : 'Descuento por producto';
          discountBreakdown[label] = (discountBreakdown[label] ?? 0) + lineDiscount * (1 - _returnedRatio(sale));
        }
      }
      final date = sale.createdAt ?? sale.clientCreatedAt;
      if (date != null) {
        final key = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
        dailySales[key] = (dailySales[key] ?? 0) + sale.total;
      }

      for (final item in sale.items) {
        final name = item['name'] as String? ?? 'Producto';
        final itemSubtotal = (item['subtotal'] as num? ?? 0).toDouble();
        final quantity = (item['quantity'] as num? ?? 0).toDouble();
        final returned = _returnedQuantity(item, quantity);
        final effectiveFactor = quantity > 0 ? (quantity - returned) / quantity : 1.0;
        final itemTotal = itemSubtotal * effectiveFactor;
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
      discountBreakdown: discountBreakdown,
      products: products,
      categories: categories,
      employees: employees,
      paymentTypes: paymentTypes,
      dailySales: dailySales,
    );
  }

  static double _lineDiscounts(Sale sale) {
    return sale.items.fold<double>(0, (total, item) => total + (item['discount'] as num? ?? 0).toDouble());
  }

  static double _returnedQuantity(Map<String, dynamic> item, double quantity) {
    final returned = (item['returnedQuantity'] as num? ?? 0).toDouble();
    return returned.clamp(0.0, quantity).toDouble();
  }

  /// Proporcion devuelta de la venta (por importe bruto). Es 0 para ventas
  /// sin devoluciones parciales, por lo que no altera metricas normales.
  static double _returnedRatio(Sale sale) {
    var gross = 0.0;
    var returned = 0.0;
    for (final item in sale.items) {
      final quantity = (item['quantity'] as num? ?? 0).toDouble();
      final unitPrice = (item['unitPrice'] as num? ?? 0).toDouble();
      gross += quantity * unitPrice;
      returned += _returnedQuantity(item, quantity) * unitPrice;
    }
    if (gross <= 0) return 0;
    return (returned / gross).clamp(0.0, 1.0).toDouble();
  }
}

class _InventoryAdjustDialog extends StatefulWidget {
  const _InventoryAdjustDialog({required this.product});

  final Product product;

  @override
  State<_InventoryAdjustDialog> createState() => _InventoryAdjustDialogState();
}

class _InventoryAdjustDialogState extends State<_InventoryAdjustDialog> {
  late final TextEditingController _quantityController;
  final _reasonController = TextEditingController();
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _quantityController = TextEditingController(text: widget.product.stockQuantity.toStringAsFixed(widget.product.sellBy == 'unit' ? 0 : 2));
  }

  @override
  void dispose() {
    _quantityController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Ajustar ${widget.product.name}'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _quantityController,
            keyboardType: TextInputType.numberWithOptions(decimal: widget.product.sellBy == 'weight'),
            decoration: InputDecoration(labelText: 'Inventario real', errorText: _errorMessage, border: const OutlineInputBorder()),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _reasonController,
            decoration: const InputDecoration(labelText: 'Motivo', border: OutlineInputBorder()),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        FilledButton(onPressed: _submit, child: const Text('Guardar')),
      ],
    );
  }

  void _submit() {
    final quantity = double.tryParse(_quantityController.text.trim().replaceAll(',', '.'));
    if (quantity == null || quantity < 0) {
      setState(() => _errorMessage = 'Cantidad no valida');
      return;
    }
    if (widget.product.sellBy == 'unit' && quantity % 1 != 0) {
      setState(() => _errorMessage = 'Debe ser cantidad entera');
      return;
    }
    Navigator.pop(context, (quantity: quantity, reason: _reasonController.text));
  }
}

class _EmployeeDialogResult {
  const _EmployeeDialogResult({
    required this.name,
    required this.email,
    required this.role,
    required this.pin,
    required this.storeIds,
    required this.permissions,
    required this.active,
    this.deactivate = false,
  });

  final String name;
  final String email;
  final String role;
  final String pin;
  final List<String> storeIds;
  final List<String> permissions;
  final bool active;
  final bool deactivate;
}

class _EmployeeDialog extends StatefulWidget {
  const _EmployeeDialog({required this.stores, this.employee});

  final List<Store> stores;
  final Employee? employee;

  @override
  State<_EmployeeDialog> createState() => _EmployeeDialogState();
}

class _EmployeeDialogState extends State<_EmployeeDialog> {
  static const _featurePermissions = <(String, String)>[
    ('pos', 'Venta (POS)'),
    ('receipts', 'Recibos / historial'),
    ('products', 'Productos'),
    ('shift', 'Turnos / caja'),
    ('butcher', 'Destazar'),
    ('poultry', 'Recibir pollo'),
    ('transfers', 'Enviar / recibir mercancía'),
  ];

  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _pinController = TextEditingController();
  late String _role;
  late bool _active;
  late final Set<String> _storeIds;
  late Set<String> _permissions;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    final employee = widget.employee;
    _nameController.text = employee?.name ?? '';
    _emailController.text = employee?.email ?? '';
    _role = employee?.role ?? 'cashier';
    _active = employee?.active ?? true;
    _storeIds = {...(employee?.storeIds ?? widget.stores.map((store) => store.id))};
    _permissions = employee != null
        ? {...employee.permissions}
        : {..._permissionsForRole(_role)};
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _pinController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.employee != null;
    final isOwner = widget.employee?.isOwner ?? false;
    return AlertDialog(
      title: Text(isEditing ? 'Editar empleado' : 'Nuevo empleado'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Nombre', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(labelText: 'Correo', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _pinController,
              keyboardType: TextInputType.number,
              obscureText: true,
              decoration: InputDecoration(
                labelText: 'PIN',
                helperText: isEditing ? 'Dejar vacio para no cambiar' : 'Minimo 4 digitos',
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _role,
              decoration: const InputDecoration(labelText: 'Rol', border: OutlineInputBorder()),
              items: [
                if (isOwner) const DropdownMenuItem(value: 'owner', child: Text('Duenno')),
                const DropdownMenuItem(value: 'admin', child: Text('Administrador')),
                const DropdownMenuItem(value: 'manager', child: Text('Gerente')),
                const DropdownMenuItem(value: 'cashier', child: Text('Cajero')),
              ],
              onChanged: isOwner ? null : (value) => setState(() => _role = value ?? _role),
            ),
            const SizedBox(height: 12),
            Align(alignment: Alignment.centerLeft, child: Text('Sucursales', style: Theme.of(context).textTheme.titleSmall)),
            ...widget.stores.map(
              (store) => CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(store.name),
                value: _storeIds.contains(store.id),
                onChanged: (value) => setState(() {
                  if (value == true) {
                    _storeIds.add(store.id);
                  } else {
                    _storeIds.remove(store.id);
                  }
                }),
              ),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: Text('Funcionalidades', style: Theme.of(context).textTheme.titleSmall),
            ),
            ..._featurePermissions.map(
              (entry) => CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                title: Text(entry.$2),
                value: _permissions.contains(entry.$1),
                onChanged: _role == 'admin'
                    ? null
                    : (value) => setState(() {
                        if (value == true) {
                          _permissions.add(entry.$1);
                        } else {
                          _permissions.remove(entry.$1);
                        }
                      }),
              ),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Activo'),
              value: _active,
              onChanged: (value) => setState(() => _active = value),
            ),
            if (_errorMessage != null) Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        if (isEditing && !isOwner)
          TextButton(
            onPressed: () => _confirmDeactivate(context),
            child: Text('Desactivar', style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ),
        FilledButton(onPressed: _submit, child: const Text('Guardar')),
      ],
    );
  }

  void _confirmDeactivate(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Desactivar empleado'),
        content: Text('Desactivar a ${widget.employee!.name}? Podras reactivarlo despues.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pop(context, _EmployeeDialogResult(
                name: widget.employee!.name,
                email: widget.employee!.email,
                role: widget.employee!.role,
                pin: '',
                storeIds: widget.employee!.storeIds,
                permissions: widget.employee!.permissions,
                active: false,
                deactivate: true,
              ));
            },
            child: const Text('Desactivar'),
          ),
        ],
      ),
    );
  }

  void _submit() {
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final pin = _pinController.text.trim();
    final isEditing = widget.employee != null;

    if (name.isEmpty || email.isEmpty || _storeIds.isEmpty) {
      setState(() => _errorMessage = 'Completa nombre, correo y sucursal');
      return;
    }
    if (!isEditing && pin.length < 4) {
      setState(() => _errorMessage = 'El PIN debe tener al menos 4 digitos');
      return;
    }

    Navigator.pop(
      context,
      _EmployeeDialogResult(
        name: name,
        email: email,
        role: _role,
        pin: pin,
        storeIds: _storeIds.toList(),
        permissions: _role == 'admin' ? ['*'] : _permissions.toList(),
        active: _active,
      ),
    );
  }

  List<String> _permissionsForRole(String role) {
    if (role == 'admin') return ['*'];
    if (role == 'manager') return ['pos', 'receipts', 'shift', 'products'];
    return ['pos'];
  }
}
