import 'package:cloud_firestore/cloud_firestore.dart';

import 'report_definition.dart';

/// Construye todas las hojas del reporte a partir de los documentos crudos de
/// Firestore (cada mapa ya incluye su `id`). Esta función es pura: no hace
/// I/O y es fácil de probar.
///
/// Convierte los datos técnicos (IDs, estados internos, JSON) en información
/// útil para un administrador, con nombres claros y valores traducidos.
List<ReportSheet> buildReportSheets({
  required String businessName,
  required String currencySymbol,
  required DateTime generatedAt,
  required List<Map<String, dynamic>> stores,
  required List<Map<String, dynamic>> products,
  required List<Map<String, dynamic>> stock,
  required List<Map<String, dynamic>> sales,
  required List<Map<String, dynamic>> movements,
  required List<Map<String, dynamic>> employees,
  required List<Map<String, dynamic>> shifts,
  required List<Map<String, dynamic>> transfers,
  required List<Map<String, dynamic>> poultryReceivings,
  required List<Map<String, dynamic>> butcheringRecords,
  required List<Map<String, dynamic>> butcherReceipts,
  required List<Map<String, dynamic>> categories,
  required List<Map<String, dynamic>> discounts,
  required List<Map<String, dynamic>> modifiers,
}) {
  final storeNames = _namesById(stores);
  final productNames = _namesById(products);
  final employeeNames = _namesById(employees);
  final shiftOpenedAt = <String, DateTime?>{
    for (final s in shifts) _id(s): _date(s['openedAt']),
  };

  return [
    _resumenSheet(
      businessName: businessName,
      generatedAt: generatedAt,
      currencySymbol: currencySymbol,
      storeNames: storeNames,
      productNames: productNames,
      stores: stores,
      products: products,
      sales: sales,
      employees: employees,
      shifts: shifts,
      transfers: transfers,
      movements: movements,
      poultryReceivings: poultryReceivings,
      butcheringRecords: butcheringRecords,
    ),
    _storesSheet(stores),
    _productsSheet(products),
    _stockSheet(stock, storeNames, productNames),
    _salesSheet(
      sales,
      storeNames: storeNames,
      employeeNames: employeeNames,
      shiftOpenedAt: shiftOpenedAt,
      currencySymbol: currencySymbol,
    ),
    _movementsSheet(movements, storeNames, productNames, employeeNames),
    _employeesSheet(employees, storeNames),
    _shiftsSheet(shifts, storeNames, employeeNames),
    _cashMovementsSheet(shifts, storeNames, employeeNames),
    _transfersSheet(transfers, storeNames, employeeNames),
    _poultrySheet(poultryReceivings, storeNames, employeeNames),
    _butcheringSheet(butcheringRecords, storeNames, employeeNames),
    _butcherReceiptsSheet(butcherReceipts, storeNames, employeeNames),
    _categoriesSheet(categories),
    _discountsSheet(discounts, currencySymbol),
    _modifiersSheet(modifiers),
  ];
}

// ---------------------------------------------------------------------------
// Hoja Resumen
// ---------------------------------------------------------------------------

ReportSheet _resumenSheet({
  required String businessName,
  required DateTime generatedAt,
  required String currencySymbol,
  required Map<String, String> storeNames,
  required Map<String, String> productNames,
  required List<Map<String, dynamic>> stores,
  required List<Map<String, dynamic>> products,
  required List<Map<String, dynamic>> sales,
  required List<Map<String, dynamic>> employees,
  required List<Map<String, dynamic>> shifts,
  required List<Map<String, dynamic>> transfers,
  required List<Map<String, dynamic>> movements,
  required List<Map<String, dynamic>> poultryReceivings,
  required List<Map<String, dynamic>> butcheringRecords,
}) {
  final validSales = _validSales(sales);
  final totalSales = _sum(validSales, 'total');
  final salesByStore = <String, List<Map<String, dynamic>>>{};
  for (final sale in validSales) {
    salesByStore.putIfAbsent(_str(sale['storeId']), () => []).add(sale);
  }

  final lowStock = products.where(_isLowStock).length;
  final outOfStock = products.where(_isOutOfStock).length;
  final chickensReceived =
      _sum(poultryReceivings, 'totalChickens').toInt();
  final kgReceived = _sum(poultryReceivings, 'totalWeightKg');
  final butcheredChickens = _sum(butcheringRecords, 'chickenCount').toInt();
  final butcheredKg = _sum(butcheringRecords, 'totalActualKg');

  final indicators = <List<Object?>>[
    ['Negocio', businessName],
    ['Fecha de generación', _dateTimeText(generatedAt)],
    ['Total de ventas', _formatMoney(totalSales, currencySymbol)],
    ['Ventas registradas', validSales.length],
    ['Sucursales', stores.length],
    ['Productos registrados', products.length],
    ['Productos con inventario bajo', lowStock],
    ['Productos agotados', outOfStock],
    ['Empleados', employees.length],
    ['Turnos', shifts.length],
    ['Traspasos realizados', transfers.length],
    ['Movimientos de inventario', movements.length],
    ['Pollos recibidos', chickensReceived],
    ['Peso recibido (kg)', _round(kgReceived)],
    ['Pollos destazados', butcheredChickens],
    ['Peso destazado (kg)', _round(butcheredKg)],
  ];

  final storeRows = <List<Object?>>[];
  final storeOrder = salesByStore.keys.toList()
    ..sort((a, b) => _sum(salesByStore[b]!, 'total')
            .compareTo(_sum(salesByStore[a]!, 'total')));
  for (final storeId in storeOrder) {
    final storeSales = salesByStore[storeId]!;
    storeRows.add([
      storeNames[storeId] ?? _str(storeId),
      storeSales.length,
      _sum(storeSales, 'total'),
    ]);
  }
  final storeTotals = storeOrder.isEmpty
      ? null
      : [
          'Total',
          validSales.length,
          totalSales,
        ];

  final bestSellers = _topProducts(validSales, limit: 5);

  return ReportSheet(
    title: 'Resumen',
    tables: [
      ReportTable(
        caption: 'Indicadores generales',
        headers: const ['Indicador', 'Valor'],
        rows: indicators,
      ),
      ReportTable(
        caption: 'Ventas por sucursal',
        headers: const ['Sucursal', 'Ventas', 'Total'],
        rows: storeRows,
        moneyColumns: const {2},
        totalsRow: storeTotals,
      ),
      ReportTable(
        caption: 'Productos más vendidos',
        headers: const ['Producto', 'Cantidad vendida'],
        rows: [
          for (final top in bestSellers)
            [productNames[top.$1] ?? top.$1, top.$2],
        ],
      ),
    ],
  );
}

// ---------------------------------------------------------------------------
// Hojas operativas
// ---------------------------------------------------------------------------

ReportSheet _storesSheet(List<Map<String, dynamic>> stores) {
  return ReportSheet(
    title: 'Sucursales',
    tables: [
      ReportTable(
        headers: const ['Nombre', 'Dirección', 'Teléfono', 'Activa'],
        rows: [
          for (final s in stores)
            [_str(s['name']), _str(s['address']), _str(s['phone']), _yesNo(s['active'])],
        ],
      ),
    ],
  );
}

ReportSheet _productsSheet(List<Map<String, dynamic>> products) {
  return ReportSheet(
    title: 'Productos',
    tables: [
      ReportTable(
        headers: const [
          'Referencia', 'Nombre', 'Categoría', 'Precio', 'Costo',
          'Controla stock', 'Stock', 'Alerta stock', 'Activo',
        ],
        moneyColumns: const {3, 4},
        rows: [
          for (final p in products)
            [
              _str(p['ref']), _str(p['name']), _str(p['categoryName']),
              _num(p['price']), _num(p['cost']), _yesNo(p['trackStock']),
              _num(p['stockQuantity']), _num(p['lowStockAlertQuantity']),
              _yesNo(p['active']),
            ],
        ],
      ),
    ],
  );
}

ReportSheet _stockSheet(
  List<Map<String, dynamic>> stock,
  Map<String, String> storeNames,
  Map<String, String> productNames,
) {
  return ReportSheet(
    title: 'Inventario',
    tables: [
      ReportTable(
        headers: const ['Sucursal', 'Producto', 'Stock', 'Alerta stock', 'Pollos', 'Estado'],
        rows: [
          for (final s in stock)
            [
              storeNames[_str(s['storeId'])] ?? _str(s['storeId']),
              productNames[_str(s['productId'])] ?? _str(s['productName']),
              _num(s['stockQuantity']), _num(s['lowStockAlertQuantity']),
              _num(s['chickenCount']), _stockStatus(s),
            ],
        ],
      ),
    ],
  );
}

ReportSheet _salesSheet(
  List<Map<String, dynamic>> sales, {
  required Map<String, String> storeNames,
  required Map<String, String> employeeNames,
  required Map<String, DateTime?> shiftOpenedAt,
  required String currencySymbol,
}) {
  final totals = _salesTotals(sales);
  return ReportSheet(
    title: 'Ventas',
    tables: [
      ReportTable(
        headers: const [
          'Folio', 'Sucursal', 'Empleado', 'Apertura de turno', 'Fecha',
          'Método de pago', 'Tipo', 'Estado', 'Subtotal', 'Descuento',
          'Impuesto', 'Total', 'Efectivo', 'Cambio', 'Cancelada',
          'Razón de cancelación', 'Artículos',
        ],
        moneyColumns: const {8, 9, 10, 11, 12, 13},
        rows: [
          for (final s in sales)
            [
              _str(s['folio']),
              storeNames[_str(s['storeId'])] ?? _str(s['storeId']),
              employeeNames[_str(s['employeeId'])] ?? _str(s['employeeId']),
              shiftOpenedAt[_str(s['shiftId'])],
              _date(s['createdAt'] ?? s['clientCreatedAt']),
              _paymentMethod(s['paymentMethod']),
              _saleType(s['type']),
              _status(s['status']),
              _num(s['subtotal']), _num(s['discountTotal']), _num(s['taxTotal']),
              _num(s['total']), _num(s['cashReceived']), _num(s['changeDue']),
              _cancelled(s),
              _str(s['cancelReason']),
              (s['items'] as List?)?.length ?? 0,
            ],
        ],
        totalsRow: [
          'Total (ventas válidas)', '', '', '', '', '', '', '',
          totals['subtotal'], totals['discount'], totals['tax'], totals['total'],
          totals['cashReceived'], totals['changeDue'], '', '', '',
        ],
      ),
    ],
  );
}

ReportSheet _movementsSheet(
  List<Map<String, dynamic>> movements,
  Map<String, String> storeNames,
  Map<String, String> productNames,
  Map<String, String> employeeNames,
) {
  return ReportSheet(
    title: 'Movimientos de inventario',
    tables: [
      ReportTable(
        headers: const [
          'Sucursal', 'Producto', 'Tipo', 'Anterior', 'Nuevo', 'Diferencia',
          'Motivo', 'Empleado', 'Fecha', 'Desde', 'Hasta',
        ],
        rows: [
          for (final m in movements)
            [
              storeNames[_str(m['storeId'])] ?? _str(m['storeId']),
              productNames[_str(m['productId'])] ?? _str(m['productName']),
              _movementType(m['type']),
              _num(m['previousQuantity']), _num(m['newQuantity']),
              _num(m['difference'] ?? (m['storedDifference'] ?? 0)),
              _str(m['reason']),
              employeeNames[_str(m['employeeId'])] ?? _str(m['employeeId']),
              _date(m['createdAt']),
              _optionalStoreName(storeNames, m['fromStoreId'], m['fromStoreName']),
              _optionalStoreName(storeNames, m['toStoreId'], m['toStoreName']),
            ],
        ],
      ),
    ],
  );
}

ReportSheet _employeesSheet(
  List<Map<String, dynamic>> employees,
  Map<String, String> storeNames,
) {
  return ReportSheet(
    title: 'Empleados',
    tables: [
      ReportTable(
        headers: const ['Nombre', 'Email', 'Rol', 'Sucursales', 'Activo'],
        rows: [
          for (final e in employees)
            [
              _str(e['name']), _str(e['email']), _role(e['role']),
              ((e['storeIds'] as List?) ?? const [])
                  .map((id) => storeNames[id.toString()] ?? id.toString())
                  .join(', '),
              _yesNo(e['active']),
            ],
        ],
      ),
    ],
  );
}

ReportSheet _shiftsSheet(
  List<Map<String, dynamic>> shifts,
  Map<String, String> storeNames,
  Map<String, String> employeeNames,
) {
  return ReportSheet(
    title: 'Turnos',
    tables: [
      ReportTable(
        headers: const [
          'Sucursal', 'Empleado', 'Estado', 'Apertura', 'Cierre',
          'Efectivo inicial', 'Efectivo final', 'Ventas efectivo',
          'Ventas tarjeta', 'Ventas total', 'Devoluciones', 'Depósitos',
          'Gastos', 'Efectivo esperado', 'Diferencia', 'Pollos recibidos',
          'Kg recibidos', 'Pollos destazados', 'Kg destazados', 'Merma kg',
        ],
        moneyColumns: const {5, 6, 7, 8, 9, 10, 11, 12, 13, 14},
        rows: [
          for (final s in shifts)
            [
              storeNames[_str(s['storeId'])] ?? _str(s['storeId']),
              employeeNames[_str(s['employeeId'])] ?? _str(s['employeeId']),
              _status(s['status']),
              _date(s['openedAt']), _date(s['closedAt']),
              _num(s['openingCash']), _num(s['closingCash']),
              _num(s['cashSales']), _num(s['cardSales']), _num(s['totalSales']),
              _num(s['cashRefunds']), _num(s['depositsTotal']),
              _num(s['payoutsTotal']), _num(s['expectedCash']),
              _num(s['cashDifference']), _num(s['chickensReceived']),
              _num(s['kgReceived']), _num(s['chickensButchered']),
              _num(s['kgButchered']), _num(s['butcherMermaKg']),
            ],
        ],
        totalsRow: [
          'Total', '', '', '', '',
          _sum(shifts, 'openingCash'), _sum(shifts, 'closingCash'),
          _sum(shifts, 'cashSales'), _sum(shifts, 'cardSales'),
          _sum(shifts, 'totalSales'), _sum(shifts, 'cashRefunds'),
          _sum(shifts, 'depositsTotal'), _sum(shifts, 'payoutsTotal'),
          _sum(shifts, 'expectedCash'), _sum(shifts, 'cashDifference'),
          _sum(shifts, 'chickensReceived').toInt(), _sum(shifts, 'kgReceived'),
          _sum(shifts, 'chickensButchered').toInt(), _sum(shifts, 'kgButchered'),
          _sum(shifts, 'butcherMermaKg'),
        ],
      ),
    ],
  );
}

ReportSheet _cashMovementsSheet(
  List<Map<String, dynamic>> shifts,
  Map<String, String> storeNames,
  Map<String, String> employeeNames,
) {
  final rows = <List<Object?>>[];
  var total = 0.0;
  for (final s in shifts) {
    final movements = (s['cashMovements'] as List?) ?? const [];
    final openedAt = _date(s['openedAt']);
    for (final raw in movements) {
      final m = raw is Map ? raw : const <String, dynamic>{};
      final amount = _num(m['amount']);
      total += amount;
      rows.add([
        storeNames[_str(s['storeId'])] ?? _str(s['storeId']),
        employeeNames[_str(s['employeeId'])] ?? _str(s['employeeId']),
        openedAt,
        _cashMovementType(m['type']),
        amount,
        _str(m['comment']),
        _date(m['createdAt']),
      ]);
    }
  }
  return ReportSheet(
    title: 'Movimientos de caja',
    tables: [
      ReportTable(
        headers: const [
          'Sucursal', 'Empleado', 'Turno', 'Tipo', 'Monto', 'Comentario', 'Fecha',
        ],
        moneyColumns: const {4},
        rows: rows,
        totalsRow: [
          'Total', '', '', '', total, '', '',
        ],
      ),
    ],
  );
}

ReportSheet _transfersSheet(
  List<Map<String, dynamic>> transfers,
  Map<String, String> storeNames,
  Map<String, String> employeeNames,
) {
  return ReportSheet(
    title: 'Traspasos',
    tables: [
      ReportTable(
        headers: const [
          'Origen', 'Destino', 'Empleado origen', 'Empleado destino',
          'Estado', 'Fecha', 'Notas', 'Artículos',
        ],
        rows: [
          for (final t in transfers)
            [
              _optionalStoreName(storeNames, t['fromStoreId'], t['fromStoreName']),
              _optionalStoreName(storeNames, t['toStoreId'], t['toStoreName']),
              employeeNames[_str(t['fromEmployeeId'])] ?? _str(t['fromEmployeeId']),
              employeeNames[_str(t['toEmployeeId'])] ?? _str(t['toEmployeeId']),
              _status(t['status']), _date(t['createdAt']), _str(t['notes']),
              _itemsSummary(t['items']),
            ],
        ],
      ),
    ],
  );
}

ReportSheet _poultrySheet(
  List<Map<String, dynamic>> receivings,
  Map<String, String> storeNames,
  Map<String, String> employeeNames,
) {
  final chickens = _sum(receivings, 'totalChickens').toInt();
  final weight = _sum(receivings, 'totalWeightKg');
  return ReportSheet(
    title: 'Recibos de pollo',
    tables: [
      ReportTable(
        headers: const [
          'Sucursal', 'Empleado', 'Fecha', 'Pollos', 'Peso total (kg)',
          'Peso promedio (kg)', 'Estado',
        ],
        rows: [
          for (final r in receivings)
            [
              storeNames[_str(r['storeId'])] ?? _str(r['storeId']),
              employeeNames[_str(r['employeeId'])] ?? _str(r['employeeName']),
              _date(r['createdAt']), _num(r['totalChickens']),
              _num(r['totalWeightKg']), _num(r['avgWeightKg']),
              _status(r['status']),
            ],
        ],
        totalsRow: [
          'Total', '', '', chickens, weight, '', '',
        ],
      ),
    ],
  );
}

ReportSheet _butcheringSheet(
  List<Map<String, dynamic>> records,
  Map<String, String> storeNames,
  Map<String, String> employeeNames,
) {
  final chickens = _sum(records, 'chickenCount').toInt();
  final exact = _sum(records, 'exactWeightKg');
  final expected = _sum(records, 'totalExpectedKg');
  final actual = _sum(records, 'totalActualKg');
  final merma = _sum(records, 'mermaKg');
  final mermaPercent = actual > 0 ? merma / actual * 100 : 0.0;
  return ReportSheet(
    title: 'Destazado',
    tables: [
      ReportTable(
        headers: const [
          'Sucursal', 'Empleado', 'Fecha', 'Pollos', 'Peso exacto (kg)',
          'Esperado (kg)', 'Real (kg)', 'Merma (kg)', 'Merma (%)',
          'Estado', 'Secciones',
        ],
        percentColumns: const {8},
        rows: [
          for (final r in records)
            [
              storeNames[_str(r['storeId'])] ?? _str(r['storeId']),
              employeeNames[_str(r['employeeId'])] ?? _str(r['employeeName']),
              _date(r['createdAt']), _num(r['chickenCount']),
              _num(r['exactWeightKg']), _num(r['totalExpectedKg']),
              _num(r['totalActualKg']), _num(r['mermaKg']),
              _num(r['mermaPercent']), _status(r['status']),
              _sectionsSummary(r['sections']),
            ],
        ],
        totalsRow: [
          'Total', '', '', chickens, exact, expected, actual, merma,
          mermaPercent, '', '',
        ],
      ),
    ],
  );
}

ReportSheet _butcherReceiptsSheet(
  List<Map<String, dynamic>> receipts,
  Map<String, String> storeNames,
  Map<String, String> employeeNames,
) {
  return ReportSheet(
    title: 'Recibos de destazado',
    tables: [
      ReportTable(
        headers: const [
          'Sucursal', 'Empleado', 'Fecha', 'Tipo', 'Pollos',
          'Peso total (kg)', 'Origen', 'Rendimientos', 'Estado',
        ],
        rows: [
          for (final r in receipts)
            [
              storeNames[_str(r['storeId'])] ?? _str(r['storeId']),
              employeeNames[_str(r['employeeId'])] ?? _str(r['employeeName']),
              _date(r['createdAt']),
              _receiptType(r['type']),
              _num(r['chickenCount']),
              _num(r['totalWeight'] ?? r['avgWeight']),
              _optionalStoreName(storeNames, r['sourceStoreId'], null),
              _yieldsSummary(r['yields']),
              _status(r['status']),
            ],
        ],
      ),
    ],
  );
}

ReportSheet _categoriesSheet(List<Map<String, dynamic>> categories) {
  return ReportSheet(
    title: 'Categorías',
    tables: [
      ReportTable(
        headers: const ['Nombre', 'Activa'],
        rows: [
          for (final c in categories)
            [_str(c['name']), _yesNo(c['active'])],
        ],
      ),
    ],
  );
}

ReportSheet _discountsSheet(
  List<Map<String, dynamic>> discounts,
  String currencySymbol,
) {
  return ReportSheet(
    title: 'Descuentos',
    tables: [
      ReportTable(
        headers: const ['Nombre', 'Tipo', 'Valor', 'Activo'],
        rows: [
          for (final d in discounts)
            [
              _str(d['name']),
              _discountType(d['type']),
              _discountValue(d, currencySymbol),
              _yesNo(d['active']),
            ],
        ],
      ),
    ],
  );
}

ReportSheet _modifiersSheet(List<Map<String, dynamic>> modifiers) {
  return ReportSheet(
    title: 'Modificadores',
    tables: [
      ReportTable(
        headers: const ['Nombre', 'Precio', 'Activo'],
        moneyColumns: const {1},
        rows: [
          for (final m in modifiers)
            [_str(m['name']), _num(m['price']), _yesNo(m['active'])],
        ],
      ),
    ],
  );
}

// ---------------------------------------------------------------------------
// Cómputos auxiliares
// ---------------------------------------------------------------------------

/// Ventas que cuentan para métricas (no canceladas ni reembolsos).
List<Map<String, dynamic>> _validSales(List<Map<String, dynamic>> sales) {
  return sales.where((s) {
    final status = _str(s['status']);
    final type = _str(s['type']);
    final refund = s['refund'] == true;
    final cancelled = status == 'cancelled' || status == 'partially_cancelled';
    final isRefund = status == 'refund' || type == 'refund' || refund;
    return !cancelled && !isRefund;
  }).toList();
}

Map<String, double> _salesTotals(List<Map<String, dynamic>> sales) {
  final valid = _validSales(sales);
  return {
    'subtotal': _sum(valid, 'subtotal'),
    'discount': _sum(valid, 'discountTotal'),
    'tax': _sum(valid, 'taxTotal'),
    'total': _sum(valid, 'total'),
    'cashReceived': _sum(valid, 'cashReceived'),
    'changeDue': _sum(valid, 'changeDue'),
  };
}

/// Productos más vendidos por cantidad, agregados desde los ítems de ventas.
List<(String, num)> _topProducts(
  List<Map<String, dynamic>> sales, {
  required int limit,
}) {
  final byName = <String, num>{};
  for (final s in sales) {
    final items = (s['items'] as List?) ?? const [];
    for (final raw in items) {
      final item = raw is Map ? raw : const <String, dynamic>{};
      final name = _str(item['name'] ?? item['productName']);
      if (name.isEmpty) continue;
      byName[name] = (byName[name] ?? 0) + _num(item['quantity']);
    }
  }
  final sorted = byName.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  return [
    for (final e in sorted.take(limit)) (e.key, e.value),
  ];
}

// ---------------------------------------------------------------------------
// Traducciones y formatos
// ---------------------------------------------------------------------------

Map<String, String> _namesById(List<Map<String, dynamic>> docs) {
  return <String, String>{
    for (final d in docs)
      if (_id(d).isNotEmpty) _id(d): _str(d['name']),
  };
}

String _status(Object? status) {
  switch (status) {
    case 'paid':
      return 'Pagada';
    case 'cancelled':
      return 'Cancelada';
    case 'partially_cancelled':
      return 'Cancelación parcial';
    case 'refund':
      return 'Reembolso';
    case 'open':
      return 'Abierto';
    case 'closed':
      return 'Cerrado';
    case 'sent':
      return 'Enviado';
    case 'confirmed':
      return 'Confirmado';
    case 'completed':
      return 'Completado';
    case 'active':
      return 'Activo';
    case 'cancelled_at_store':
      return 'Cancelado en origen';
    default:
      return _str(status);
  }
}

String _paymentMethod(Object? method) {
  switch (method) {
    case 'cash':
      return 'Efectivo';
    case 'card':
      return 'Tarjeta';
    case 'transfer':
      return 'Transferencia';
    case 'credit':
      return 'Crédito';
    default:
      return _str(method);
  }
}

String _saleType(Object? type) {
  switch (type) {
    case 'sale':
      return 'Venta';
    case 'refund':
      return 'Reembolso';
    default:
      return _str(type);
  }
}

String _movementType(Object? type) {
  switch (type) {
    case 'sale':
      return 'Venta';
    case 'refund':
      return 'Devolución';
    case 'adjustment':
      return 'Ajuste';
    case 'butchering':
      return 'Destazado';
    case 'receiving':
      return 'Recepción';
    case 'transfer':
      return 'Traspaso';
    case 'swap':
      return 'Intercambio';
    default:
      return _str(type);
  }
}

String _role(Object? role) {
  switch (role) {
    case 'owner':
      return 'Dueño';
    case 'admin':
      return 'Administrador';
    case 'manager':
      return 'Gerente';
    case 'cashier':
      return 'Cajero';
    case 'stock':
      return 'Inventario';
    default:
      return _str(role);
  }
}

String _cashMovementType(Object? type) {
  switch (type) {
    case 'deposit':
      return 'Depósito';
    case 'payout':
      return 'Retiro';
    default:
      return _str(type);
  }
}

String _receiptType(Object? type) {
  switch (type) {
    case 'chicken':
      return 'Pollo entero';
    case 'parts':
      return 'Piezas';
    default:
      return _str(type);
  }
}

String _discountType(Object? type) {
  switch (type) {
    case 'percentage':
      return 'Porcentaje';
    case 'fixed':
      return 'Monto fijo';
    default:
      return _str(type);
  }
}

String _discountValue(Map<String, dynamic> discount, String symbol) {
  final value = _num(discount['value']);
  return discount['type'] == 'percentage'
      ? '${value.toStringAsFixed(value == value.roundToDouble() ? 0 : 2)}%'
      : _formatMoney(value, symbol);
}

String _cancelled(Map<String, dynamic> sale) {
  final status = _str(sale['status']);
  return status == 'cancelled' || status == 'partially_cancelled' ? 'Sí' : 'No';
}

String _stockStatus(Map<String, dynamic> stock) {
  final quantity = _num(stock['stockQuantity']);
  final alert = _num(stock['lowStockAlertQuantity']);
  if (quantity <= 0) return 'Agotado';
  if (alert > 0 && quantity <= alert) return 'Bajo';
  return 'OK';
}

String _yesNo(Object? value) => value == true ? 'Sí' : 'No';

String _optionalStoreName(
  Map<String, String> storeNames,
  Object? storeId,
  Object? storedName,
) {
  final resolved = storeNames[_str(storeId)];
  if (resolved != null && resolved.isNotEmpty) return resolved;
  return _str(storedName);
}

String _formatMoney(double value, String symbol) {
  final negative = value < 0;
  final abs = value.abs();
  final parts = abs.toStringAsFixed(2).split('.');
  final intPart = parts[0].replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'),
    (_) => ',',
  );
  return '${negative ? '-' : ''}$symbol$intPart.${parts[1]}';
}

String _itemsSummary(Object? items) {
  final list = items is List ? items : const <Object>[];
  return list.map((item) {
    final map = item is Map ? item : const <String, dynamic>{};
    final name = _str(map['productName'] ?? map['name'] ?? map['productId']);
    final qty = map['sentQuantity'] ?? map['quantity'] ?? map['count'];
    return qty == null ? name : '$name x$qty';
  }).join('; ');
}

String _sectionsSummary(Object? sections) {
  final list = sections is List ? sections : const <Object>[];
  return list.map((section) {
    final map = section is Map ? section : const <String, dynamic>{};
    final name = _str(map['sectionName'] ?? map['name']);
    final actual = map['actualKg'];
    return actual == null ? name : '$name: $actual kg';
  }).join('; ');
}

String _yieldsSummary(Object? yields) {
  final list = yields is List ? yields : const <Object>[];
  return list.map((yield_) {
    final map = yield_ is Map ? yield_ : const <String, dynamic>{};
    final name = _str(map['name']);
    final weight = _num(map['weight']);
    final pct = _num(map['percentage']);
    return '$name: $weight kg ($pct%)';
  }).join('; ');
}

String _dateTimeText(DateTime date) {
  final d = date.day.toString().padLeft(2, '0');
  final m = date.month.toString().padLeft(2, '0');
  final h = date.hour.toString().padLeft(2, '0');
  final min = date.minute.toString().padLeft(2, '0');
  return '$d/$m/${date.year} $h:$min';
}

double _round(double value) => (value * 100).roundToDouble() / 100;

// ---------------------------------------------------------------------------
// Accessores tolerantes
// ---------------------------------------------------------------------------

String _id(Map<String, dynamic> doc) => _str(doc['id']);

DateTime? _date(Object? value) {
  if (value is DateTime) return value;
  if (value is Timestamp) return value.toDate();
  return null;
}

double _num(Object? value) => value is num ? value.toDouble() : 0;

String _str(Object? value) => value?.toString() ?? '';

double _sum(List<Map<String, dynamic>> docs, String key) {
  var total = 0.0;
  for (final d in docs) {
    final value = d[key];
    if (value is num) total += value;
  }
  return total;
}

bool _isLowStock(Map<String, dynamic> product) {
  final track = product['trackStock'] == true;
  if (!track) return false;
  final quantity = _num(product['stockQuantity']);
  final alert = _num(product['lowStockAlertQuantity']);
  return quantity > 0 && alert > 0 && quantity <= alert;
}

bool _isOutOfStock(Map<String, dynamic> product) {
  final track = product['trackStock'] == true;
  if (!track) return false;
  return _num(product['stockQuantity']) <= 0;
}
