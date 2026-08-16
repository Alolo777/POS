import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:path_provider/path_provider.dart';

import '../../../core/offline/local_database.dart';
import '../../../core/offline/sync_queue.dart';
import '../domain/backup_repository.dart';

class BackupService implements BackupRepository {
  BackupService({FirebaseFirestore? firestore}) : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  Future<String> exportLocalBackup({required String businessId}) async {
    final backup = await _buildBackupMap(businessId: businessId);
    final now = DateTime.now();

    final dir = await _backupDirectory();
    final file = File('${dir.path}/backup_${businessId}_${_fileTimestamp(now)}.json');
    await file.writeAsString(const JsonEncoder.withIndent('  ').convert(backup));
    return file.path;
  }

  Future<String> uploadLocalBackupToCloud({required String businessId}) async {
    final backup = await _buildBackupMap(businessId: businessId);
    final now = DateTime.now();
    final path = 'backups/$businessId/backup_${_fileTimestamp(now)}.json';

    final ref = FirebaseStorage.instance.ref(path);
    final metadata = SettableMetadata(
      contentType: 'application/json',
      customMetadata: {'businessId': businessId, 'exportedAt': now.toIso8601String()},
    );
    await ref.putData(
      utf8.encode(const JsonEncoder().convert(backup)),
      metadata,
    );
    return path;
  }

  Future<Map<String, dynamic>> _buildBackupMap({required String businessId}) async {
    final business = LocalDatabase.getCachedBusiness(businessId);
    final stores = LocalDatabase.getCachedStores(businessId);
    final employees = LocalDatabase.getCachedEmployees(businessId);
    final products = LocalDatabase.getCachedProducts(businessId);
    final productStock = LocalDatabase.getCachedProductStock(businessId);
    final categories = LocalDatabase.getCachedCategories(businessId);
    final modifiers = LocalDatabase.getCachedModifiers(businessId);
    final discounts = LocalDatabase.getCachedDiscounts(businessId);
    final sales = LocalDatabase.getCachedSales(businessId);
    final shifts = LocalDatabase.getCachedShifts(businessId);
    final openTickets = LocalDatabase.getCachedOpenTickets(businessId);
    final inventoryMovements = LocalDatabase.getCachedInventoryMovements(businessId);

    return {
      'schemaVersion': 1,
      'businessId': businessId,
      'exportedAt': DateTime.now().toIso8601String(),
      'localCache': {
        'business': business != null ? {
          'id': business.id, 'name': business.name, 'currency': business.currency,
          'timezone': business.timezone, 'active': business.active,
        } : null,
        'stores': stores?.map((s) => {'id': s.id, 'name': s.name, 'address': s.address, 'phone': s.phone, 'active': s.active}).toList() ?? const [],
        'employees': employees?.map((e) => {'id': e.id, 'businessId': e.businessId, 'authUid': e.authUid, 'name': e.name, 'email': e.email, 'role': e.role, 'storeIds': e.storeIds, 'permissions': e.permissions, 'pin': e.pin, 'active': e.active}).toList() ?? const [],
        'products': products?.map((p) => {'id': p.id, 'name': p.name, 'categoryId': p.categoryId, 'categoryName': p.categoryName, 'sellBy': p.sellBy, 'price': p.price, 'cost': p.cost, 'ref': p.ref, 'trackStock': p.trackStock, 'stockQuantity': p.stockQuantity, 'lowStockAlertQuantity': p.lowStockAlertQuantity, 'presentationType': p.presentationType, 'presentationShape': p.presentationShape, 'presentationColor': p.presentationColor, 'imageUrl': p.imageUrl, 'localImagePath': p.localImagePath, 'active': p.active}).toList() ?? const [],
        'productStock': productStock?.map((s) => {'productId': s.productId, 'storeId': s.storeId, 'stockQuantity': s.stockQuantity, 'lowStockAlertQuantity': s.lowStockAlertQuantity}).toList() ?? const [],
        'categories': categories?.map((c) => {'id': c.id, 'name': c.name, 'color': c.color, 'active': c.active}).toList() ?? const [],
        'modifiers': modifiers?.map((m) => {'id': m.id, 'name': m.name, 'price': m.price, 'active': m.active}).toList() ?? const [],
        'discounts': discounts?.map((d) => {'id': d.id, 'name': d.name, 'type': d.type, 'value': d.value, 'active': d.active}).toList() ?? const [],
        'sales': sales?.map((s) => {'id': s.id, 'businessId': s.businessId, 'folio': s.folio, 'storeId': s.storeId, 'employeeId': s.employeeId, 'shiftId': s.shiftId, 'items': s.items, 'subtotal': s.subtotal, 'discountTotal': s.discountTotal, 'taxTotal': s.taxTotal, 'total': s.total, 'paymentMethod': s.paymentMethod, 'cashReceived': s.cashReceived, 'changeDue': s.changeDue, 'status': s.status, 'originalSaleId': s.originalSaleId, 'returnedItems': s.returnedItems, 'createdAt': s.createdAt?.toIso8601String(), 'cancelledAt': s.cancelledAt?.toIso8601String(), 'cancelReason': s.cancelReason, 'inventoryReturned': s.inventoryReturned, 'clientCreatedAt': s.clientCreatedAt?.toIso8601String(), 'type': s.type, 'refund': s.refund, 'refundIds': s.refundIds}).toList() ?? const [],
        'shifts': shifts?.map((s) => {'id': s.id, 'businessId': s.businessId, 'storeId': s.storeId, 'employeeId': s.employeeId, 'status': s.status, 'openingCash': s.openingCash, 'closingCash': s.closingCash, 'cashSales': s.cashSales, 'cardSales': s.cardSales, 'totalSales': s.totalSales, 'cashRefunds': s.cashRefunds, 'depositsTotal': s.depositsTotal, 'payoutsTotal': s.payoutsTotal, 'cashMovements': s.cashMovements, 'expectedCash': s.expectedCash, 'cashDifference': s.cashDifference, 'openedAt': s.openedAt?.toIso8601String(), 'closedAt': s.closedAt?.toIso8601String()}).toList() ?? const [],
        'openTickets': openTickets?.map((t) => {'id': t.id, 'businessId': t.businessId, 'storeId': t.storeId, 'employeeId': t.employeeId, 'name': t.name, 'items': t.items, 'total': t.total, 'status': t.status, 'createdAt': t.createdAt?.toIso8601String(), 'updatedAt': t.updatedAt?.toIso8601String()}).toList() ?? const [],
        'inventoryMovements': inventoryMovements?.map((m) => {'id': m.id, 'businessId': m.businessId, 'storeId': m.storeId, 'productId': m.productId, 'productName': m.productName, 'type': m.type, 'previousQuantity': m.previousQuantity, 'newQuantity': m.newQuantity, 'difference': m.difference, 'reason': m.reason, 'employeeId': m.employeeId, 'createdAt': m.createdAt?.toIso8601String()}).toList() ?? const [],
      },
      'syncQueue': SyncQueue.getAll().map((op) => op.toMap()).toList(),
    };
  }

  Future<String> exportSalesCsv({required String businessId}) async {
    final snapshot = await _db
        .collection('businesses')
        .doc(businessId)
        .collection('sales')
        .orderBy('clientCreatedAt', descending: true)
        .get();

    final rows = <List<String>>[
      ['folio', 'tipo', 'estado', 'sucursal', 'empleado', 'fecha', 'metodo_pago', 'subtotal', 'descuento', 'impuesto', 'total'],
    ];

    for (final doc in snapshot.docs) {
      final data = doc.data();
      rows.add([
        (data['folio'] as String?) ?? doc.id,
        (data['type'] as String?) ?? 'sale',
        (data['status'] as String?) ?? 'paid',
        (data['storeId'] as String?) ?? '',
        (data['employeeId'] as String?) ?? '',
        _dateString(data['createdAt'] ?? data['clientCreatedAt']),
        (data['paymentMethod'] as String?) ?? '',
        _numString(data['subtotal']),
        _numString(data['discountTotal']),
        _numString(data['taxTotal']),
        _numString(data['total']),
      ]);
    }

    final dir = await _backupDirectory();
    final now = DateTime.now();
    final file = File('${dir.path}/ventas_${businessId}_${_fileTimestamp(now)}.csv');
    await file.writeAsString(rows.map(_csvRow).join('\n'));
    return file.path;
  }

  Future<Directory> _backupDirectory() async {
    final downloads = await getDownloadsDirectory();
    if (downloads != null) return downloads;
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory('${base.path}/pos_backups');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  String _fileTimestamp(DateTime date) {
    return '${date.year}${date.month.toString().padLeft(2, '0')}${date.day.toString().padLeft(2, '0')}_${date.hour.toString().padLeft(2, '0')}${date.minute.toString().padLeft(2, '0')}${date.second.toString().padLeft(2, '0')}';
  }

  String _dateString(dynamic value) {
    if (value is Timestamp) return value.toDate().toIso8601String();
    if (value is DateTime) return value.toIso8601String();
    return value?.toString() ?? '';
  }

  String _numString(dynamic value) => ((value as num?) ?? 0).toStringAsFixed(2);

  String _csvRow(List<String> values) => values.map(_csvCell).join(',');

  String _csvCell(String value) {
    final escaped = value.replaceAll('"', '""');
    return '"$escaped"';
  }
}