import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import '../domain/excel_export_repository.dart';
import 'excel_book_builder.dart';
import 'excel_report_sheets.dart';
import 'report_definition.dart';

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
    final data = await _fetchAll(businessId);

    final sheets = buildReportSheets(
      businessName: data.businessName,
      currencySymbol: _currencySymbol(data.currency),
      generatedAt: data.generatedAt,
      stores: data.stores,
      products: data.products,
      stock: data.stock,
      sales: data.sales,
      movements: data.movements,
      employees: data.employees,
      shifts: data.shifts,
      transfers: data.transfers,
      poultryReceivings: data.poultryReceivings,
      butcheringRecords: data.butcheringRecords,
      butcherReceipts: data.butcherReceipts,
      categories: data.categories,
      discounts: data.discounts,
      modifiers: data.modifiers,
    );

    final bytes = buildExcelWorkbook(
      ReportDefinition(
        businessName: data.businessName,
        currencySymbol: _currencySymbol(data.currency),
        generatedAt: data.generatedAt,
        sheets: sheets,
      ),
    );

    final now = data.generatedAt;
    final fileName = 'reporte_${_slug(data.businessName)}_${_fileTimestamp(now)}.xlsx';

    late final String path;
    try {
      path = await _saveExcel(fileName, bytes);
    } catch (_) {
      path = await _saveToAppDirectory(fileName, bytes);
    }

    return ExcelExportResult(
      path: path,
      message: 'Exportación completada con '
          '${sheets.fold<int>(0, (total, s) => total + s.tables.fold<int>(0, (t, table) => t + table.rows.length))} registros',
      counts: {
        for (final s in sheets)
          s.title: s.tables.fold<int>(0, (t, table) => t + table.rows.length),
      },
    );
  }

  Future<_ReportData> _fetchAll(String businessId) async {
    final businessSnapshot =
        await _db.collection('businesses').doc(businessId).get();
    final businessData = businessSnapshot.data() ?? {};
    final businessName =
        (businessData['name'] as String?) ?? businessId;
    final currency = (businessData['currency'] as String?) ?? 'MXN';

    final stores = await _db
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
        stock.add({...stockDoc.data(), 'id': stockDoc.id});
      }
    }
    final sales = await _fetchAllSales(businessId);
    final movements = await _db
        .collection('businesses')
        .doc(businessId)
        .collection('inventoryMovements')
        .get();
    final employees = await _db
        .collection('businesses')
        .doc(businessId)
        .collection('employees')
        .get();
    final shifts = await _db
        .collection('businesses')
        .doc(businessId)
        .collection('shifts')
        .get();
    final transfers = await _db
        .collection('businesses')
        .doc(businessId)
        .collection('transfers')
        .get();
    final poultryReceivings = await _db
        .collection('businesses')
        .doc(businessId)
        .collection('poultryReceivings')
        .get();
    final butcheringRecords = await _db
        .collection('businesses')
        .doc(businessId)
        .collection('butchering')
        .get();
    final butcherReceipts = await _db
        .collection('businesses')
        .doc(businessId)
        .collection('butcherReceipts')
        .get();
    final categories = await _db
        .collection('businesses')
        .doc(businessId)
        .collection('categories')
        .get();
    final discounts = await _db
        .collection('businesses')
        .doc(businessId)
        .collection('discounts')
        .get();
    final modifiers = await _db
        .collection('businesses')
        .doc(businessId)
        .collection('modifiers')
        .get();

    List<Map<String, dynamic>> withId(QuerySnapshot<Map<String, dynamic>> snap) =>
        [for (final d in snap.docs) {...d.data(), 'id': d.id}];

    return _ReportData(
      businessName: businessName,
      currency: currency,
      generatedAt: DateTime.now(),
      stores: withId(stores),
      products: withId(productsSnapshot),
      stock: stock,
      sales: sales,
      movements: withId(movements),
      employees: withId(employees),
      shifts: withId(shifts),
      transfers: withId(transfers),
      poultryReceivings: withId(poultryReceivings),
      butcheringRecords: withId(butcheringRecords),
      butcherReceipts: withId(butcherReceipts),
      categories: withId(categories),
      discounts: withId(discounts),
      modifiers: withId(modifiers),
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
        all.add({...doc.data(), 'id': doc.id});
      }
      if (snapshot.docs.length < 1000) break;
      last = snapshot.docs.last;
    }
    return all;
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
}

String _currencySymbol(String currencyCode) {
  switch (currencyCode.toUpperCase()) {
    case 'MXN':
    case 'USD':
    case 'CAD':
    case 'AUD':
    case 'NZD':
    case 'HKD':
    case 'SGD':
      return r'$';
    case 'EUR':
      return '€';
    case 'GBP':
      return '£';
    case 'JPY':
      return '¥';
    default:
      return r'$';
  }
}

class _ReportData {
  const _ReportData({
    required this.businessName,
    required this.currency,
    required this.generatedAt,
    required this.stores,
    required this.products,
    required this.stock,
    required this.sales,
    required this.movements,
    required this.employees,
    required this.shifts,
    required this.transfers,
    required this.poultryReceivings,
    required this.butcheringRecords,
    required this.butcherReceipts,
    required this.categories,
    required this.discounts,
    required this.modifiers,
  });

  final String businessName;
  final String currency;
  final DateTime generatedAt;
  final List<Map<String, dynamic>> stores;
  final List<Map<String, dynamic>> products;
  final List<Map<String, dynamic>> stock;
  final List<Map<String, dynamic>> sales;
  final List<Map<String, dynamic>> movements;
  final List<Map<String, dynamic>> employees;
  final List<Map<String, dynamic>> shifts;
  final List<Map<String, dynamic>> transfers;
  final List<Map<String, dynamic>> poultryReceivings;
  final List<Map<String, dynamic>> butcheringRecords;
  final List<Map<String, dynamic>> butcherReceipts;
  final List<Map<String, dynamic>> categories;
  final List<Map<String, dynamic>> discounts;
  final List<Map<String, dynamic>> modifiers;
}
