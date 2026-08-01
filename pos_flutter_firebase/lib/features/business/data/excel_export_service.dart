import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import '../domain/excel_export_repository.dart';
import 'excel_book_builder.dart';

typedef SaveExcel = Future<String> Function(String fileName, Uint8List bytes);

class ExcelExportService implements ExcelExportRepository {
  ExcelExportService({FirebaseFirestore? firestore, SaveExcel? saveExcel})
      : _db = firestore ?? FirebaseFirestore.instance,
        _saveExcel = saveExcel ?? _saveViaChannel;

  final FirebaseFirestore _db;
  final SaveExcel _saveExcel;

  static const _channel = MethodChannel('com.lolo.posllo/export_saver');
  static const _xlsxMime =
      'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';

  static Future<String> _saveViaChannel(String fileName, Uint8List bytes) async {
    final path = await _channel.invokeMethod<String>('saveToDownloads', {
      'name': fileName,
      'mimeType': _xlsxMime,
      'bytes': bytes,
    });
    if (path == null) {
      throw StateError('No se pudo guardar el archivo en Descargas');
    }
    return path;
  }

  @override
  Future<ExcelExportResult> exportAllData({required String businessId}) async {
    final businessSnapshot =
        await _db.collection('businesses').doc(businessId).get();
    final businessName =
        (businessSnapshot.data()?['name'] as String?) ?? businessId;

    final storesSnapshot = await _db
        .collection('businesses')
        .doc(businessId)
        .collection('stores')
        .get();
    final productsSnapshot = await _db
        .collection('businesses')
        .doc(businessId)
        .collection('products')
        .get();
    final stock = <Map<String, dynamic>>[];
    for (final productDoc in productsSnapshot.docs) {
      final stockSnapshot =
          await productDoc.reference.collection('stockByStore').get();
      for (final stockDoc in stockSnapshot.docs) {
        stock.add(stockDoc.data());
      }
    }
    final sales = await _fetchAllSales(businessId);
    final movementsSnapshot = await _db
        .collection('businesses')
        .doc(businessId)
        .collection('inventoryMovements')
        .get();
    final employeesSnapshot = await _db
        .collection('businesses')
        .doc(businessId)
        .collection('employees')
        .get();
    final shiftsSnapshot = await _db
        .collection('businesses')
        .doc(businessId)
        .collection('shifts')
        .get();
    final transfersSnapshot = await _db
        .collection('businesses')
        .doc(businessId)
        .collection('transfers')
        .get();
    final poultrySnapshot = await _db
        .collection('businesses')
        .doc(businessId)
        .collection('poultryReceivings')
        .get();
    final butcheringSnapshot = await _db
        .collection('businesses')
        .doc(businessId)
        .collection('butchering')
        .get();
    final butcherReceiptsSnapshot = await _db
        .collection('businesses')
        .doc(businessId)
        .collection('butcherReceipts')
        .get();
    final categoriesSnapshot = await _db
        .collection('businesses')
        .doc(businessId)
        .collection('categories')
        .get();
    final discountsSnapshot = await _db
        .collection('businesses')
        .doc(businessId)
        .collection('discounts')
        .get();
    final modifiersSnapshot = await _db
        .collection('businesses')
        .doc(businessId)
        .collection('modifiers')
        .get();

    final stores = storesSnapshot.docs.map((d) => d.data()).toList();
    final products = productsSnapshot.docs.map((d) => d.data()).toList();
    final storeNames = <String, String>{
      for (final s in stores) (s['id'] as String?) ?? '': (s['name'] as String?) ?? '',
    };
    final productNames = <String, String>{
      for (final p in products) (p['id'] as String?) ?? '': (p['name'] as String?) ?? '',
    };
    final employeeNames = <String, String>{};
    for (final d in employeesSnapshot.docs) {
      final data = d.data();
      final id = (data['id'] as String?) ?? d.id;
      employeeNames[id] = (data['name'] as String?) ?? '';
    }

    final sheets = <ExcelSheetData>[
      _storesSheet(stores),
      _productsSheet(products),
      _stockSheet(stock, storeNames, productNames),
      _salesSheet(sales, storeNames, employeeNames),
      _movementsSheet(movementsSnapshot.docs.map((d) => d.data()).toList(), storeNames, productNames),
      _employeesSheet(employeesSnapshot.docs.map((d) => d.data()).toList(), storeNames),
      _shiftsSheet(shiftsSnapshot.docs.map((d) => d.data()).toList(), storeNames, employeeNames),
      _transfersSheet(transfersSnapshot.docs.map((d) => d.data()).toList(), storeNames, employeeNames),
      _poultrySheet(poultrySnapshot.docs.map((d) => d.data()).toList(), storeNames, employeeNames),
      _butcheringSheet(butcheringSnapshot.docs.map((d) => d.data()).toList(), storeNames, employeeNames),
      _rawSheet('Recibos', butcherReceiptsSnapshot.docs.map((d) => d.data()).toList(), storeNames),
      _categoriesSheet(categoriesSnapshot.docs.map((d) => d.data()).toList()),
      _discountsSheet(discountsSnapshot.docs.map((d) => d.data()).toList()),
      _modifiersSheet(modifiersSnapshot.docs.map((d) => d.data()).toList()),
    ];

    final bytes = buildExcelWorkbook(sheets);

    final now = DateTime.now();
    final fileName =
        'datos_${_slug(businessName)}_${_fileTimestamp(now)}.xlsx';

    late final String path;
    try {
      path = await _saveExcel(fileName, bytes);
    } catch (_) {
      path = await _saveToAppDirectory(fileName, bytes);
    }

    return ExcelExportResult(
      path: path,
      message: 'Exportación completada con ${sheets.fold<int>(0, (total, s) => total + s.rows.length)} registros',
      counts: {for (final s in sheets) s.title: s.rows.length},
    );
  }

  Future<List<Map<String, dynamic>>> _fetchAllSales(String businessId) async {
    final ref =
        _db.collection('businesses').doc(businessId).collection('sales');
    final all = <Map<String, dynamic>>[];
    DocumentSnapshot<Map<String, dynamic>>? last;
    while (true) {
      var query = ref.limit(1000);
      if (last != null) query = query.startAfterDocument(last);
      final snapshot = await query.get();
      if (snapshot.docs.isEmpty) break;
      for (final doc in snapshot.docs) {
        all.add(doc.data());
      }
      if (snapshot.docs.length < 1000) break;
      last = snapshot.docs.last;
    }
    return all;
  }

  ExcelSheetData _storesSheet(List<Map<String, dynamic>> stores) {
    return ExcelSheetData(
      title: 'Sucursales',
      headers: const ['id', 'nombre', 'direccion', 'telefono', 'activa'],
      rows: [
        for (final s in stores)
          [_str(s['id']), _str(s['name']), _str(s['address']), _str(s['phone']), _bool(s['active'])],
      ],
    );
  }

  ExcelSheetData _productsSheet(List<Map<String, dynamic>> products) {
    return ExcelSheetData(
      title: 'Productos',
      headers: const [
        'id', 'ref', 'nombre', 'categoria', 'venta_por', 'precio', 'costo',
        'controla_stock', 'stock', 'alerta_stock', 'presentacion_tipo',
        'presentacion_forma', 'color', 'activo',
      ],
      rows: [
        for (final p in products)
          [
            _str(p['id']), _str(p['ref']), _str(p['name']), _str(p['categoryName']),
            _str(p['sellBy']), _num(p['price']), _num(p['cost']),
            _bool(p['trackStock']), _num(p['stockQuantity']),
            _num(p['lowStockAlertQuantity']), _str(p['presentationType']),
            _str(p['presentationShape']), _int(p['presentationColor']), _bool(p['active']),
          ],
      ],
    );
  }

  ExcelSheetData _stockSheet(
    List<Map<String, dynamic>> stock,
    Map<String, String> storeNames,
    Map<String, String> productNames,
  ) {
    return ExcelSheetData(
      title: 'Inventario',
      headers: const ['sucursal', 'producto', 'stock', 'alerta_stock', 'pollos'],
      rows: [
        for (final s in stock)
          [
            storeNames[_str(s['storeId'])] ?? _str(s['storeId']),
            productNames[_str(s['productId'])] ?? _str(s['productId']),
            _num(s['stockQuantity']), _num(s['lowStockAlertQuantity']),
            _num(s['chickenCount']),
          ],
      ],
    );
  }

  ExcelSheetData _salesSheet(
    List<Map<String, dynamic>> sales,
    Map<String, String> storeNames,
    Map<String, String> employeeNames,
  ) {
    return ExcelSheetData(
      title: 'Ventas',
      headers: const [
        'folio', 'sucursal', 'empleado', 'turno', 'fecha', 'metodo_pago',
        'tipo', 'estado', 'subtotal', 'descuento', 'impuesto', 'total',
        'efectivo', 'cambio', 'cancelada', 'razon_cancelacion', 'articulos',
      ],
      rows: [
        for (final s in sales)
          [
            _str(s['folio']),
            storeNames[_str(s['storeId'])] ?? _str(s['storeId']),
            employeeNames[_str(s['employeeId'])] ?? _str(s['employeeId']),
            _str(s['shiftId']), _date(s['createdAt'] ?? s['clientCreatedAt']),
            _str(s['paymentMethod']), _str(s['type']), _str(s['status']),
            _num(s['subtotal']), _num(s['discountTotal']), _num(s['taxTotal']),
            _num(s['total']), _num(s['cashReceived']), _num(s['changeDue']),
            _date(s['cancelledAt']), _str(s['cancelReason']),
            '${((s['items'] as List?) ?? const []).length}',
          ],
      ],
    );
  }

  ExcelSheetData _movementsSheet(
    List<Map<String, dynamic>> movements,
    Map<String, String> storeNames,
    Map<String, String> productNames,
  ) {
    return ExcelSheetData(
      title: 'Movimientos',
      headers: const [
        'sucursal', 'producto', 'tipo', 'anterior', 'nuevo', 'diferencia',
        'motivo', 'empleado', 'fecha',
      ],
      rows: [
        for (final m in movements)
          [
            storeNames[_str(m['storeId'])] ?? _str(m['storeId']),
            productNames[_str(m['productId'])] ?? _str(m['productName'] ?? ''),
            _str(m['type']), _num(m['previousQuantity']), _num(m['newQuantity']),
            _num(m['storedDifference'] ?? m['difference']), _str(m['reason']),
            _str(m['employeeId']), _date(m['createdAt']),
          ],
      ],
    );
  }

  ExcelSheetData _employeesSheet(
    List<Map<String, dynamic>> employees,
    Map<String, String> storeNames,
  ) {
    return ExcelSheetData(
      title: 'Empleados',
      headers: const ['id', 'nombre', 'email', 'rol', 'sucursales', 'activo'],
      rows: [
        for (final e in employees)
          [
            _str(e['id']), _str(e['name']), _str(e['email']), _str(e['role']),
            ((e['storeIds'] as List?) ?? const [])
                .map((id) => storeNames[id.toString()] ?? id.toString())
                .join(', '),
            _bool(e['active']),
          ],
      ],
    );
  }

  ExcelSheetData _shiftsSheet(
    List<Map<String, dynamic>> shifts,
    Map<String, String> storeNames,
    Map<String, String> employeeNames,
  ) {
    return ExcelSheetData(
      title: 'Turnos',
      headers: const [
        'sucursal', 'empleado', 'estado', 'apertura', 'cierre', 'ventas_efectivo',
        'ventas_tarjeta', 'ventas_total', 'devoluciones', 'depositos', 'gastos',
        'esperado', 'diferencia', 'abrio', 'cerro', 'pollos_recibidos',
        'kg_recibidos', 'pollos_destazados', 'kg_destazados', 'merma_kg',
      ],
      rows: [
        for (final s in shifts)
          [
            storeNames[_str(s['storeId'])] ?? _str(s['storeId']),
            employeeNames[_str(s['employeeId'])] ?? _str(s['employeeId']),
            _str(s['status']), _num(s['openingCash']), _num(s['closingCash']),
            _num(s['cashSales']), _num(s['cardSales']), _num(s['totalSales']),
            _num(s['cashRefunds']), _num(s['depositsTotal']),
            _num(s['payoutsTotal']), _num(s['expectedCash']),
            _num(s['cashDifference']), _date(s['openedAt']), _date(s['closedAt']),
            _num(s['chickensReceived']), _num(s['kgReceived']),
            _num(s['chickensButchered']), _num(s['kgButchered']),
            _num(s['butcherMermaKg']),
          ],
      ],
    );
  }

  ExcelSheetData _transfersSheet(
    List<Map<String, dynamic>> transfers,
    Map<String, String> storeNames,
    Map<String, String> employeeNames,
  ) {
    return ExcelSheetData(
      title: 'Traspasos',
      headers: const [
        'id', 'origen', 'destino', 'empleado_origen', 'empleado_destino',
        'estado', 'fecha', 'notas', 'articulos',
      ],
      rows: [
        for (final t in transfers)
          [
            _str(t['id']),
            storeNames[_str(t['fromStoreId'])] ?? _str(t['fromStoreId']),
            storeNames[_str(t['toStoreId'])] ?? _str(t['toStoreId']),
            employeeNames[_str(t['fromEmployeeId'])] ?? _str(t['fromEmployeeId']),
            employeeNames[_str(t['toEmployeeId'])] ?? _str(t['toEmployeeId']),
            _str(t['status']), _date(t['createdAt']), _str(t['notes']),
            _itemsSummary(t['items']),
          ],
      ],
    );
  }

  ExcelSheetData _poultrySheet(
    List<Map<String, dynamic>> receivings,
    Map<String, String> storeNames,
    Map<String, String> employeeNames,
  ) {
    return ExcelSheetData(
      title: 'RecibosPollo',
      headers: const [
        'sucursal', 'empleado', 'fecha', 'pollos', 'peso_kg', 'peso_promedio', 'estado',
      ],
      rows: [
        for (final r in receivings)
          [
            storeNames[_str(r['storeId'])] ?? _str(r['storeId']),
            employeeNames[_str(r['employeeId'])] ?? _str(r['employeeName'] ?? ''),
            _date(r['createdAt']), _num(r['totalChickens']),
            _num(r['totalWeightKg']), _num(r['avgWeightKg']), _str(r['status']),
          ],
      ],
    );
  }

  ExcelSheetData _butcheringSheet(
    List<Map<String, dynamic>> records,
    Map<String, String> storeNames,
    Map<String, String> employeeNames,
  ) {
    return ExcelSheetData(
      title: 'Destazado',
      headers: const [
        'sucursal', 'empleado', 'fecha', 'pollos', 'peso_exacto', 'esperado_kg',
        'real_kg', 'merma_kg', 'merma_pct', 'estado', 'secciones',
      ],
      rows: [
        for (final r in records)
          [
            storeNames[_str(r['storeId'])] ?? _str(r['storeId']),
            employeeNames[_str(r['employeeId'])] ?? _str(r['employeeName'] ?? ''),
            _date(r['createdAt']), _num(r['chickenCount']),
            _num(r['exactWeightKg']), _num(r['totalExpectedKg']),
            _num(r['totalActualKg']), _num(r['mermaKg']),
            _num(r['mermaPercent']), _str(r['status']),
            _sectionsSummary(r['sections']),
          ],
      ],
    );
  }

  ExcelSheetData _categoriesSheet(List<Map<String, dynamic>> categories) {
    return ExcelSheetData(
      title: 'Categorias',
      headers: const ['id', 'nombre', 'color', 'activa'],
      rows: [
        for (final c in categories)
          [_str(c['id']), _str(c['name']), _int(c['color']), _bool(c['active'])],
      ],
    );
  }

  ExcelSheetData _discountsSheet(List<Map<String, dynamic>> discounts) {
    return ExcelSheetData(
      title: 'Descuentos',
      headers: const ['id', 'nombre', 'tipo', 'valor', 'activo'],
      rows: [
        for (final d in discounts)
          [_str(d['id']), _str(d['name']), _str(d['type']), _num(d['value']), _bool(d['active'])],
      ],
    );
  }

  ExcelSheetData _modifiersSheet(List<Map<String, dynamic>> modifiers) {
    return ExcelSheetData(
      title: 'Modificadores',
      headers: const ['id', 'nombre', 'precio', 'activo'],
      rows: [
        for (final m in modifiers)
          [_str(m['id']), _str(m['name']), _num(m['price']), _bool(m['active'])],
      ],
    );
  }

  ExcelSheetData _rawSheet(
    String title,
    List<Map<String, dynamic>> docs,
    Map<String, String> storeNames,
  ) {
    final headers = <String>{};
    for (final d in docs) {
      headers.addAll(d.keys);
    }
    if (headers.contains('storeId')) {
      headers.remove('storeId');
    }
    final ordered = <String>['storeId', ...headers.toList()..sort()];
    return ExcelSheetData(
      title: title,
      headers: [
        for (final h in ordered)
          h == 'storeId' ? 'sucursal' : h,
      ],
      rows: [
        for (final d in docs)
          [
            for (final h in ordered)
              h == 'storeId'
                  ? (storeNames[_str(d['storeId'])] ?? _str(d['storeId']))
                  : _typedValue(d[h]),
          ],
      ],
    );
  }

  Future<String> _saveToAppDirectory(String fileName, Uint8List bytes) async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory('${base.path}/pos_backups');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    final file = File('${dir.path}/$fileName');
    await file.writeAsBytes(bytes);
    return file.path;
  }

  String _fileTimestamp(DateTime date) {
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    final h = date.hour.toString().padLeft(2, '0');
    final min = date.minute.toString().padLeft(2, '0');
    final s = date.second.toString().padLeft(2, '0');
    return '${date.year}$m${d}_$h$min$s';
  }

  String _slug(String value) {
    final slug = value
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
    return slug.isEmpty ? 'negocio' : slug;
  }

  String _date(Object? value) {
    if (value is Timestamp) return value.toDate().toIso8601String();
    if (value is DateTime) return value.toIso8601String();
    return value?.toString() ?? '';
  }

  double _num(Object? value) => value is num ? value.toDouble() : 0;

  int _int(Object? value) => value is num ? value.toInt() : 0;

  bool _bool(Object? value) => value is bool ? value : false;

  String _str(Object? value) => value?.toString() ?? '';

  Object? _typedValue(Object? value) {
    if (value is Timestamp) return _date(value);
    if (value is Map || value is List) return value.toString();
    return value;
  }

  String _itemsSummary(Object? items) {
    final list = items is List ? items : const <Object>[];
    return list.map((item) {
      final map = item is Map ? item : const <String, dynamic>{};
      final name = map['productName'] ?? map['name'] ?? map['productId'] ?? '?';
      final qty = map['sentQuantity'] ?? map['quantity'] ?? map['count'];
      return qty == null ? '$name' : '$name x$qty';
    }).join('; ');
  }

  String _sectionsSummary(Object? sections) {
    final list = sections is List ? sections : const <Object>[];
    return list.map((section) {
      final map = section is Map ? section : const <String, dynamic>{};
      final name = map['sectionName'] ?? map['name'] ?? '?';
      final actual = map['actualKg'];
      return actual == null ? '$name' : '$name: $actual kg';
    }).join('; ');
  }
}
