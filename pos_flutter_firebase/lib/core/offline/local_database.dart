import 'package:hive_flutter/hive_flutter.dart';
import '../adapters/type_adapters.dart';
import '../../shared/models/product.dart';
import '../../shared/models/product_stock.dart';
import '../../shared/models/category.dart';
import '../../shared/models/modifier.dart';
import '../../shared/models/discount.dart';
import '../../shared/models/store.dart';
import '../../shared/models/business.dart';
import '../../shared/models/employee.dart';
import '../../shared/models/sale.dart';
import '../../shared/models/shift.dart';
import '../../shared/models/open_ticket.dart';
import '../../shared/models/inventory_movement.dart';

/// Hive box names (internal).
const _kProducts = 'products_v2';
const _kCategories = 'categories_v2';
const _kModifiers = 'modifiers_v2';
const _kDiscounts = 'discounts_v2';
const _kEmployees = 'employees_v2';
const _kStores = 'stores_v2';
const _kBusiness = 'business_v2';
const _kSales = 'sales_v2';
const _kShifts = 'shifts_v2';
const _kOpenTickets = 'openTickets_v2';
const _kInventoryMovements = 'inventoryMovements_v2';
const _kProductStock = 'productStock_v2';
const _kPinLockout = 'pinLockout_v1';
const _kLastSession = 'lastSession_v1';

class LocalDatabase {
  static Future<void> initialize() async {
    await Hive.initFlutter();
    registerTypeAdapters();
    await Hive.openBox<List>(_kProducts);
    await Hive.openBox<List>(_kCategories);
    await Hive.openBox<List>(_kModifiers);
    await Hive.openBox<List>(_kDiscounts);
    await Hive.openBox<List>(_kEmployees);
    await Hive.openBox<List>(_kStores);
    await Hive.openBox<Business>(_kBusiness);
    await Hive.openBox<List>(_kSales);
    await Hive.openBox<List>(_kShifts);
    await Hive.openBox<List>(_kOpenTickets);
    await Hive.openBox<List>(_kInventoryMovements);
    await Hive.openBox<List>(_kProductStock);
    await Hive.openBox<Map>(_kPinLockout);
    await Hive.openBox<Map>(_kLastSession);
  }

  // ── Products ──
  static Box<List> get _products => Hive.box<List>(_kProducts);

  static Future<void> cacheProducts(String businessId, List<Product> products) async {
    await _products.put(businessId, products);
  }

  static List<Product>? getCachedProducts(String businessId) {
    final data = _products.get(businessId);
    if (data == null) return null;
    return data.cast<Product>();
  }

  // ── Categories ──
  static Box<List> get _categories => Hive.box<List>(_kCategories);

  static Future<void> cacheCategories(String businessId, List<Category> categories) async {
    await _categories.put(businessId, categories);
  }

  static List<Category>? getCachedCategories(String businessId) {
    final data = _categories.get(businessId);
    if (data == null) return null;
    return data.cast<Category>();
  }

  // ── Modifiers ──
  static Box<List> get _modifiers => Hive.box<List>(_kModifiers);

  static Future<void> cacheModifiers(String businessId, List<Modifier> modifiers) async {
    await _modifiers.put(businessId, modifiers);
  }

  static List<Modifier>? getCachedModifiers(String businessId) {
    final data = _modifiers.get(businessId);
    if (data == null) return null;
    return data.cast<Modifier>();
  }

  // ── Discounts ──
  static Box<List> get _discounts => Hive.box<List>(_kDiscounts);

  static Future<void> cacheDiscounts(String businessId, List<Discount> discounts) async {
    await _discounts.put(businessId, discounts);
  }

  static List<Discount>? getCachedDiscounts(String businessId) {
    final data = _discounts.get(businessId);
    if (data == null) return null;
    return data.cast<Discount>();
  }

  // ── Employees ──
  static Box<List> get _employees => Hive.box<List>(_kEmployees);

  static Future<void> cacheEmployees(String businessId, List<Employee> employees) async {
    await _employees.put(businessId, employees);
  }

  static List<Employee>? getCachedEmployees(String businessId) {
    final data = _employees.get(businessId);
    if (data == null) return null;
    return data.cast<Employee>();
  }

  // ── Stores ──
  static Box<List> get _stores => Hive.box<List>(_kStores);

  static Future<void> cacheStores(String businessId, List<Store> stores) async {
    await _stores.put(businessId, stores);
  }

  static List<Store>? getCachedStores(String businessId) {
    final data = _stores.get(businessId);
    if (data == null) return null;
    return data.cast<Store>();
  }

  // ── Business ──
  static Box<Business> get _business => Hive.box<Business>(_kBusiness);

  static Future<void> cacheBusiness(String businessId, Business business) async {
    await _business.put(businessId, business);
  }

  static Business? getCachedBusiness(String businessId) {
    return _business.get(businessId);
  }

  // ── Sales ──
  static Box<List> get _sales => Hive.box<List>(_kSales);

  static Future<void> cacheSales(String businessId, List<Sale> sales) async {
    await _sales.put(businessId, sales);
  }

  static List<Sale>? getCachedSales(String businessId) {
    final data = _sales.get(businessId);
    if (data == null) return null;
    return data.cast<Sale>();
  }

  // ── Shifts ──
  static Box<List> get _shifts => Hive.box<List>(_kShifts);

  static Future<void> cacheShifts(String businessId, List<Shift> shifts) async {
    await _shifts.put(businessId, shifts);
  }

  static List<Shift>? getCachedShifts(String businessId) {
    final data = _shifts.get(businessId);
    if (data == null) return null;
    return data.cast<Shift>();
  }

  // ── Open Tickets ──
  static Box<List> get _openTickets => Hive.box<List>(_kOpenTickets);

  static Future<void> cacheOpenTickets(String businessId, List<OpenTicket> tickets) async {
    await _openTickets.put(businessId, tickets);
  }

  static List<OpenTicket>? getCachedOpenTickets(String businessId) {
    final data = _openTickets.get(businessId);
    if (data == null) return null;
    return data.cast<OpenTicket>();
  }

  // ── Inventory Movements ──
  static Box<List> get _inventoryMovements => Hive.box<List>(_kInventoryMovements);

  static Future<void> cacheInventoryMovements(String businessId, List<InventoryMovement> movements) async {
    await _inventoryMovements.put(businessId, movements);
  }

  static List<InventoryMovement>? getCachedInventoryMovements(String businessId) {
    final data = _inventoryMovements.get(businessId);
    if (data == null) return null;
    return data.cast<InventoryMovement>();
  }

  // ── Product Stock ──
  static Box<List> get _productStock => Hive.box<List>(_kProductStock);

  static Future<void> cacheProductStock(String businessId, List<ProductStock> stockList) async {
    await _productStock.put(businessId, stockList);
  }

  static List<ProductStock>? getCachedProductStock(String businessId) {
    final data = _productStock.get(businessId);
    if (data == null) return null;
    return data.cast<ProductStock>();
  }

  // ── Última sesión (arranque en frío offline) ──
  static Box<Map> get _lastSession => Hive.box<Map>(_kLastSession);

  /// Guarda el `businessId` y `employeeId` de la última sesión exitosa para
  /// poder reconstruir el contexto desde la caché si la app abre sin internet.
  static Future<void> cacheLastSession({
    required String businessId,
    required String employeeId,
  }) async {
    await _lastSession.put('current', {
      'businessId': businessId,
      'employeeId': employeeId,
    });
  }

  static Map<String, String>? getLastSession() {
    final data = _lastSession.get('current');
    if (data == null) return null;
    return {
      'businessId': data['businessId'] as String? ?? '',
      'employeeId': data['employeeId'] as String? ?? '',
    };
  }

  // ── PIN lockout (bloqueo de intentos) ──
  static Box<Map> get _pinLockout => Hive.box<Map>(_kPinLockout);

  /// Devuelve `{'failures': int, 'lockUntil': int}` para un empleado, o null.
  static Map<String, dynamic>? getPinLockout(String employeeId) {
    final data = _pinLockout.get(employeeId);
    if (data == null) return null;
    return Map<String, dynamic>.from(data as Map);
  }

  static Future<void> savePinLockout(String employeeId, Map<String, dynamic> data) async {
    await _pinLockout.put(employeeId, data);
  }

  static Future<void> clearPinLockout(String employeeId) async {
    await _pinLockout.delete(employeeId);
  }

  static Future<void> clearCachedStockForStore(String businessId, String storeId) async {
    final data = _productStock.get(businessId);
    if (data == null) return;
    final stockList = data.cast<ProductStock>().toList();
    for (int i = 0; i < stockList.length; i++) {
      if (stockList[i].storeId == storeId) {
        stockList[i] = ProductStock(
          productId: stockList[i].productId,
          storeId: storeId,
          stockQuantity: 0,
          lowStockAlertQuantity: 0,
        );
      }
    }
    await _productStock.put(businessId, stockList);
  }

  static Future<void> clearAll() async {
    await Future.wait([
      _products.clear(),
      _categories.clear(),
      _modifiers.clear(),
      _discounts.clear(),
      _employees.clear(),
      _stores.clear(),
      _business.clear(),
      _sales.clear(),
      _shifts.clear(),
      _openTickets.clear(),
      _inventoryMovements.clear(),
      _productStock.clear(),
      _pinLockout.clear(),
      _lastSession.clear(),
    ]);
  }
}
