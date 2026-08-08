import 'package:flutter_test/flutter_test.dart';

import 'package:pos_flutter_firebase/features/business/data/excel_report_sheets.dart';

void main() {
  final sheets = buildReportSheets(
    businessName: 'Pollos Marcos',
    currencySymbol: r'$',
    generatedAt: DateTime(2026, 8, 8, 10, 30),
    stores: [
      {'id': 's1', 'name': 'Sucursal principal', 'address': 'Centro', 'phone': '555', 'active': true},
      {'id': 's2', 'name': 'Sucursal 3era', 'active': true},
    ],
    products: [
      {'id': 'p1', 'name': 'Pollo entero', 'ref': 'PO-01', 'categoryName': 'Pollos', 'price': 90.0, 'cost': 70.0, 'trackStock': true, 'stockQuantity': 5, 'lowStockAlertQuantity': 3, 'active': true},
      {'id': 'p2', 'name': 'Pechuga', 'ref': 'PE-01', 'categoryName': 'Piezas', 'price': 120.0, 'cost': 90.0, 'trackStock': true, 'stockQuantity': 0, 'lowStockAlertQuantity': 4, 'active': true},
    ],
    stock: [
      {'id': 'st1', 'storeId': 's1', 'productId': 'p1', 'stockQuantity': 5, 'lowStockAlertQuantity': 3, 'chickenCount': 5},
      {'id': 'st2', 'storeId': 's1', 'productId': 'p2', 'stockQuantity': 0, 'lowStockAlertQuantity': 4, 'chickenCount': 0},
    ],
    sales: [
      {'id': 'v1', 'folio': 'V-001', 'storeId': 's1', 'employeeId': 'e1', 'shiftId': 'sh1', 'createdAt': DateTime(2026, 8, 8, 11, 0), 'paymentMethod': 'cash', 'type': 'sale', 'status': 'paid', 'subtotal': 210.0, 'discountTotal': 10.0, 'taxTotal': 0.0, 'total': 200.0, 'cashReceived': 200.0, 'changeDue': 0.0, 'cancelReason': null, 'items': [{'name': 'Pollo entero', 'quantity': 2}, {'name': 'Pechuga', 'quantity': 1}]},
      {'id': 'v2', 'folio': 'V-002', 'storeId': 's2', 'employeeId': 'e1', 'shiftId': 'sh1', 'createdAt': DateTime(2026, 8, 8, 12, 0), 'paymentMethod': 'card', 'type': 'sale', 'status': 'paid', 'subtotal': 200.0, 'discountTotal': 0.0, 'taxTotal': 0.0, 'total': 200.0, 'cashReceived': 0.0, 'changeDue': 0.0, 'cancelReason': null, 'items': [{'name': 'Pechuga', 'quantity': 2}]},
      {'id': 'v3', 'folio': 'V-003', 'storeId': 's1', 'employeeId': 'e1', 'shiftId': 'sh1', 'createdAt': DateTime(2026, 8, 8, 13, 0), 'paymentMethod': 'cash', 'type': 'sale', 'status': 'cancelled', 'subtotal': 50.0, 'discountTotal': 0.0, 'taxTotal': 0.0, 'total': 50.0, 'cashReceived': 50.0, 'changeDue': 0.0, 'cancelReason': 'Error de captura', 'items': []},
    ],
    movements: [
      {'id': 'm1', 'storeId': 's1', 'productId': 'p1', 'productName': 'Pollo entero', 'type': 'receiving', 'previousQuantity': 0, 'newQuantity': 5, 'difference': 5, 'reason': 'Recepción de 5 pollos', 'employeeId': 'e1', 'createdAt': DateTime(2026, 8, 8)},
    ],
    employees: [
      {'id': 'e1', 'name': 'Juan Pérez', 'email': 'juan@example.com', 'role': 'admin', 'storeIds': ['s1'], 'active': true},
    ],
    shifts: [
      {'id': 'sh1', 'storeId': 's1', 'employeeId': 'e1', 'status': 'closed', 'openingCash': 500.0, 'closingCash': 600.0, 'cashSales': 200.0, 'cardSales': 100.0, 'totalSales': 300.0, 'cashRefunds': 0.0, 'depositsTotal': 150.0, 'payoutsTotal': 20.0, 'cashMovements': [
        {'type': 'deposit', 'amount': 150.0, 'comment': 'Depósito banco', 'createdAt': DateTime(2026, 8, 8, 12, 0)},
        {'type': 'payout', 'amount': 20.0, 'comment': 'Refrescos', 'createdAt': DateTime(2026, 8, 8, 12, 30)},
      ], 'expectedCash': 500.0, 'cashDifference': 100.0, 'openedAt': DateTime(2026, 8, 8, 9, 0), 'closedAt': DateTime(2026, 8, 8, 18, 0)},
    ],
    transfers: [
      {'id': 't1', 'fromStoreId': 's1', 'toStoreId': 's2', 'fromStoreName': 'Sucursal principal', 'toStoreName': 'Sucursal 3era', 'fromEmployeeId': 'e1', 'toEmployeeId': null, 'status': 'sent', 'createdAt': DateTime(2026, 8, 8, 14, 0), 'notes': '', 'items': [{'productName': 'Pollo entero', 'sentQuantity': 3}]},
    ],
    poultryReceivings: [
      {'id': 'pr1', 'storeId': 's1', 'employeeId': 'e1', 'createdAt': DateTime(2026, 8, 8), 'totalChickens': 20, 'totalWeightKg': 42.5, 'avgWeightKg': 2.125, 'status': 'completed'},
    ],
    butcheringRecords: [
      {'id': 'b1', 'storeId': 's1', 'employeeId': 'e1', 'createdAt': DateTime(2026, 8, 8), 'chickenCount': 10, 'exactWeightKg': 21.0, 'totalExpectedKg': 20.5, 'totalActualKg': 19.8, 'mermaKg': 1.2, 'mermaPercent': 5.7, 'status': 'active', 'sections': [{'sectionName': 'Pechuga', 'actualKg': 5.0}]},
    ],
    butcherReceipts: [
      {'id': 'br1', 'storeId': 's1', 'employeeId': 'e1', 'createdAt': DateTime(2026, 8, 8), 'type': 'chicken', 'chickenCount': 10, 'totalWeight': 21.0, 'sourceStoreId': null, 'status': 'active', 'yields': [{'name': 'Pechuga', 'weight': 5.0, 'percentage': 30.0}]},
    ],
    categories: [
      {'id': 'c1', 'name': 'Pollos', 'active': true},
    ],
    discounts: [
      {'id': 'd1', 'name': 'Cliente frecuente', 'type': 'percentage', 'value': 10.0, 'active': true},
    ],
    modifiers: [
      {'id': 'mo1', 'name': 'Adicional salsa', 'price': 5.0, 'active': true},
    ],
  );

  test('incluye 16 hojas y Resumen como primera', () {
    expect(sheets.map((s) => s.title).toList(), [
      'Resumen', 'Sucursales', 'Productos', 'Inventario', 'Ventas',
      'Movimientos de inventario', 'Empleados', 'Turnos', 'Movimientos de caja',
      'Traspasos', 'Recibos de pollo', 'Destazado', 'Recibos de destazado',
      'Categorías', 'Descuentos', 'Modificadores',
    ]);
  });

  test('Resumen: indicadores, ventas por sucursal y productos más vendidos', () {
    final resumen = sheets.first;
    expect(resumen.tables, hasLength(3));

    final indicators = resumen.tables[0].rows.map((r) => r[0].toString()).toList();
    expect(indicators, contains('Total de ventas'));
    expect(indicators, contains('Productos agotados'));
    expect(indicators, contains('Pollos recibidos'));

    final totalDeVentas = resumen.tables[0].rows.firstWhere((r) => r[0] == 'Total de ventas')[1];
    expect(totalDeVentas, r'$400.00');

    final porSucursal = resumen.tables[1].rows;
    expect(porSucursal, hasLength(2));
    expect(porSucursal[0][0], 'Sucursal principal');
    expect(porSucursal[0][2], 200.0);
    expect(resumen.tables[1].totalsRow![2], 400.0);

    final top = resumen.tables[2].rows;
    expect(top, hasLength(2));
    expect(top.first[0], 'Pechuga');
    expect(top.first[1], 3);
  });

  test('Ventas: estados y métodos de pago traducidos, cancelada como Sí/No', () {
    final ventas = sheets.firstWhere((s) => s.title == 'Ventas').tables.first;
    final rows = ventas.rows;
    expect(rows[0][5], 'Efectivo');
    expect(rows[0][7], 'Pagada');
    expect(rows[0][14], 'No');
    expect(rows[1][5], 'Tarjeta');
    expect(rows[2][7], 'Cancelada');
    expect(rows[2][14], 'Sí');
    expect(rows[2][15], 'Error de captura');
    expect(ventas.totalsRow![11], 400.0);
  });

  test('Sucursales y Productos no exponen IDs internos', () {
    final sucursales = sheets.firstWhere((s) => s.title == 'Sucursales').tables.first;
    expect(sucursales.headers, ['Nombre', 'Dirección', 'Teléfono', 'Activa']);
    expect(sucursales.headers, isNot(contains('id')));

    final productos = sheets.firstWhere((s) => s.title == 'Productos').tables.first;
    expect(productos.headers, isNot(contains('id')));
    expect(productos.headers, isNot(contains('presentacion')));
    expect(productos.moneyColumns, {3, 4});
  });

  test('Inventario calcula el estado de stock', () {
    final inventario = sheets.firstWhere((s) => s.title == 'Inventario').tables.first;
    expect(inventario.rows[0].last, 'OK');
    expect(inventario.rows[1].last, 'Agotado');
  });

  test('Movimientos de caja extrae depósitos y retiros del turno', () {
    final movimientos = sheets.firstWhere((s) => s.title == 'Movimientos de caja').tables.first;
    expect(movimientos.rows, hasLength(2));
    expect(movimientos.rows[0][3], 'Depósito');
    expect(movimientos.rows[1][3], 'Retiro');
    expect(movimientos.totalsRow![4], 170.0);
  });

  test('Recibos de destazado tiene columnas limpias (sin JSON)', () {
    final recibos = sheets.firstWhere((s) => s.title == 'Recibos de destazado').tables.first;
    expect(recibos.headers, isNot(contains('yields')));
    expect(recibos.rows[0][3], 'Pollo entero');
    expect(recibos.rows[0][7], contains('Pechuga'));
  });

  test('Descuentos formatea porcentaje y monto fijo', () {
    final descuentos = sheets.firstWhere((s) => s.title == 'Descuentos').tables.first;
    expect(descuentos.rows[0][2], '10%');
  });

  test('Traspasos resuelve nombres de sucursal en lugar de IDs', () {
    final traspasos = sheets.firstWhere((s) => s.title == 'Traspasos').tables.first;
    expect(traspasos.rows[0][0], 'Sucursal principal');
    expect(traspasos.rows[0][1], 'Sucursal 3era');
    expect(traspasos.rows[0][4], 'Enviado');
  });
}
