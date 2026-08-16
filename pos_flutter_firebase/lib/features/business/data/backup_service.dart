import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:path_provider/path_provider.dart';

import '../../../core/offline/local_database.dart';
import '../../../core/offline/sync_queue.dart';
import '../../../shared/models/business.dart';
import '../../../shared/models/category.dart';
import '../../../shared/models/discount.dart';
import '../../../shared/models/employee.dart';
import '../../../shared/models/inventory_movement.dart';
import '../../../shared/models/modifier.dart';
import '../../../shared/models/open_ticket.dart';
import '../../../shared/models/product.dart';
import '../../../shared/models/product_stock.dart';
import '../../../shared/models/sale.dart';
import '../../../shared/models/shift.dart';
import '../../../shared/models/store.dart';
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

  Future<String> importLocalBackup({required String businessId, required String filePath}) async {
    final file = File(filePath);
    if (!await file.exists()) {
      throw StateError('El archivo de respaldo no existe');
    }
    final decoded = jsonDecode(await file.readAsString());
    final backup = Map<String, dynamic>.from(decoded as Map);

    if (backup['businessId'] != businessId) {
      throw StateError('El respaldo no corresponde a esta empresa');
    }
    final cache = Map<String, dynamic>.from(backup['localCache'] as Map? ?? {});

    await LocalDatabase.cacheBusiness(businessId, _businessFromMap(businessId, Map<String, dynamic>.from(cache['business'] as Map? ?? const {})));
    await LocalDatabase.cacheStores(businessId, _storesFromMap(cache['stores'] as List? ?? const []));
    await LocalDatabase.cacheEmployees(businessId, _employeesFromMap(businessId, cache['employees'] as List? ?? const []));
    await LocalDatabase.cacheProducts(businessId, _productsFromMap(cache['products'] as List? ?? const []));
    await LocalDatabase.cacheProductStock(businessId, _stockFromMap(cache['productStock'] as List? ?? const []));
    await LocalDatabase.cacheCategories(businessId, _categoriesFromMap(cache['categories'] as List? ?? const []));
    await LocalDatabase.cacheModifiers(businessId, _modifiersFromMap(cache['modifiers'] as List? ?? const []));
    await LocalDatabase.cacheDiscounts(businessId, _discountsFromMap(cache['discounts'] as List? ?? const []));
    await LocalDatabase.cacheSales(businessId, _salesFromMap(businessId, cache['sales'] as List? ?? const []));
    await LocalDatabase.cacheShifts(businessId, _shiftsFromMap(businessId, cache['shifts'] as List? ?? const []));
    await LocalDatabase.cacheOpenTickets(businessId, _ticketsFromMap(businessId, cache['openTickets'] as List? ?? const []));
    await LocalDatabase.cacheInventoryMovements(businessId, _movementsFromMap(cache['inventoryMovements'] as List? ?? const []));

    return filePath;
  }

  DateTime? _dt(dynamic value) {
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  List<Map<String, dynamic>> _maps(List<dynamic> list) => list
      .where((e) => e is Map)
      .map((e) => Map<String, dynamic>.from(e as Map))
      .toList();

  List<String> _strings(dynamic list) =>
      List<String>.from((list as List? ?? const []).whereType<String>());

  Business _businessFromMap(String businessId, Map<String, dynamic> m) => Business(
        id: m['id'] as String? ?? businessId,
        name: m['name'] as String? ?? 'Mi negocio',
        currency: m['currency'] as String? ?? 'MXN',
        timezone: m['timezone'] as String? ?? 'America/Mexico_City',
        active: m['active'] as bool? ?? true,
      );

  List<Store> _storesFromMap(List<dynamic> list) => _maps(list)
      .map((m) => Store(
            id: m['id'] as String? ?? '',
            name: m['name'] as String? ?? '',
            address: m['address'] as String? ?? '',
            phone: m['phone'] as String? ?? '',
            active: m['active'] as bool? ?? true,
          ))
      .toList();

  List<Employee> _employeesFromMap(String businessId, List<dynamic> list) => _maps(list)
      .map((m) => Employee(
            id: m['id'] as String? ?? '',
            businessId: m['businessId'] as String? ?? businessId,
            authUid: m['authUid'] as String? ?? '',
            name: m['name'] as String? ?? '',
            email: m['email'] as String? ?? '',
            role: m['role'] as String? ?? 'cashier',
            storeIds: _strings(m['storeIds']),
            permissions: _strings(m['permissions']),
            pin: m['pin'] as String? ?? '',
            active: m['active'] as bool? ?? true,
          ))
      .toList();

  List<Product> _productsFromMap(List<dynamic> list) => _maps(list)
      .map((m) => Product(
            id: m['id'] as String? ?? '',
            name: m['name'] as String? ?? '',
            categoryId: m['categoryId'] as String?,
            categoryName: m['categoryName'] as String?,
            sellBy: m['sellBy'] as String? ?? 'unit',
            price: ((m['price'] as num?) ?? 0).toDouble(),
            cost: ((m['cost'] as num?) ?? 0).toDouble(),
            ref: m['ref'] as String? ?? '',
            trackStock: m['trackStock'] as bool? ?? false,
            stockQuantity: ((m['stockQuantity'] as num?) ?? 0).toDouble(),
            lowStockAlertQuantity: ((m['lowStockAlertQuantity'] as num?) ?? 0).toDouble(),
            presentationType: m['presentationType'] as String? ?? 'shape',
            presentationShape: m['presentationShape'] as String? ?? 'square',
            presentationColor: ((m['presentationColor'] as num?) ?? 0xFF9E9E9E).toInt(),
            imageUrl: m['imageUrl'] as String?,
            localImagePath: m['localImagePath'] as String?,
            active: m['active'] as bool? ?? true,
            stockLoaded: true,
          ))
      .toList();

  List<ProductStock> _stockFromMap(List<dynamic> list) => _maps(list)
      .map((m) => ProductStock(
            productId: m['productId'] as String? ?? '',
            storeId: m['storeId'] as String? ?? '',
            stockQuantity: ((m['stockQuantity'] as num?) ?? 0).toDouble(),
            lowStockAlertQuantity: ((m['lowStockAlertQuantity'] as num?) ?? 0).toDouble(),
            chickenCount: m['chickenCount'] as int?,
            price: (m['price'] as num?)?.toDouble(),
          ))
      .toList();

  List<Category> _categoriesFromMap(List<dynamic> list) => _maps(list)
      .map((m) => Category(
            id: m['id'] as String? ?? '',
            name: m['name'] as String? ?? '',
            color: ((m['color'] as num?) ?? 0xFF607D8B).toInt(),
            active: m['active'] as bool? ?? true,
          ))
      .toList();

  List<Modifier> _modifiersFromMap(List<dynamic> list) => _maps(list)
      .map((m) => Modifier(
            id: m['id'] as String? ?? '',
            name: m['name'] as String? ?? '',
            price: ((m['price'] as num?) ?? 0).toDouble(),
            active: m['active'] as bool? ?? true,
          ))
      .toList();

  List<Discount> _discountsFromMap(List<dynamic> list) => _maps(list)
      .map((m) => Discount(
            id: m['id'] as String? ?? '',
            name: m['name'] as String? ?? '',
            type: m['type'] as String? ?? 'fixed',
            value: ((m['value'] as num?) ?? 0).toDouble(),
            active: m['active'] as bool? ?? true,
          ))
      .toList();

  List<Sale> _salesFromMap(String businessId, List<dynamic> list) => _maps(list)
      .map((m) => Sale(
            id: m['id'] as String? ?? '',
            businessId: m['businessId'] as String? ?? businessId,
            folio: m['folio'] as String? ?? '',
            storeId: m['storeId'] as String? ?? '',
            employeeId: m['employeeId'] as String? ?? '',
            shiftId: m['shiftId'] as String?,
            items: _maps(m['items'] as List? ?? const []),
            subtotal: ((m['subtotal'] as num?) ?? 0).toDouble(),
            discountTotal: ((m['discountTotal'] as num?) ?? 0).toDouble(),
            taxTotal: ((m['taxTotal'] as num?) ?? 0).toDouble(),
            total: ((m['total'] as num?) ?? 0).toDouble(),
            paymentMethod: m['paymentMethod'] as String? ?? 'cash',
            cashReceived: (m['cashReceived'] as num?)?.toDouble(),
            changeDue: (m['changeDue'] as num?)?.toDouble(),
            status: m['status'] as String? ?? 'completed',
            originalSaleId: m['originalSaleId'] as String?,
            returnedItems: _maps(m['returnedItems'] as List? ?? const []),
            createdAt: _dt(m['createdAt']),
            cancelledAt: _dt(m['cancelledAt']),
            cancelReason: m['cancelReason'] as String?,
            inventoryReturned: m['inventoryReturned'] as bool? ?? false,
            clientCreatedAt: _dt(m['clientCreatedAt']),
            type: m['type'] as String? ?? 'sale',
            refund: m['refund'] as bool? ?? false,
            refundIds: _strings(m['refundIds']),
          ))
      .toList();

  List<Shift> _shiftsFromMap(String businessId, List<dynamic> list) => _maps(list)
      .map((m) => Shift(
            id: m['id'] as String? ?? '',
            businessId: m['businessId'] as String? ?? businessId,
            storeId: m['storeId'] as String? ?? '',
            employeeId: m['employeeId'] as String? ?? '',
            status: m['status'] as String? ?? 'open',
            openingCash: ((m['openingCash'] as num?) ?? 0).toDouble(),
            closingCash: (m['closingCash'] as num?)?.toDouble(),
            cashSales: ((m['cashSales'] as num?) ?? 0).toDouble(),
            cardSales: ((m['cardSales'] as num?) ?? 0).toDouble(),
            totalSales: ((m['totalSales'] as num?) ?? 0).toDouble(),
            cashRefunds: ((m['cashRefunds'] as num?) ?? 0).toDouble(),
            depositsTotal: ((m['depositsTotal'] as num?) ?? 0).toDouble(),
            payoutsTotal: ((m['payoutsTotal'] as num?) ?? 0).toDouble(),
            cashMovements: _maps(m['cashMovements'] as List? ?? const []),
            expectedCash: ((m['expectedCash'] as num?) ?? 0).toDouble(),
            cashDifference: ((m['cashDifference'] as num?) ?? 0).toDouble(),
            openedAt: _dt(m['openedAt']),
            closedAt: _dt(m['closedAt']),
          ))
      .toList();

  List<OpenTicket> _ticketsFromMap(String businessId, List<dynamic> list) => _maps(list)
      .map((m) => OpenTicket(
            id: m['id'] as String? ?? '',
            businessId: m['businessId'] as String? ?? businessId,
            storeId: m['storeId'] as String? ?? '',
            employeeId: m['employeeId'] as String? ?? '',
            name: m['name'] as String? ?? 'Ticket abierto',
            items: _maps(m['items'] as List? ?? const []),
            total: ((m['total'] as num?) ?? 0).toDouble(),
            status: m['status'] as String? ?? 'open',
            createdAt: _dt(m['createdAt']),
            updatedAt: _dt(m['updatedAt']),
          ))
      .toList();

  List<InventoryMovement> _movementsFromMap(List<dynamic> list) => _maps(list)
      .map((m) => InventoryMovement.fromMap(m, m['id'] as String? ?? ''))
      .toList();

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