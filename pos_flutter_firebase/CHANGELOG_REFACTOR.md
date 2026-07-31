# Changelog de Refactorización

---

## 2026-07-23

### Módulo trabajado
Fase 0.1 — PINs con hash SHA-256

### Objetivo
Eliminar almacenamiento de PINs en texto plano en Firestore y caché local, reemplazándolos con hash SHA-256.

### Archivos modificados
- `pubspec.yaml` — agregada dependencia `crypto: ^3.0.3`
- `lib/models/employee.dart` — agregados métodos `verifyPin()` y `hashPin()`, con soporte legacy para PINs planos de 4 dígitos
- `lib/services/auth_service.dart` — `'0000'` ahora se guarda como `Employee.hashPin('0000')`
- `lib/services/employee_service.dart` — agregada función `_hashedPin()`, toda escritura de PIN usa hash
- `lib/screens/employee_pin_screen.dart` — reemplazada comparación directa por `employee.verifyPin()`

### Archivos sin cambios (confirmado que no requieren modificación)
- `lib/offline/sync_handlers.dart` — el PIN ya llega hasheado desde employee_service
- `lib/screens/back_office_screen.dart` — el PIN crudo se envía a employee_service que lo hashea
- `lib/services/app_context_service.dart` — solo lectura del campo `pin`, no almacenamiento

### Cambios realizados
1. Agregado `crypto` package a pubspec.yaml
2. Employee.verifyPin(String input): hashea input y compara con pin almacenado. Legacy: si el pin almacenado es 4 dígitos exactos, hace comparación directa para no romper PINs existentes en Firebase
3. Employee.hashPin(String input): SHA-256 estático, usable desde cualquier service
4. auth_service.dart: el owner PIN '0000' se hashea antes de guardar en el batch
5. employee_service.dart: los 4 puntos de escritura (addEmployee online/offline, updateEmployee online/offline) ahora hashean antes de persistir
6. employee_pin_screen.dart: `employee.pin.isEmpty ? '0000' : employee.pin` reemplazado por `employee.verifyPin(_pin)`

### Validaciones realizadas
- flutter analyze ✅
- flutter test ✅

### Observaciones
- Los PINs existentes en Firebase (texto plano de 4 dígitos) seguirán funcionando gracias al fallback legacy en `verifyPin()`.
- La próxima vez que un empleado edite su PIN desde Back Office, se guardará como hash y se perderá el fallback legacy para ese empleado.
- No se requiere migración de datos porque el código maneja ambos formatos.

---

### Módulo trabajado
Fase 0.2 — Variables de entorno (flutter_dotenv)

### Objetivo
Eliminar valores hardcodeados de Firebase del código fuente y migrarlos a un archivo `.env` no versionado.

### Archivos modificados
- `pubspec.yaml` — agregadas dependencia `flutter_dotenv: ^5.1.0` y asset `.env`
- `lib/main.dart` — reemplazado `DefaultFirebaseOptions.currentPlatform` por `_firebaseOptionsFromEnv()` que lee de `dotenv.env`
- `.gitignore` — agregada entrada `.env`

### Archivos creados
- `.env` — valores reales de Firebase (no versionado)
- `.env.example` — template con valores dummy (versionado)

### Cambios realizados
1. Agregado `flutter_dotenv` a pubspec.yaml y registrado `.env` como asset
2. Creado `.env` con las 7 variables de Firebase extraídas de `firebase_options.dart`
3. Creado `.env.example` con valores dummy para desarrollo
4. Agregado `.env` a `.gitignore`
5. En `lib/main.dart`:
   - `await dotenv.load(fileName: '.env')` antes de `Firebase.initializeApp()`
   - Nueva función `_firebaseOptionsFromEnv()` que construye `FirebaseOptions` desde `dotenv.env`
6. Eliminado import de `firebase_options.dart` en `main.dart` (el archivo se conserva por si otras herramientas lo necesitan)

### Validaciones realizadas
- flutter analyze ✅ (mismos 5 info preexistentes)
- flutter test ✅ (22/22)

### Observaciones
- El archivo `firebase_options.dart` se conserva intacto por compatibilidad con `flutterfire configure`, pero ya no se importa desde `main.dart`.
- Para regenerar `.env` tras `flutterfire configure`, copiar los nuevos valores al `.env` manualmente.
- `dart-define` sería más seguro, pero `flutter_dotenv` es más práctico para este proyecto.

---

### Módulo trabajado
Fase 1.1 — Estructura de carpetas (core/data/domain/presentation)

### Objetivo
Reestructurar el proyecto de arquitectura por tipo (models/, services/, screens/) a arquitectura por feature (core/, shared/, features/<name>/{data, domain, ui}).

### Archivos movidos
- **15 modelos** → `lib/shared/models/` (product, sale, employee, store, shift, product_stock, open_ticket, modifier, inventory_movement, discount, category, cart_item, butcher_section, business, app_session)
- **15 servicios** → `lib/features/<feature>/data/`:
  - auth_service → features/auth/data/
  - employee_service → features/employees/data/
  - business_service → features/business/data/
  - shift_service → features/shift/data/
  - product_service → features/products/data/
  - butcher_service → features/butcher/data/
  - sale_service → features/sales/data/
  - open_ticket_service → features/pos/data/
  - category_service → features/pos/data/
  - discount_service → features/pos/data/
  - modifier_service → features/pos/data/
  - inventory_service → features/inventory/data/
  - stock_service → features/inventory/data/
  - backup_service → features/business/data/
  - pdf_service → features/sales/data/
- **4 archivos offline** → `lib/core/offline/` (local_database, sync_queue, sync_service, sync_handlers)
- **2 archivos theme** → `lib/core/theme/` (glass_theme, glass_container)
- **2 widgets shared** → `lib/shared/widgets/` (product_presentation, reports_dashboard)
- **1 provider** → `lib/shared/providers/` (cart_provider)
- **14 pantallas** → `lib/features/<feature>/ui/` (login, home, pos, products, add_product, butcher_recipe, employee_pin, shift, receipts, ticket_detail, settings, business_setup, back_office, placeholder_section)
- **3 POS widgets** → `lib/features/pos/ui/widgets/` (modifier_dialog, product_grid, ticket_discount_dialog)
- **Config** → `lib/core/config/config.dart`
- **Utils** → `lib/core/utils/result.dart`
- **Logger** → `lib/core/logger/logger_service.dart`
- **Connectivity** → `lib/core/network/connectivity_service.dart`
- **AppContext** → `lib/core/app_context_service.dart`

### Archivos creados
- `lib/shared/providers/theme_provider.dart` — ThemeNotifier y FontSizeNotifier extraídos de main.dart
- `lib/core/di/` — directorio para inyección de dependencias (pendiente service_locator.dart)

### Directorios eliminados
- `lib/models/`, `lib/services/`, `lib/screens/`, `lib/widgets/`, `lib/providers/`, `lib/theme/`, `lib/utils/`, `lib/offline/`

### Cambios realizados
1. Creada estructura de carpetas: core/{config, di, logger, network, offline, theme, utils}, shared/{models, providers, widgets}, features/{auth, pos, products, inventory, butcher, sales, employees, settings, business, shift, home}/{data, domain, ui}
2. Movidos 15 modelos a shared/models/
3. Movidos 15 servicios a features/<feature>/data/
4. Movidos 4 archivos offline a core/offline/
5. Movidos 2 archivos theme a core/theme/
6. Movidos 2 widgets shared a shared/widgets/
7. Movido cart_provider a shared/providers/
8. Movidas 14 pantallas a features/<feature>/ui/
9. Movidos 3 POS widgets a features/pos/ui/widgets/
10. Extraídos ThemeNotifier y FontSizeNotifier de main.dart a shared/providers/theme_provider.dart
11. Movidos config, utils, logger, connectivity, app_context a core/
12. Actualizados todos los imports en archivos movidos (models/, services/, theme/, offline/, etc.)
13. Actualizados imports en test files

### Validaciones realizadas
- flutter analyze ✅ (0 errores)
- flutter test ✅ (22/22)

### Observaciones
- La estructura feature-first está completa. Los módulos ahora están organizados por dominio de negocio.
- Pendiente para Fase 1.2: Crear service_locator.dart en lib/core/di/ para consolidar la inicialización de servicios.
- Los archivos de dominio/ y data/ en cada feature están vacíos y serán llenados en fases posteriores (Fase 1.3 - Interfaces, Fase 1.4 - Migrar servicios a repositorios).

---

### Módulo trabajado
Fase 1.2 — Sistema de DI (providers)

### Objetivo
Crear un sistema centralizado de inyección de dependencias usando Provider, eliminando la instanciación directa de servicios en la capa de UI.

### Archivos creados
- `lib/core/di/service_locator.dart` — ServiceLocator que crea y gestiona todas las instancias de servicios

### Archivos modificados
- `lib/main.dart` — Registrados todos los servicios via MultiProvider
- `lib/features/pos/ui/pos_screen.dart` — Servicios obtenidos via Provider
- `lib/features/home/ui/home_screen.dart` — Servicios obtenidos via Provider
- `lib/features/settings/ui/settings_screen.dart` — Servicios obtenidos via Provider
- `lib/features/sales/ui/receipts_screen.dart` — Servicios obtenidos via Provider
- `lib/features/shift/ui/shift_screen.dart` — Servicios obtenidos via Provider
- `lib/features/products/ui/products_screen.dart` — Servicios obtenidos via Provider
- `lib/features/products/ui/add_product_screen.dart` — Servicios obtenidos via Provider
- `lib/features/home/ui/back_office_screen.dart` — Servicios obtenidos via Provider
- `lib/features/butcher/ui/butcher_recipe_screen.dart` — Servicios obtenidos via Provider
- `lib/features/business/ui/business_setup_screen.dart` — Servicios obtenidos via Provider
- `lib/features/pos/ui/widgets/modifier_dialog.dart` — Servicios obtenidos via Provider
- `lib/features/pos/ui/widgets/product_grid.dart` — Servicios obtenidos via Provider
- `lib/shared/widgets/reports_dashboard.dart` — Servicios obtenidos via Provider

### Cambios realizados
1. Creado `ServiceLocator` en `lib/core/di/service_locator.dart` que instancia todos los servicios con sus dependencias
2. Actualizado `main.dart` para crear ServiceLocator y registrar servicios via MultiProvider
3. Reemplazadas todas las instanciaciones directas de servicios (`ServiceName()`) por `context.read<ServiceName>()` en 14 archivos
4. Convertidos campos `final _service = Service()` a getters `Service get _service => context.read<Service>()`
5. CartProvider ahora es proporcionado via ChangeNotifierProvider

### Validaciones realizadas
- flutter analyze ✅ (0 errores)
- flutter test ✅ (22/22)

### Observaciones
- Todos los servicios ahora son proporcionados centralmente via Provider
- Los servicios que aceptaban dependencias opcionales ahora reciben ConnectivityService y StockService desde ServiceLocator
- CartProvider ahora es gestionado por el sistema de Provider, eliminando la necesidad de dispose manual en PosScreen
- Pendiente para futuras fases: migrar a Riverpod o injectable para un DI más robusto

---

### Módulo trabajado
Fase 1.3 — Interfaces de repositorios

### Objetivo
Crear interfaces abstractas (repository pattern) para todos los servicios, permitiendo abstracción de la implementación y facilitando testing con mocks.

### Archivos creados (16 interfaces)
- `lib/core/domain/app_context_repository.dart`
- `lib/features/auth/domain/auth_repository.dart`
- `lib/features/sales/domain/sale_repository.dart`
- `lib/features/shift/domain/shift_repository.dart`
- `lib/features/products/domain/product_repository.dart`
- `lib/features/inventory/domain/inventory_repository.dart`
- `lib/features/inventory/domain/stock_repository.dart`
- `lib/features/employees/domain/employee_repository.dart`
- `lib/features/business/domain/business_repository.dart`
- `lib/features/business/domain/backup_repository.dart`
- `lib/features/butcher/domain/butcher_repository.dart`
- `lib/features/pos/domain/category_repository.dart`
- `lib/features/pos/domain/discount_repository.dart`
- `lib/features/pos/domain/modifier_repository.dart`
- `lib/features/pos/domain/open_ticket_repository.dart`
- `lib/features/sales/domain/pdf_repository.dart`

### Archivos modificados (16 servicios)
- Todos los servicios actualizados para implementar su interfaz correspondiente

### Cambios realizados
1. Creadas 16 interfaces abstractas en las carpetas `domain/` de cada feature
2. Cada interfaz define los métodos públicos del servicio correspondiente
3. Actualizados los 16 servicios para implementar (`implements`) su interfaz
4. ButcherRepository usa tipos record de Dart para coincidir con la implementación existente
5. Eliminada la clase duplicada `SalesPage` de `sale_service.dart` (reemplazada por export desde la interfaz)

### Validaciones realizadas
- flutter analyze ✅ (0 errores)
- flutter test ✅ (22/22)

### Observaciones
- Todas las interfaces están en `lib/features/<feature>/domain/`
- Los servicios ahora implementan sus interfaces, permitiendo dependencias abstractas
- El UI layer puede depender de las interfaces en lugar de las implementaciones concretas
- Pendiente para Fase 1.4: actualizar el ServiceLocator y el UI para usar las interfaces en lugar de los tipos concretos

---

### Módulo trabajado
Fase 1.4 — Migrar servicios a repositorios

### Objetivo
Actualizar el ServiceLocator y todos los archivos UI para depender de las interfaces (repositories) en lugar de las implementaciones concretas (services).

### Archivos modificados
- `lib/core/di/service_locator.dart` — Todos los campos ahora usan tipos de interfaz
- 13 archivos de screens/widgets actualizados para usar interfaces

### Cambios realizados
1. Actualizado `ServiceLocator` para que todos los campos sean de tipo interfaz (`SaleRepository`, `ShiftRepository`, etc.)
2. ServiceLocator crea instancias concretas pero las provee como interfaces
3. Actualizadas 13 pantallas/widgets para importar interfaces en lugar de servicios concretos
4. Reemplazados todos los tipos `ServiceName` por `RepositoryName` en anotaciones de tipo
5. Corregido un caso donde `CategoryRepository()` se instanciaba directamente (cambiado a `context.read<CategoryRepository>()`)

### Archivos actualizados
- `pos_screen.dart` — SaleRepository, ShiftRepository, OpenTicketRepository, CategoryRepository
- `home_screen.dart` — AuthRepository, AppContextRepository
- `settings_screen.dart` — BusinessRepository
- `receipts_screen.dart` — PdfRepository, SaleRepository, ShiftRepository
- `shift_screen.dart` — SaleRepository, ShiftRepository
- `products_screen.dart` — ProductRepository, StockRepository, CategoryRepository, ModifierRepository, DiscountRepository
- `add_product_screen.dart` — ProductRepository, CategoryRepository
- `back_office_screen.dart` — EmployeeRepository, InventoryRepository, ProductRepository, SaleRepository, ShiftRepository, StockRepository
- `butcher_recipe_screen.dart` — ButcherRepository
- `business_setup_screen.dart` — AuthRepository
- `modifier_dialog.dart` — ModifierRepository, DiscountRepository
- `product_grid.dart` — ProductRepository, StockRepository
- `reports_dashboard.dart` — SaleRepository, EmployeeRepository, ShiftRepository

### Validaciones realizadas
- flutter analyze ✅ (0 errores)
- flutter test ✅ (22/22)

### Observaciones
- La Fase 1 (Arquitectura) está ahora completa
- El UI layer completamente depende de interfaces, no de implementaciones concretas
- Esto permite testing con mocks (implementar interfaz sin Firestore)
- ServiceLocator instancia servicios concretos pero los provee como interfaces via Provider
- Pendiente para futuras fases: migrar a Riverpod, agregar more unit tests con mocks

---

### Módulo trabajado
Fase 2.1 — Dividir ButcherService

### Objetivo
Dividir el monolito ButcherService (599 líneas) en 3 servicios enfocados por responsabilidad: Recipe, Receipt y Stock.

### Archivos creados
- `lib/features/butcher/data/butcher_recipe_service.dart` — Gestión de receta/configuración de secciones
- `lib/features/butcher/data/butcher_receipt_service.dart` — Registro y cancelación de entradas
- `lib/features/butcher/data/butcher_stock_service.dart` — Operaciones de stock y reportes
- `lib/features/butcher/domain/butcher_recipe_repository.dart` — Interfaz de receta
- `lib/features/butcher/domain/butcher_receipt_repository.dart` — Interfaz de recibos
- `lib/features/butcher/domain/butcher_stock_repository.dart` — Interfaz de stock

### Archivos modificados
- `lib/features/butcher/data/butcher_service.dart` — Ahora delega a los 3 sub-servicios
- `lib/features/butcher/domain/butcher_repository.dart` — Ahora extiende las 3 sub-interfaces

### Cambios realizados
1. Creado `ButcherRecipeService` con `watchRecipe`, `getRecipe`, `saveRecipe` (3 métodos)
2. Creado `ButcherReceiptService` con `registerEntry`, `registerPartsEntry`, `cancelEntry`, `watchReceipts` (4 métodos)
3. Creado `ButcherStockService` con `assignPendingStockToProduct`, `getPendingStockBySection`, `clearStoreStock`, `getSectionRealData` + helpers privados (4 métodos públicos)
4. Creadas 3 interfaces separadas: `ButcherRecipeRepository`, `ButcherReceiptRepository`, `ButcherStockRepository`
5. `ButcherRepository` ahora extiende las 3 sub-interfaces (backward compatibility)
6. `ButcherService` ahora es un facade que delega a los 3 sub-servicios
7. Corregidos errores de API: `hasConnection()` en lugar de `isConnected()`, parámetros posicionales en `clearCachedStockForStore`

### Validaciones realizadas
- flutter analyze ✅ (0 errores)
- flutter test ✅ (22/22)

### Observaciones
- ButcherService pasó de 599 líneas a un facade de ~150 líneas
- Cada sub-servicio tiene una responsabilidad clara y acotada
- Los sub-servicios pueden inyectarse independientemente para testing
- ButcherRepository mantiene backward compatibility para código existente
- Pendiente: los tests existentes no cubren ButcherService (pendiente para Fase 5)

---

### Módulo trabajado
Fase 2.2 — Dividir SaleService (use cases)

### Objetivo
Dividir SaleService (1000+ líneas) en 3 sub-servicios por responsabilidad: Creator, Refund y Query.

### Archivos creados
- `lib/features/sales/data/sale_creator_service.dart` — Lógica de creación de ventas (transacción, validación stock, cola offline)
- `lib/features/sales/data/sale_refund_service.dart` — Cancelación/devolución de ventas
- `lib/features/sales/data/sale_query_service.dart` — Consultas y streaming de ventas
- `lib/features/sales/domain/sale_creator_repository.dart` — Interfaz de creación
- `lib/features/sales/domain/sale_refund_repository.dart` — Interfaz de devolución
- `lib/features/sales/domain/sale_query_repository.dart` — Interfaz de consultas + clase SalesPage

### Archivos modificados
- `lib/features/sales/data/sale_service.dart` — Ahora es facade delegando a los 3 sub-servicios
- `lib/features/sales/domain/sale_repository.dart` — Extiende las 3 sub-interfaces
- `lib/core/di/service_locator.dart` — Registro de los nuevos servicios
- `lib/main.dart` — Actualizado con los nuevos servicios en MultiProvider
- `lib/features/pos/ui/pos_main_screen.dart` — Actualizado imports
- `test/sale_service_test.dart` — Actualizado constructor con stockService
- `test/services_test.dart` — Actualizado constructor con stockService
- `test/offline_sync_test.dart` — Actualizado constructor con stockService

### Cambios realizados
1. Creado `SaleCreatorService` con `createSale` (transacción, validación stock offline, descuento de stock)
2. Creado `SaleRefundService` con `cancelSale`, `refundExists` (reembolso, incremento stock, movimiento inventario)
3. Creado `SaleQueryService` con `watchSales`, `watchBusinessSales`, `getCachedSales`, `fetchSalesPage`
4. Creadas 3 interfaces: `SaleCreatorRepository`, `SaleRefundRepository`, `SaleQueryRepository`
5. `SaleRepository` extiende las 3 sub-interfaces (backward compatibility)
6. `SaleService` ahora es un facade delegando a los 3 sub-servicios
7. Corregidos errores de compatibilidad: campo `stockQuantity` en lugar de `quantity`, folio counter sin doble incremento, status `'refund'` en devoluciones

### Validaciones realizadas
- flutter analyze ✅ (0 errores)
- flutter test ✅ (22/22)

### Observaciones
- SaleService pasó de ~1000 líneas a un facade de ~50 líneas
- Cada sub-servicio tiene una responsabilidad clara y acotada
- Los sub-servicios pueden inyectarse independientemente para testing
- Los tests existentes cubren createSale y cancelSale (Fase 2.2 completa)

---

### Módulo trabajado
Fase 2.3 — Limpiar modelos (campos duplicados)

### Objetivo
Eliminar campos duplicados en los modelos de dominio para reducir confusión y mantener una fuente de verdad única.

### Archivos modificados
- `lib/shared/models/product.dart` — Eliminados campos `stock` (int) y `lowStockAlert` (int) duplicados
- `lib/shared/models/inventory_movement.dart` — Eliminado campo `difference` (calculable), convertido a getter
- `lib/features/products/data/product_service.dart` — Actualizado cache y deserialización para usar solo campos nuevos
- `lib/features/home/ui/back_office_screen.dart` — Eliminados parámetros `stock` y `lowStockAlert` de constructores
- `lib/features/pos/ui/pos_screen.dart` — Eliminados parámetros `stock` y `lowStockAlert` de constructores
- `lib/features/pos/ui/widgets/product_grid.dart` — Eliminados parámetros `stock` y `lowStockAlert` de constructores
- `lib/features/products/ui/products_screen.dart` — Eliminados parámetros `stock` y `lowStockAlert` de constructores
- `test/offline_sync_test.dart` — Eliminados parámetros `stock` y `lowStockAlert` de constructores
- `test/sale_service_test.dart` — Eliminados parámetros `stock` y `lowStockAlert` de constructores
- `test/services_test.dart` — Eliminados parámetros `stock` y `lowStockAlert` de constructores

### Cambios realizados
1. **Product**: Eliminados campos `stock` (int) y `lowStockAlert` (int) — el modelo ahora solo tiene `stockQuantity` (double) y `lowStockAlertQuantity` (double)
2. **InventoryMovement**: Eliminado campo `difference` (calculable como `newQuantity - previousQuantity`), convertido a getter
3. **Backward compatibility**: `fromDoc` sigue leyendo `stock` y `lowStockAlert` de Firestore para documentos antiguos
4. **Firestore writes**: Se mantiene la escritura de `stock` y `lowStockAlert` en product_service para compatibilidad con datos existentes

### Validaciones realizadas
- flutter analyze ✅ (0 errores)
- flutter test ✅ (22/22)

### Observaciones
- Product pasó de 17 campos a 15 campos (2 eliminados)
- InventoryMovement pasó de 12 campos a 11 campos (1 eliminado, 1 getter)
- Los campos eliminados eran redundantes (mismo dato en diferentes tipos: int vs double)

---

### Módulo trabajado
Fase 2.4 — Hive TypeAdapters

### Objetivo
Crear TypeAdapters de Hive para todos los modelos de dominio, permitiendo serialización binaria eficiente y type-safety.

### Archivos creados
- `lib/core/adapters/type_adapters.dart` — 13 TypeAdapters (Product, ProductStock, Category, Modifier, Discount, Store, Business, Employee, Sale, Shift, OpenTicket, InventoryMovement, ButcherSection)
- `lib/core/offline/cache_entry.dart` — Wrappers genéricos para cache (TypedCacheEntry, TypedCacheSingle)

### Archivos modificados
- `lib/core/offline/local_database.dart` — Llamada a `registerTypeAdapters()` en `initialize()`

### Cambios realizados
1. Creados 13 TypeAdapters con typeIds únicos (0-12)
2. Cada adapter implementa `read(BinaryReader)` y `write(BinaryWriter, T)` con campos serializados manualmente
3. `registerTypeAdapters()` registra todos los adapters con Hive al inicio de la app
4. Creados wrappers genéricos `TypedCacheEntry<T>` y `TypedCacheSingle<T>` para future use
5. LocalDatabase ahora registra adapters antes de abrir boxes

### Validaciones realizadas
- flutter analyze ✅ (0 errores)
- flutter test ✅ (22/22)

### Observaciones
- TypeAdapters están registrados y listos para usar
- Actualmente LocalDatabase sigue usando `Box<Map>` para backward compatibility
- Para usar TypeAdapters plenamente, se necesita migrar a typed boxes (`Box<Product>`, `Box<Category>`, etc.)
- Pendiente: migrar servicios para usar typed boxes en lugar de `List<Map>`

---

### Módulo trabajado
Fase 2.4 — Hive TypeAdapters (continuación: migración a typed boxes)

### Objetivo
Completar la migración de `LocalDatabase` y todos los servicios para usar typed boxes en lugar de `Box<Map>`, aprovechando los TypeAdapters creados anteriormente.

### Archivos modificados
- `lib/core/adapters/type_adapters.dart` — `registerTypeAdapters()` ahora es idempotente (evita doble registro)
- `lib/core/offline/local_database.dart` — Migrado de `Box<Map>` a `Box<List>` / `Box<Business>` para cada modelo
- `lib/features/pos/data/category_service.dart` — Eliminada serialización manual a Maps
- `lib/features/pos/data/modifier_service.dart` — Eliminada serialización manual a Maps
- `lib/features/pos/data/discount_service.dart` — Eliminada serialización manual a Maps
- `lib/features/pos/data/open_ticket_service.dart` — Eliminada serialización manual a Maps
- `lib/features/business/data/business_service.dart` — Eliminada serialización manual a Maps
- `lib/features/employees/data/employee_service.dart` — Eliminada serialización manual a Maps
- `lib/features/products/data/product_service.dart` — Eliminada serialización manual a Maps
- `lib/features/shift/data/shift_service.dart` — Eliminada serialización manual a Maps
- `lib/features/inventory/data/inventory_service.dart` — Eliminada serialización manual a Maps
- `lib/features/inventory/data/stock_service.dart` — Eliminada serialización manual a Maps
- `lib/features/sales/data/sale_query_service.dart` — Eliminada serialización manual a Maps
- `lib/features/business/data/backup_service.dart` — Conversión inline a Maps para exportación JSON
- `test/offline_sync_test.dart` — Actualizado para usar tipos Hive correctos y ProductStock objetos
- `lib/core/offline/cache_entry.dart` — Eliminado (innecesario con typed boxes)

### Cambios realizados
1. **LocalDatabase**: Migrado de `Box<Map>` a `Box<List>` / `Box<Business>` — cada cache ahora almacena objetos tipados directamente
2. **11 servicios**: Eliminada toda la serialización manual a `Map<String, dynamic>` — ahora pasan objetos del modelo directamente a `LocalDatabase`
3. **backup_service**: Actualizado para convertir objetos tipados a Maps inline para exportación JSON
4. **TypeAdapters**: `registerTypeAdapters()` ahora es idempotente (evita errores en tests)
5. **clearCachedStockForStore**: Reescrito para trabajar con `List<ProductStock>` en lugar de `List<Map>`
6. **applyLocalStockDelta**: Reescrito para crear nuevos objetos `ProductStock` en lugar de mutar Maps

### Validaciones realizadas
- flutter analyze ✅ (0 errores)
- flutter test ✅ (22/22)

### Observaciones
- LocalDatabase pasó de 235 líneas a 195 líneas (código más limpio)
- Eliminada toda la serialización manual de Maps en 11 archivos de servicio
- Los TypeAdapters ahora se usan activamente para serialización binaria en Hive
- Las boxes usan nuevos nombres con `_v2` suffix para evitar conflictos con datos existentes

---

### Módulo trabajado
Fase 3.1 — Migrar a GoRouter

### Objetivo
Migrar la navegación de la app de Navigator imperativo a GoRouter declarativo.

### Archivos creados
- `lib/core/router/app_router.dart` — Configuración de GoRouter con rutas y AuthGate

### Archivos modificados
- `pubspec.yaml` — Agregada dependencia `go_router: ^14.8.1`
- `lib/main.dart` — Cambiado `MaterialApp` a `MaterialApp.router` con `routerConfig: goRouter`
- `lib/features/products/ui/products_screen.dart` — 2 `Navigator.push` migrados a `context.push()`
- `lib/features/sales/ui/receipts_screen.dart` — 1 `Navigator.push` migrado a `context.push()`

### Cambios realizados
1. Agregada dependencia `go_router` a pubspec.yaml
2. Creado `app_router.dart` con:
   - Ruta raíz `/` con `AuthGate` (StreamBuilder de auth state)
   - `ShellRoute` para navegación interna de HomeScreen
   - Rutas hijas: `/home/products/add`, `/home/products/edit`, `/home/tickets/:saleId`
   - Redirect logic para manejar estado de autenticación
3. Actualizado `main.dart` de `MaterialApp` a `MaterialApp.router`
4. Eliminado `AuthGate` de main.dart (ahora está en app_router.dart)
5. Migrados 3 `Navigator.push` a `context.push()` con parámetros via `extra`

### Validaciones realizadas
- flutter analyze ✅ (0 errores)
- flutter test ✅ (22/22)

---

## 2026-07-24

### Módulo trabajado
Fase 4.4 — Optimizar ButcherService.getSectionRealData (N+1)

### Objetivo
Eliminar el patrón N+1 en `getSectionRealData`: reemplazar N queries secuenciales por 3 queries bulk + procesamiento en memoria.

### Archivos afectados
- `lib/features/butcher/data/butcher_stock_service.dart` — Reescrito `getSectionRealData`

### Cambios realizados
1. **Antes**: 3 queries Firestore por cada sección (9 secciones = 27 reads secuenciales)
   - Query 1: buscar producto por nombre
   - Query 2: leer stock del producto
   - Query 3: fetch todas las ventas del día (¡idéntica en cada iteración!)
2. **Ahora**: 3 queries bulk + procesamiento en memoria
   - Query 1: fetch todos los productos activos → construir mapa nombre→producto
   - Query 2: collectionGroup('stockByStore') para la tienda → mapa productId→stock
   - Query 3: fetch ventas del día para la tienda (una vez) → filtrar en memoria por nombre
3. Reducción de 27 Firestore reads a 3 reads para 9 secciones
4. El resultado es idéntico: mismo `Map<String, ({double price, double stock, double sales})>`

### Validaciones realizadas
- flutter analyze ✅ (0 errores)
- flutter test ✅ (22/22)

---

## 2026-07-24

### Módulo trabajado
Fase 3.3 — CartProvider global

### Objetivo
Hacer CartProvider session-aware: limpiar carrito cuando cambia la tienda o empleado activo.

### Archivos afectados
- `lib/shared/providers/cart_provider.dart` — Ahora recibe `AppSessionNotifier` en constructor, escucha cambios de sesión y limpia carrito al cambiar de tienda
- `lib/core/di/service_locator.dart` — Eliminado `cartProvider` y `changeNotifierProviders` (ya no crea CartProvider)
- `lib/main.dart` — Crea `CartProvider` con dependencia de `AppSessionNotifier` en un nested `MultiProvider` después del padre

### Cambios realizados
1. CartProvider ahora depende de AppSessionNotifier (constructor con named parameter)
2. `_onSessionChanged()` detecta cambio de store y limpia carrito si tiene items
3. ServiceLocator ya no crea CartProvider — se crea en main.dart con contexto de sesión
4. Eliminado `changeNotifierProviders` de ServiceLocator (ya no es necesario)
5. Fix: `resolvedStore?.id` → `resolvedStore.id` (no nullable)

### Validaciones realizadas
- flutter analyze ✅ (0 errores)
- flutter test ✅ (22/22)

---

## 2026-07-24

### Módulo trabajado
Fase 3.2 — AppSessionNotifier

### Objetivo
Reemplazar `FutureBuilder<AppSession?>` en HomeScreen con un `ChangeNotifier` centralizado para gestionar sesión de negocio/empleado.

### Archivos afectados
- `lib/shared/providers/app_session_notifier.dart` — **NUEVO**: ChangeNotifier con `loadSession`, `refreshSession`, `selectStore`, `selectEmployee`, computed properties (`needsStoreSelection`, `needsPinEntry`, `employeesForStore`, `resolvedStore`, `resolvedEmployee`, `isCurrentEmployeeValid`)
- `lib/main.dart` — Registrado `AppSessionNotifier` como `ChangeNotifierProvider`
- `lib/features/home/ui/home_screen.dart` — Reescrito de `FutureBuilder<AppSession?>` a `Consumer<AppSessionNotifier>`. Eliminado estado local `_selectedStore`/`_activeEmployee`

### Cambios realizados
1. Creado `AppSessionNotifier` con toda la lógica de sesión (resolver store, employee, permisos)
2. Registrado en `main.dart` MultiProvider, se auto-carga sesión en init
3. Reescrito `HomeScreen` completo usando `Consumer<AppSessionNotifier>`
4. Eliminado imports innecesarios de modelos en HomeScreen

### Validaciones realizadas
- flutter analyze ✅ (0 errores)
- flutter test ✅ (22/22)
---

## 2026-07-25

### M�dulo trabajado
Fase 5.1 - Unit tests para repositorios

### Objetivo
Crear tests unitarios para todos los servicios/repositorios, cubriendo flujos online, offline y validaciones.

### Archivos creados (14 archivos de test)
- test/features/products/product_repository_test.dart - ProductService (16 tests)
- test/features/pos/category_repository_test.dart - CategoryService (8 tests)
- test/features/pos/discount_repository_test.dart - DiscountService (11 tests)
- test/features/pos/modifier_repository_test.dart - ModifierService (8 tests)
- test/features/pos/open_ticket_repository_test.dart - OpenTicketService (8 tests)
- test/features/employees/employee_repository_test.dart - EmployeeService (9 tests)
- test/features/business/business_repository_test.dart - BusinessService (9 tests)
- test/features/auth/auth_repository_test.dart - AuthService (15 tests)
- test/features/inventory/stock_repository_test.dart - StockService (8 tests)
- test/features/butcher/butcher_recipe_repository_test.dart - ButcherRecipeService (4 tests)
- test/features/butcher/butcher_receipt_repository_test.dart - ButcherReceiptService (5 tests)
- test/features/butcher/butcher_stock_repository_test.dart - ButcherStockService (7 tests)

### Archivos modificados (refactor para testabilidad)
- lib/features/pos/data/category_service.dart - DI constructor
- lib/features/pos/data/discount_service.dart - DI constructor
- lib/features/pos/data/modifier_service.dart - DI constructor
- lib/features/pos/data/open_ticket_service.dart - DI constructor
- lib/features/employees/data/employee_service.dart - DI constructor
- lib/features/business/data/business_service.dart - DI constructor
- lib/features/auth/data/auth_service.dart - DI constructor
- pubspec.yaml - Agregado mocktail: 1.0.4

### Cambios realizados
1. Creados 108 tests nuevos distribuidos en 14 archivos
2. Cada suite cubre: online, offline (sync queue), y validaciones
3. AuthService incluye mock de FirebaseAuth con mocktail
4. Agregada DI a 7 servicios que no la tenian

### Deuda tecnica
- ProductService.updateProduct: read-despues-de-write al cambiar REF en transaccion

### Validaciones realizadas
- flutter analyze OK (0 errores)
- flutter test OK (130/130)

---

## 2026-07-25 (Widget tests - Phase 5.2)

### Archivos creados
- test/presentation/screens/login_screen_test.dart - LoginScreen (8 tests)
- test/presentation/widgets/product_grid_test.dart - ProductGrid (10 tests)

### Archivos modificados
- lib/features/auth/ui/login_screen.dart - Constructor opcional authService para DI

### Tests agregados

**LoginScreen (8 widget tests):**
1. Muestra formulario de login por defecto
2. Alterna a modo registro
3. Muestra error cuando email y password estan vacios
4. Muestra error cuando nombre de empresa esta vacio en registro
5. Llama a signIn al enviar formulario
6. Llama a signUp al enviar formulario de registro
7. Muestra mensaje de error desde signIn
8. Muestra indicador de carga mientras se envia

**ProductGrid (10 widget tests):**
1. Muestra indicador de carga inicialmente
2. Muestra estado vacio cuando no hay productos
3. Muestra productos en grilla
4. Muestra cantidad de stock para productos con tracking
5. Filtra por busqueda
6. Filtra por categoria
7. Llama a onTap al tocar producto
8. Muestra estado de error en stream error
9. Muestra stock desde StockRepository
10. Oculta stock para productos sin tracking

### Cambios realizados
1. Refactorizado LoginScreen para aceptar AuthService opcional via constructor
2. Creado helper de testing `emitData` para manejo correcto de StreamBuilders anidados
3. Patron de testing con broadcast StreamControllers y Provider

### Deuda tecnica
- ProductsScreen y PosScreen requieren GoRouter y 4-5 providers cada una
- _buildCartPanel es privado en PosScreen (no testable como widget separado)

### Validaciones realizadas
- flutter analyze OK
- flutter test OK (148/148)

---

## 2026-07-25 (Cleanup - Phase 6)

### Archivos modificados
- lib/features/auth/ui/login_screen.dart - Fixed @override superfluo
- lib/features/home/ui/home_screen.dart - Removed unused `session` variable
- lib/features/butcher/domain/butcher_repository.dart - Removed unused import
- lib/features/products/domain/product_repository.dart - Removed unused import (dart:typed_data)
- lib/features/products/ui/products_screen.dart - Removed unused import (add_product_screen)
- lib/features/sales/ui/receipts_screen.dart - Removed unused imports and variables
- lib/features/sales/data/sale_creator_service.dart - Removed unnecessary cast
- lib/features/pos/ui/pos_screen.dart - Removed redundant _QuantityFormat extension; removed unused ticketId
- test/features/business/business_repository_test.dart - Removed unused import
- test/features/butcher/butcher_stock_repository_test.dart - Removed unused import
- test/features/employees/employee_repository_test.dart - Removed unused import
- test/features/inventory/stock_repository_test.dart - Removed unused import (dart:async)
- test/features/pos/category_repository_test.dart - Removed unused import
- test/features/pos/discount_repository_test.dart - Removed unused import
- test/features/pos/modifier_repository_test.dart - Removed unused import
- test/features/pos/open_ticket_repository_test.dart - Removed unused import
- test/sale_service_test.dart - Removed unused import

### Cambios realizados
1. Eliminados imports no utilizados (6.2)
2. Eliminadas variables locales no utilizadas
3. Eliminado cast innecesario
4. Eliminada extension redundante _QuantityFormat (formattedQuantity ya existe en CartItem)
5. flutter analyze: 0 warnings, 0 errors (6.3)
6. flutter test: 148/148 all pass (6.4)

### Deuda tecnica
- 73 issues info-level restantes (65 annotate_overrides, 4 prefer_initializing_formals, 2 avoid_types_as_parameter_names, 1 unnecessary_string_interpolations, 1 use_build_context_synchronously)

### Validaciones realizadas
- flutter analyze OK (0 warnings, 0 errors)
- flutter test OK (148/148)

---

## 2026-07-25 (Integration tests - Phase 5.3)

### Objetivo
Agregar integration tests con Patrol para los flujos principales: POS, ventas, y sincronizacion offline.

### Archivos creados
- test_e2e/pos_flow_test.dart - Flujo POS: login, navegar, buscar producto, agregar al carrito, cobrar
- test_e2e/sale_flow_test.dart - Flujo venta: realizar venta y verificar en historial de recibos
- test_e2e/offline_sync_test.dart - Flujo offline: crear venta sin conexion y sincronizar

### Archivos modificados
- pubspec.yaml - Agregada dependencia patrol: 4.8.0
- lib/features/auth/ui/login_screen.dart - Agregados Keys: emailField, passwordField, submitButton
- lib/features/pos/ui/pos_screen.dart - Agregado Key: searchField

### Cambios realizados
1. Agregado patrol 4.8.0 como dev dependency
2. Creados 3 tests E2E con Patrol 4.x API (patrolTest, $ finder, pumpAndSettle)
3. Agregados Keys a widgets clave para selectores de Patrol
4. Credenciales E2E cargadas via String.fromEnvironment (E2E_EMAIL, E2E_PASSWORD)

### Deuda tecnica
- Los tests requieren dispositivo real/emulador con Firebase Auth y datos precargados
- Ejecutar con: `patrol test --target test_e2e/pos_flow_test.dart`
- No se ejecutan via `flutter test` (requieren patrol test runner)

### Validaciones realizadas
- flutter analyze OK (0 warnings, 0 errors)
- flutter test OK (148/148)
