# Plan de Reestructuración — POS Flutter Firebase

> **Objetivo:** Proyecto para máximo 10 sucursales, 50 empleados, 5000 productos.
> **Principio:** Refactorización progresiva sin romper funcionalidad existente.
> **Regla:** No mezclar refactor con nuevas features. Cada fase termina con `flutter analyze` y `flutter test` OK.

---

## Fase 0 — Preparación (Seguridad + Configuración)

### 0.1 Proteger PINs de empleados

**Archivos a modificar:**
- `lib/models/employee.dart`
- `lib/services/employee_service.dart`
- `lib/services/auth_service.dart`
- `lib/screens/employee_pin_screen.dart`

**Qué hacer:**
1. Agregar dependencia `crypto: ^3.0.3` en `pubspec.yaml`
2. En `employee.dart`:
   - Agregar getter `bool verifyPin(String input)` que compare hash
   - Agregar `String get pinHash` que retorne el hash del pin actual
   - Mantener campo `pin` pero renombrar semánticamente a `pinHash` internamente
3. En `employee_service.dart`:
   - Al guardar: convertir `pin` a SHA-256 hash antes de enviar a Firestore
   - Al leer: mantener el hash, no guardar texto plano
4. En `employee_pin_screen.dart`:
   - Cambiar `employee.pin == enteredPin` por `employee.verifyPin(enteredPin)`
5. Ejecutar script one-time en Firebase Console para hashear PINs existentes (o pedir a usuarios que reestablezcan)

**Verificación:** `flutter test` debe pasar. Login con PIN debe seguir funcionando.

### 0.2 Agregar flutter_dotenv para configuración

**Archivos a crear:**
- `.env` (no versionar, agregar a `.gitignore`)
- `.env.example` (versionar con valores dummy)

**Archivos a modificar:**
- `pubspec.yaml` (agregar `flutter_dotenv: ^5.1.0`)
- `lib/main.dart` (cargar dotenv antes de Firebase)
- `.gitignore` (agregar `.env`)

**Qué hacer:**
1. Crear `.env.example`:
```
FIREBASE_API_KEY=your_key
FIREBASE_APP_ID=your_app_id
FIREBASE_MESSAGING_SENDER_ID=your_sender_id
FIREBASE_PROJECT_ID=your_project_id
FIREBASE_AUTH_DOMAIN=your_domain
FIREBASE_STORAGE_BUCKET=your_bucket
FIREBASE_MEASUREMENT_ID=your_measurement_id
```
2. En `main.dart`: `await dotenv.load(fileName: '.env');`
3. En `firebase_options.dart`: leer desde `dotenv.env['FIREBASE_API_KEY']` en lugar de strings hardcodeados
4. FirebaseOptions web/android mantener estructura pero con valores dinámicos

**Verificación:** La app debe inicializar Firebase correctamente con variables de entorno.

---

## Fase 1 — Arquitectura Base (Capas + DI)

### 1.1 Crear estructura de capas

**Nueva estructura de carpetas:**

```
lib/
  core/
    di/              # Inyección de dependencias
    errors/          # Manejo centralizado de errores
**ProductService → ProductRepository**
- Mover `watchProducts`, `getCachedProducts`, `addProduct`, `updateProduct`, `deactivateProduct`, `getSuggestedRef`
- Mover `_saveProductImageLocally`, `_optimizeImage`
- El servicio original se marca como `@deprecated` y delega al repositorio

**SaleService → SaleRepository**
- Separar: `createSale`, `cancelSale`, `watchSales`, `fetchSalesPage`, `watchBusinessSales`, `getCachedSales`, `refundExists`
- La lógica de folios (contadores) se queda en el repositorio
- `_validateReturnQuantities`, `_isFullReturn`, `_refundSubtotal` son privadas del repositorio

**ShiftService → ShiftRepository**
- `watchOpenShift`, `getOpenShift`, `watchShifts`, `watchAllClosedShifts`
- `openShift`, `addCashMovement`, `closeShift`

**StockService → StockRepository**
- `watchStockByStore`, `getCachedStock`, `applyLocalStockDelta`
- Migrar StreamController manual a `ref.watch` con Riverpod o a un `StreamProvider`

**CategoryService → CategoryRepository**
- `watchCategories`, `getCachedCategories`, `addCategory`, `updateCategory`, `deactivateCategory`

**DiscountService → DiscountRepository**
- `watchDiscounts`, `getCachedDiscounts`, `addDiscount`, `updateDiscount`, `deactivateDiscount`

**ModifierService → ModifierRepository**
- `watchModifiers`, `getCachedModifiers`, `addModifier`, `updateModifier`, `deactivateModifier`

**EmployeeService → EmployeeRepository**
- `watchEmployees`, `getCachedEmployees`, `addEmployee`, `updateEmployee`

**BusinessService → BusinessRepository**
- `watchBusiness`, `getCachedBusiness`, `watchStores`, `getCachedStores`
- `updateBusiness`, `addStore`, `updateStore`

**InventoryService → InventoryRepository**
- `watchMovements`, `getCachedMovements`, `adjustStock`

**AuthService → AuthRepository**
- `signIn`, `signUp`, `signOut`, `ensureCurrentUserWorkspace`, `createOwnerWorkspace`
- `_mapError` se mantiene privado

**OpenTicketService → OpenTicketRepository**
- `watchOpenTickets`, `getCachedOpenTickets`, `saveOpenTicket`, `closeOpenTicket`, `cancelOpenTicket`

**ButcherService → ButcherRepository + ButcherReceiptRepository**
- Dividir: `watchRecipe`, `getRecipe`, `saveRecipe` van a ButcherRecipeRepository
- `registerEntry`, `registerPartsEntry`, `cancelEntry` van a ButcherReceiptRepository
- `assignPendingStockToProduct`, `getPendingStockBySection`, `clearStoreStock` van a ButcherReceiptRepository
- `getSectionRealData`, `_addStockToExistingProducts`, `_applyStockChange`, `_subtractStock` se quedan como helpers

**IMPORTANTE:** Por ahora los repositorios llaman internamente al servicio viejo. No reescribir lógica, solo redirigir. Ejemplo:
```dart
class ProductRepository implements IProductRepository {
  final _service = ProductService(); // temporal, luego inline
  
  @override
  Stream<List<Product>> watchProducts({required String businessId}) {
    return _service.watchProducts(businessId: businessId);
  }
}
```

Luego en Fase 2 se inlinea la lógica del servicio dentro del repositorio.

---

## Fase 2 — Refactor de Servicios (Eliminar Monolitos)

### 2.1 Dividir ButcherService

**Crear:**
- `lib/data/repositories/butcher_recipe_repository.dart`
- `lib/data/repositories/butcher_receipt_repository.dart`

**Mover de `butcher_service.dart`:**
- A `ButcherRecipeRepository`: `watchRecipe`, `getRecipe`, `saveRecipe` (4 métodos)
- A `ButcherReceiptRepository`: `registerEntry`, `registerPartsEntry`, `cancelEntry`, `assignPendingStockToProduct`, `getPendingStockBySection`, `clearStoreStock`, `getSectionRealData`, `watchReceipts` (8 métodos)
- Helpers privados: `_addStockToExistingProducts`, `_applyStockChange`, `_subtractStock`, `_consumePendingSectionsForStore` (4 métodos)

**Resultado:** `ButcherService` original se elimina completamente. Cada repositorio queda con ~200 líneas máximo.

### 2.2 Dividir SaleService

**Crear:**
- `lib/domain/usecases/create_sale_usecase.dart`
- `lib/domain/usecases/cancel_sale_usecase.dart`

**CreateSaleUseCase:**
```dart
class CreateSaleUseCase {
  final SaleRepository _saleRepo;
  final StockRepository _stockRepo;
  
  Future<({String folio, String saleId})> execute({
    required String businessId,
    required String storeId,
    required String employeeId,
    required String shiftId,
    required List<CartItem> items,
    required double subtotal,
    required double discountTotal,
    required double total,
    required String paymentMethod,
    double? cashReceived,
    double? changeDue,
  }) async {
    // 1. Validar stock (online o offline)
    // 2. Si online: usar transacción Firestore en SaleRepository.createSale()
    // 3. Si offline: encolar en SyncQueue y aplicar delta local
    // 4. Registrar movimientos de inventario
    // 5. Retornar folio
  }
}
```

**CancelSaleUseCase:**
```dart
class CancelSaleUseCase {
  final SaleRepository _saleRepo;
  final StockRepository _stockRepo;
  
  Future<String> execute({
    required String businessId,
    required Sale sale,
    required List<Map<String, dynamic>> returnItems,
    required bool returnInventory,
    required String reason,
    String? refundShiftId,
    String? refundEmployeeId,
  }) async {
    // 1. Validar devolución
    // 2. Si online: transacción Firestore
    // 3. Si offline: encolar
    // 4. Registrar movimientos
    // 5. Retornar refund ID
  }
}
```

### 2.3 Limpiar modelos — eliminar campos duplicados

**Product (product.dart):**
- Eliminar: `stock` (int), `lowStockAlert` (int)
- Renombrar: `stockQuantity` → `stock`, `lowStockAlertQuantity` → `lowStockAlertThreshold`
- Ajustar: `fromDoc` para leer ambos nombres (backwards compatibility con datos legacy)
- La app internamente solo usa `stock` (double) y `lowStockAlertThreshold` (double)

```dart
class Product {
  const Product({
    required this.id,
    required this.name,
    required this.price,
    required this.cost,
    required this.stock,        // antes stockQuantity
    required this.lowStockAlertThreshold, // antes lowStockAlertQuantity
    ...
  });

  final double stock;
  final double lowStockAlertThreshold;
}
```

**Sale (sale.dart):**
- Eliminar: `refund` (bool redundante con `type` y `status`)
- Eliminar: `folioType`, `refundCreatedFrom` (solo para debug, no necesarios en modelo)
- Mantener: `type` ('sale' | 'refund'), `status` ('paid' | 'cancelled' | 'partially_cancelled' | 'refund')
- Simplificar getters: `bool get isRefund => type == 'refund';`

```dart
class Sale {
  // Antes: 30 campos
  // Después: ~22 campos
}
```

### 2.4 Estandarizar Hive con TypeAdapters

**Archivos a crear:**
- `lib/data/local/adapters/product_adapter.dart`
- `lib/data/local/adapters/category_adapter.dart`
- `lib/data/local/adapters/sale_adapter.dart`
- `lib/data/local/adapters/employee_adapter.dart`
- `lib/data/local/adapters/shift_adapter.dart`
- `lib/data/local/adapters/product_stock_adapter.dart`
- `lib/data/local/adapters/pending_operation_adapter.dart`

**pubspec.yaml:**
```yaml
dependencies:
  hive_flutter: ^1.1.0
  hive: ^2.2.3

dev_dependencies:
  hive_generator: ^2.0.1
  build_runner: ^2.4.8
```

**Ejemplo de adaptador manual (sin codegen):**
```dart
// product_adapter.dart
class ProductAdapter {
  static Map<String, dynamic> toMap(Product p) => {
    'id': p.id,
    'name': p.name,
    'price': p.price,
    'cost': p.cost,
    'stock': p.stock,
    'active': p.active,
    ...
  };

  static Product fromMap(Map<String, dynamic> map) => Product(
    id: map['id'] as String,
    name: map['name'] as String,
    price: (map['price'] as num).toDouble(),
    cost: (map['cost'] as num).toDouble(),
    stock: (map['stock'] as num).toDouble(),
    active: map['active'] as bool? ?? true,
    ...
  );
}
```

**Modificar `LocalDatabase`:**
- Cambiar cajas de `Box<Map>` a `Box<Product>` (con TypeAdapter registrado)
- `cacheProducts` ya no serializa manualmente, usa `box.put(businessId, products)`
- `getCachedProducts` retorna `List<Product>` tipado

**Archivos a modificar después:**
- `product_service.dart`: eliminar mapeos manuales de cache
- `sale_service.dart`: eliminar `_saleFromMap`
- Todos los `cacheX` y `getCachedX` se simplifican drasticamente

---

## Fase 3 — Navegación + Estado

### 3.1 Migrar a GoRouter

**pubspec.yaml:**
```yaml
dependencies:
  go_router: ^14.2.0
```

**Archivos a crear:**
- `lib/presentation/routes/app_router.dart`

```dart
// app_router.dart
final appRouterProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateProvider);
  
  return GoRouter(
    initialLocation: '/login',
    redirect: (context, state) {
      final loggedIn = authState.valueOrNull != null;
      final onLogin = state.matchedLocation == '/login';
      
      if (!loggedIn && !onLogin) return '/login';
      if (loggedIn && onLogin) return '/home';
      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      ShellRoute(
        builder: (_, __, child) => AppShell(child: child),
        routes: [
          GoRoute(path: '/home', builder: (_, __) => const HomeScreen()),
          GoRoute(path: '/pos', builder: (_, __) => const PosScreen()),
          GoRoute(path: '/products', builder: (_, __) => const ProductsScreen()),
          GoRoute(path: '/receipts', builder: (_, __) => const ReceiptsScreen()),
          GoRoute(path: '/settings', builder: (_, __) => const SettingsScreen()),
          GoRoute(path: '/back-office', builder: (_, __) => const BackOfficeScreen()),
          GoRoute(path: '/shift', builder: (_, __) => const ShiftScreen()),
          GoRoute(
            path: '/ticket/:saleId',
            builder: (_, state) => TicketDetailScreen(
              saleId: state.pathParameters['saleId']!,
            ),
          ),
        ],
      ),
    ],
  );
});
```

**Archivos a modificar:**
- `lib/main.dart`: Reemplazar `MaterialApp` con `MaterialApp.router`
- Todas las screens: Reemplazar `Navigator.push(context, MaterialPageRoute(...))` con `context.push('/ticket/${sale.id}')`
- Eliminar `AuthGate` en main.dart (GoRouter redirect lo reemplaza)

**Rutas protegidas adicionales:**
```dart
// Redirect por PIN
if (state.matchedLocation != '/pin' && !ref.read(sessionProvider).hasPinVerified) {
  return '/pin';
}
// Redirect por sucursal
if (state.matchedLocation != '/select-store' && ref.read(sessionProvider).selectedStoreId == null) {
  return '/select-store';
}
```

### 3.2 Crear AppSessionNotifier

**Archivos a crear:**
- `lib/presentation/providers/session_provider.dart`

```dart
class AppSessionNotifier extends ChangeNotifier {
  AppSession? _session;
  String? _selectedStoreId;
  bool _pinVerified = false;

  AppSession? get session => _session;
  String? get selectedStoreId => _selectedStoreId;
  Employee? get employee => _session?.employee;
  Business? get business => _session?.business;
  List<Store> get stores => _session?.stores ?? [];
  Store? get selectedStore => stores.where((s) => s.id == _selectedStoreId).firstOrNull;
  bool get isLoggedIn => _session != null;
  bool get hasPinVerified => _pinVerified;
  bool get needsStoreSelection => stores.length > 1 && _selectedStoreId == null;

  Future<void> loadSession() async {
    final contextService = AppContextService();
    _session = await contextService.loadSession();
    notifyListeners();
  }

  void selectStore(String storeId) {
    _selectedStoreId = storeId;
    notifyListeners();
  }

  void verifyPin() {
    _pinVerified = true;
    notifyListeners();
  }

  Future<void> logout() async {
    await FirebaseAuth.instance.signOut();
    _session = null;
    _selectedStoreId = null;
    _pinVerified = false;
    notifyListeners();
  }
}
```

### 3.3 Migrar CartProvider a Provider

El `CartProvider` ya existe y es correcto. Solo asegurar que esté disponible globalmente:

```dart
// lib/presentation/providers/cart_provider.dart (mover desde lib/providers/)
final cartProvider = ChangeNotifierProvider<CartProvider>((ref) => CartProvider());
```

En lugar de instanciar `CartProvider()` manual, las screens lo obtienen con `ref.watch(cartProvider)` (Riverpod) o `context.read<CartProvider>()` (Provider nativo).

---

## Fase 4 — Firebase Performance

### 4.1 Optimizar watchSales

**Archivo:** `lib/data/repositories/sale_repository.dart`

**Antes:**
```dart
Stream<List<Sale>> watchSales({required String businessId, required String storeId}) {
  return _db
      .collection('businesses').doc(businessId).collection('sales')
      .snapshots()  // <-- Lee TODAS las ventas del negocio
      .map((snapshot) {
    final sales = snapshot.docs.map(Sale.fromDoc)
        .where((sale) => sale.storeId == storeId)  // <-- Filtra en cliente
        .toList();
    ...
  });
}
```

**Después:**
```dart
Stream<List<Sale>> watchSales({required String businessId, required String storeId}) {
  return _db
      .collection('businesses').doc(businessId).collection('sales')
      .where('storeId', isEqualTo: storeId)  // <-- Filtro en servidor
      .orderBy('clientCreatedAt', descending: true)  // <-- Requiere índice
      .snapshots()
      .map((snapshot) => snapshot.docs.map(Sale.fromDoc).toList());
}
```

**Firestore index requerido:**
```json
{
  "collectionGroup": "sales",
  "queryScope": "COLLECTION",
  "fields": [
    { "fieldPath": "storeId", "order": "ASCENDING" },
    { "fieldPath": "clientCreatedAt", "order": "DESCENDING" }
  ]
}
```
(Actualizar `firestore.indexes.json`)

### 4.2 Optimizar watchStockByStore

**Archivo:** `lib/data/repositories/stock_repository.dart`

**Antes:** StreamController manual con collectionGroup.

**Después:** Usar `StreamProvider` o el stream nativo de Firebase sin StreamController:

```dart
Stream<Map<String, ProductStock>> watchStockByStore({
  required String businessId,
  required String storeId,
}) {
  return _db
      .collectionGroup('stockByStore')
      .where('businessId', isEqualTo: businessId)
      .where('storeId', isEqualTo: storeId)
      .snapshots()  // Firebase maneja el lifecycle
      .map((snapshot) {
    final result = <String, ProductStock>{};
    for (final doc in snapshot.docs) {
      result[doc.id] = ProductStock.fromDoc(doc);
    }
    return result;
  });
}
```

No necesita StreamController manual. El `StreamSubscription` lo maneja Provider/Riverpod.

### 4.3 Agregar índices compuestos faltantes

**Actualizar `firestore.indexes.json`:**

```json
{
  "indexes": [
    { /* sales por storeId + clientCreatedAt - YA EXISTE */ },
    {
      "collectionGroup": "stockByStore",
      "queryScope": "COLLECTION",
      "fields": [
        { "fieldPath": "businessId", "order": "ASCENDING" },
        { "fieldPath": "storeId", "order": "ASCENDING" }
      ]
    },
    {
      "collectionGroup": "shifts",
      "queryScope": "COLLECTION",
      "fields": [
        { "fieldPath": "storeId", "order": "ASCENDING" },
        { "fieldPath": "status", "order": "ASCENDING" }
      ]
    },
    {
      "collectionGroup": "inventoryMovements",
      "queryScope": "COLLECTION",
      "fields": [
        { "fieldPath": "storeId", "order": "ASCENDING" }
      ]
    }
  ]
}
```

### 4.4 Optimizar ButcherService.getSectionRealData()

**Problema:** N+1 queries — por cada sección, hace query individual de stock + sales.

**Solución:**
1. Leer todos los stocks de una vez con `collectionGroup('stockByStore').where('storeId', isEqualTo: storeId)`
2. Indexar por `productId` en un `Map<String, double>`
3. Leer todas las ventas del día con una sola query con `storeId` filtrado
4. Procesar en memoria

```dart
Future<Map<String, ({double price, double stock, double sales})>> getSectionRealData({
  required String businessId,
  required String storeId,
  required List<String> sectionNames,
}) async {
  // 1. Leer productos activos
  final productsSnap = await _db
      .collection('businesses').doc(businessId)
      .collection('products')
      .where('active', isEqualTo: true)
      .get();

  final productByName = <String, ({String id, double price})>{};
  for (final doc in productsSnap.docs) {
    final data = doc.data();
    final name = (data['name'] as String? ?? '').trim().toLowerCase();
    productByName[name] = (id: doc.id, price: (data['price'] as num? ?? 0).toDouble());
  }

  // 2. Leer stock de todos los productos en UNA query
  final stockSnap = await _db
      .collectionGroup('stockByStore')
      .where('storeId', isEqualTo: storeId)
      .get();
  final stockByProductId = <String, double>{};
  for (final doc in stockSnap.docs) {
    stockByProductId[doc.id] = (doc.data()['stockQuantity'] as num? ?? 0).toDouble();
  }

  // 3. Leer ventas de hoy en UNA query
  final todayStart = DateTime.now();
  final todayEnd = DateTime(todayStart.year, todayStart.month, todayStart.day + 1);
  final salesSnap = await _db
      .collection('businesses').doc(businessId)
      .collection('sales')
      .where('storeId', isEqualTo: storeId)
      .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(todayStart))
      .where('createdAt', isLessThan: Timestamp.fromDate(todayEnd))
      .get();

  final salesByName = <String, double>{};
  for (final doc in salesSnap.docs) {
    for (final item in (doc.data()['items'] as List? ?? [])) {
      final iMap = Map<String, dynamic>.from(item as Map);
      final name = (iMap['name'] as String? ?? '').trim().toLowerCase();
      salesByName[name] = (salesByName[name] ?? 0) + (iMap['quantity'] as num? ?? 0).toDouble();
    }
  }

  // 4. Armar resultado
  final result = <String, ({double price, double stock, double sales})>{};
  for (final name in sectionNames) {
    final key = name.trim().toLowerCase();
    final product = productByName[key];
    if (product == null) {
      result[name] = (price: 0, stock: 0, sales: 0);
      continue;
    }
    result[name] = (
      price: product.price,
      stock: stockByProductId[product.id] ?? 0,
      sales: salesByName[key] ?? 0,
    );
  }

  return result;
}
```

---

## Fase 5 — Testing

### 5.1 Agregar Unit Tests para repositorios

**Archivos a crear:**
- `test/data/repositories/product_repository_test.dart`
- `test/data/repositories/sale_repository_test.dart`
- `test/data/repositories/shift_repository_test.dart`
- `test/data/repositories/stock_repository_test.dart`
- `test/data/repositories/category_repository_test.dart`
- `test/data/repositories/employee_repository_test.dart`
- `test/data/repositories/auth_repository_test.dart`
- `test/data/repositories/butcher_receipt_repository_test.dart`

**Para cada repositorio, probar:**
- Operación exitosa (online)
- Operación offline (cola de sync)
- Validaciones (campos obligatorios, valores negativos)
- Casos borde (stock insuficiente, REF duplicado)

**Ejemplo:**
```dart
void main() {
  late FakeFirebaseFirestore fakeFirestore;
  late ProductRepository repository;

  setUp(() {
    fakeFirestore = FakeFirebaseFirestore();
    repository = ProductRepository(
      firestore: fakeFirestore,
      connectivity: AlwaysOnlineConnectivity(),
      localDb: LocalDatabase(),
    );
  });

  group('addProduct', () {
    test('online: creates product and stock', () async { ... });
    test('offline: enqueues operation', () async { ... });
    test('validates empty name', () async {
      expect(
        () => repository.addProduct(name: ''),
        throwsA(isA<StateError>()),
      );
    });
  });
}
```

### 5.2 Agregar Widget Tests para screens principales

**Archivos a crear:**
- `test/presentation/screens/pos_screen_test.dart`
- `test/presentation/screens/products_screen_test.dart`
- `test/presentation/screens/login_screen_test.dart`
- `test/presentation/widgets/product_grid_test.dart`
- `test/presentation/widgets/cart_panel_test.dart`

**Para widget tests:**
- Mockear repositorios con `mocktail`
- Probar que los widgets renderizan datos
- Probar interacciones (tap, navegación)

```dart
void main() {
  testWidgets('ProductGrid muestra productos', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          productRepositoryProvider.overrideWith((ref) => MockProductRepository()),
        ],
        child: const MaterialApp(home: ProductGrid(businessId: 'test', storeId: 'test')),
      ),
    );
    expect(find.text('Producto 1'), findsOneWidget);
  });
}
```

### 5.3 Agregar Integration Test con Patrol

**Archivos a crear:**
- `test_e2e/pos_flow_test.dart`
- `test_e2e/sale_flow_test.dart`
- `test_e2e/offline_sync_test.dart`

**Requerimientos:**
```yaml
dev_dependencies:
  patrol: ^3.0.0
```

```dart
// pos_flow_test.dart
void main() {
  patrolTest(
    'POS: crear producto, agregar al carrito y cobrar',
    ($) async {
      // 1. Login
      await $.pumpWidgetAndSettle();
      await $.enterTextByKey('emailField', 'test@test.com');
      await $.enterTextByKey('passwordField', '123456');
      await $.tapByKey('loginButton');
      await $.pumpAndSettle();
      
      // 2. Navegar a POS
      await $.tapByText('Punto de venta');
      await $.pumpAndSettle();
      
      // 3. Buscar producto
      await $.enterTextByKey('searchField', 'Producto 1');
      await $.pumpAndSettle();
      
      // 4. Agregar al carrito
      await $.tapByText('Producto 1');
      await $.pumpAndSettle();
      
      // 5. Cobrar
      await $.tapByText('Cobrar \$100.00');
      await $.pumpAndSettle();
      await $.tapByText('Cobrar efectivo');
      await $.pumpAndSettle();
      
      // 6. Verificar mensaje de éxito
      expect($('Venta creada'), findsOneWidget);
    },
  );
}
```

---

## Fase 6 — Limpieza Final

### 6.1 Eliminar archivos obsoletos

**Servicios reemplazados por repositorios (marcar @deprecated):**
- `lib/services/product_service.dart` → reemplazado por `lib/data/repositories/product_repository.dart`
- `lib/services/sale_service.dart` → reemplazado por `lib/data/repositories/sale_repository.dart`
- `lib/services/shift_service.dart` → reemplazado por `lib/data/repositories/shift_repository.dart`
- `lib/services/stock_service.dart` → reemplazado por `lib/data/repositories/stock_repository.dart`
- `lib/services/category_service.dart` → reemplazado por `lib/data/repositories/category_repository.dart`
- `lib/services/discount_service.dart` → reemplazado por `lib/data/repositories/discount_repository.dart`
- `lib/services/modifier_service.dart` → reemplazado por `lib/data/repositories/modifier_repository.dart`
- `lib/services/employee_service.dart` → reemplazado por `lib/data/repositories/employee_repository.dart`
- `lib/services/business_service.dart` → reemplazado por `lib/data/repositories/business_repository.dart`
- `lib/services/inventory_service.dart` → reemplazado por `lib/data/repositories/inventory_repository.dart`
- `lib/services/auth_service.dart` → reemplazado por `lib/data/repositories/auth_repository.dart`
- `lib/services/butcher_service.dart` → reemplazado por `lib/data/repositories/butcher_recipe_repository.dart` + `butcher_receipt_repository.dart`
- `lib/services/open_ticket_service.dart` → reemplazado por `lib/data/repositories/open_ticket_repository.dart`

**Conservar (no tienen lógica de negocio, solo utilería):**
- `lib/services/connectivity_service.dart` → mover a `lib/core/network/connectivity_service.dart`
- `lib/services/pdf_service.dart` → mover a `lib/data/services/pdf_service.dart` o conservar
- `lib/services/backup_service.dart` → mover a `lib/data/services/backup_service.dart`
- `lib/services/logger_service.dart` → mover a `lib/core/utils/logger_service.dart`

**Modelos viejos (reemplazados):**
- Los modelos en `lib/models/` se conservan pero se limpian (eliminar campos duplicados)
- `lib/models/app_session.dart` → se queda pero los repositorios ya no lo usan directamente
- `lib/models/butcher_section.dart` → se queda

### 6.2 Eliminar imports innecesarios en todas las screens

**Buscar con:**
```bash
dart fix --dry-run
```
**Aplicar:**
```bash
dart fix --apply
```

### 6.3 Verificar que flutter analyze pase sin warnings

```bash
cd C:\Users\Alonso-Manuel\POS\pos_flutter_firebase
flutter analyze
```

**Resolver:**
- Warnings de tipos (cast seguros)
- Warnings de unused imports
- Warnings de prefer_const_constructors
- Warnings de prefer_const_literals_to_create_immutables

### 6.4 Verificar que todos los tests pasen

```bash
flutter test
```

Debe dar: `All tests passed!`

---

## Resumen de Archivos a Crear vs Modificar

| Fase | Crear | Modificar | Eliminar |
|------|-------|-----------|----------|
| **Fase 0** | `.env`, `.env.example` | `pubspec.yaml`, `main.dart`, `employee.dart`, `employee_service.dart`, `employee_pin_screen.dart`, `firebase_options.dart`, `.gitignore` | - |
| **Fase 1** | `core/di/providers.dart`, 8 interfaces en `domain/repositories/`, 8 repositorios en `data/repositories/` | `main.dart`, `pubspec.yaml` | - |
| **Fase 2** | `butcher_recipe_repository.dart`, `butcher_receipt_repository.dart`, `create_sale_usecase.dart`, `cancel_sale_usecase.dart`, 7 adaptadores Hive | `product.dart`, `sale.dart`, `LocalDatabase`, `product_service.dart`, `sale_service.dart`, `butcher_service.dart` | `butcher_service.dart` (eventualmente) |
| **Fase 3** | `app_router.dart`, `session_provider.dart` | `main.dart`, todas las screens (navegación GoRouter), reemplazar Navigator.push | `AuthGate` en main.dart |
| **Fase 4** | - | `sale_repository.dart`, `stock_repository.dart`, `firestore.indexes.json`, `butcher_receipt_repository.dart` | - |
| **Fase 5** | ~15 archivos de test | - | - |
| **Fase 6** | - | - | 13 archivos service antiguos (después de verificar reemplazo) |

---

## Orden de Implementación Recomendado

```
Semana 1: Fase 0 (Seguridad) → Fase 4.3 (Índices) → Fase 2.3 (Limpiar modelos)
Semana 2: Fase 1.1-1.2 (Estructura de capas + DI)
Semana 3: Fase 1.3-1.4 (Interfaces + migrar servicios a repositorios)
Semana 4: Fase 2.1-2.2 (Dividir ButcherService y SaleService)
Semana 5: Fase 2.4 (Hive TypeAdapters)
Semana 6: Fase 3 (GoRouter + AppSessionNotifier + CartProvider global)
Semana 7: Fase 4.1-4.2-4.4 (Performance Firebase)
Semana 8: Fase 5 (Testing)
Semana 9: Fase 6 (Limpieza final)
```

**Tiempo total estimado:** 9 semanas (trabajo parcial, no dedicación exclusiva)

---

## Notas para el desarrollador

1. **No intentes hacer todo de una vez.** Cada fase debe terminar con `flutter analyze` y `flutter test` OK.
2. **Usa branches de git:** `refactor/fase-1-capas`, `refactor/fase-2-servicios`, etc.
3. **No mezcles refactor con features nuevas.** Si encuentras un bug durante el refactor, anótalo y arréglalo después.
4. **Los tests existentes son tu red de seguridad.** Si después de un cambio los tests fallan, significa que algo cambió de comportamiento.
5. **Para 10 sucursales máximo**, esta arquitectura es más que suficiente. No necesitas microservicios, ni colas de mensajes, ni event sourcing.
6. **Firestore puede manejar 10 sucursales sin problemas.** El límite real está en ~500 writes/segundo por documento, que para tu volumen es irrelevante.
7. **Prioriza la fase 0 (seguridad) primero.** Es lo único que podría causar un problema real si alguien accede a la DB de Firebase.