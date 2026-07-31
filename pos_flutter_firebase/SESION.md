# SESIÓN - POS Flutter Firebase

## Información del dispositivo
- Dispositivo: SM G970U (Android 12), ID: R58M515Y1TH
- Proyecto Firebase: `pos-flutter-firebase`
- Firestore rules desplegadas

---

## Archivos relevantes del proyecto

### Features implementados

#### 1. Poultry (Recepción de pollos)
| Archivo | Propósito |
|---------|-----------|
| `lib/features/poultry/domain/chicken_receiving.dart` | Modelo simplificado: solo `totalChickens`, `totalWeightKg`, `avgWeightKg` |
| `lib/features/poultry/domain/poultry_config.dart` | Config: secciones, tolerancia, `wholeProductId` |
| `lib/features/poultry/domain/poultry_section.dart` | Sección de corte (name, defaultPercent, productId) |
| `lib/features/poultry/domain/poultry_repository.dart` | Interfaz: `getConfig`, `saveConfig`, `saveReceiving`, `watchReceivings` |
| `lib/features/poultry/data/poultry_service.dart` | Implementación: auto-crea producto "Pollo Entero" + actualiza stock |
| `lib/features/poultry/ui/receive_chicken_screen.dart` | UI simplificada: solo cantidad + peso total |

#### 2. Butcher (Destazado)
| Archivo | Propósito |
|---------|-----------|
| `lib/features/butcher/domain/butcher_record.dart` | `ButcherRecord` + `ButcherSectionResult` (destazado con merma) |
| `lib/features/butcher/domain/butcher_receipt_repository.dart` | Interfaz extendida: `registerButchering`, `watchButcheringRecords`, `cancelButchering` |
| `lib/features/butcher/domain/butcher_recipe_repository.dart` | Interfaz receta (watch, get, save) |
| `lib/features/butcher/domain/butcher_stock_repository.dart` | Interfaz stock (assignPending, getPending, clearStore, getSectionRealData) |
| `lib/features/butcher/domain/butcher_repository.dart` | Interfaz combinada (hereda las 3 anteriores) |
| `lib/features/butcher/data/butcher_receipt_service.dart` | Implementación: `registerButchering` usa batch para deducir enteros + sumar partes + guardar merma |
| `lib/features/butcher/data/butcher_recipe_service.dart` | CRUD receta en `butcherRecipe/config` |
| `lib/features/butcher/data/butcher_stock_service.dart` | Stock de secciones (ahora usa `stockQuantity` unificado) |
| `lib/features/butcher/data/butcher_service.dart` | Fachada que delega a recipe, receipt y stock services |
| `lib/features/butcher/ui/butcher_screen.dart` | **NUEVA**: formulario de destazado con peso exacto, secciones editables, merma |
| `lib/features/butcher/ui/butcher_recipe_screen.dart` | Editor de receta + historial de entradas (legacy) |

#### 3. Transferencias (Envío/Recepción entre sucursales)
| Archivo | Propósito |
|---------|-----------|
| `lib/features/transfers/ui/send_transfer_screen.dart` | Enviar productos a otra sucursal |
| `lib/features/transfers/ui/receive_transfer_screen.dart` | Recibir productos de otra sucursal |
| `lib/features/transfers/data/transfer_service.dart` | Lógica de traspasos con validación de stock |

#### 4. Shared / Core
| Archivo | Propósito |
|---------|-----------|
| `lib/shared/models/product.dart` | Producto con `stockQuantity` (stock unificado) |
| `lib/shared/models/product_stock.dart` | Stock por sucursal, lee `stockQuantity` |
| `lib/shared/models/butcher_section.dart` | Sección de receta con porcentaje (decimal 0.3738 = 37.38%) |
| `lib/core/di/service_locator.dart` | DI con Provider: `ButcherRepository`, `PoultryRepository`, etc. |
| `lib/features/inventory/data/stock_service.dart` | Stream de stock por sucursal (`stockByStore` subcollection) |
| `lib/features/home/ui/home_screen.dart` | Menú principal con nav a todas las pantallas |

#### 5. Navegación
- `lib/features/home/ui/home_screen.dart` (línea ~236): items del menú
  - `poultry` → ReceiveChickenScreen (admin)
  - `butcher` → ButcherScreen (admin o permiso 'butcher')
  - `send_transfer` → SendTransferScreen
  - `receive_transfer` → ReceiveTransferScreen

### Firestore Rules
- `firestore.rules` (línea ~228): reglas para `butchering` collection

---

## Flujo actual del sistema Pollo/Destazado

### 1. Recibir pollos (`ReceiveChickenScreen`)
1. Admin ingresa cantidad de pollos recibidos + peso total en kg
2. `PoultryService.saveReceiving()`:
   - Busca/crea producto "Pollo Entero" (auto-guarda `wholeProductId` en config)
   - Guarda documento en `poultryReceivings`
   - Incrementa `stockByStore.stockQuantity` de "Pollo Entero"

### 2. Destazar pollos (`ButcherScreen`)
1. Muestra stock disponible de "Pollo Entero" (desde `StockService.watchStockByStore`)
2. Empleado ingresa:
   - Cuántos pollos destazó
   - Peso exacto de esos pollos (los pesa en báscula)
3. Sistema calcula peso esperado por sección según receta (`exactWeightKg × percentage`)
4. Empleado ajusta pesos reales obtenidos de cada sección (kg editables)
5. Al guardar, `ButcherReceiptService.registerButchering()` ejecuta batch:
   - Deduce `exactWeightKg` de `Pollo Entero.stockByStore.stockQuantity`
   - Suma `actualKg` a cada producto de sección (busca por nombre)
   - Guarda `ButcherRecord` en colección `butchering`
   - Merma = expected - actual (trackeada en el record)

### 3. Stock unificado
- **Todos** los servicios escriben en `stockQuantity` en la subcolección `stockByStore`
- `ButcherStockService` antes usaba `quantity`, ahora usa `stockQuantity`
- `PoultryService` usa `stockQuantity` (FieldValue.increment)
- `StockService` / `ProductStock.fromDoc` lee `stockQuantity` (fallback `stock`)

### 4. Receta de destazado
- Almacenada en `butcherRecipe/config` como `ButcherSection` list
- Porcentajes en decimal: 0.3738 = 37.38%
- Default: Pechuga 37.38%, Maciza 26.19%, Alas 8.10%, Patas 3.57%, Huacal 8.57%, Mollejas/Hígado 3.57%, Rabadilla 6.90%, Cabezas 1.90%, Merma 3.81%
- Configurable desde `ButcherRecipeScreen`

---

## Pendientes / Próximos pasos

### Funcionalidad actual
- [x] Recibir pollos (solo recepción → stock de Pollo Entero)
- [x] Destazar con peso exacto (descuenta enteros, suma partes, trackea merma)
- [x] Stock unificado con `stockQuantity`
- [x] Reglas de Firestore para colección `butchering`
- [x] Navegación con "Recibir Pollo" y "Destazar"

### Posibles mejoras futuras
- [ ] Historial de destazados con vistas de merma (reportes)
- [ ] Editar/cancelar destazados desde UI (backend ya soporta `cancelButchering`)
- [ ] Permitir destazar a empleados no-admin (permiso 'butcher' ya definido en nav)
- [ ] Migrar/limpiar datos legacy en `butcherReceipts` (colección antigua)
- [ ] Vincular `meatSection` en productos de sección automáticamente
- [ ] Reporte de merma diario/semanal por sucursal
- [ ] Sincronizar receta de destazado entre `PoultryConfig` (legacy) y `ButcherRecipeService` (nuevo)

---

## Notas técnicas

### Convenciones de código
- Provider para DI (no Riverpod/Bloc)
- `StockRepository` para leer stock, `ButcherRepository` para operaciones de carnicería
- `PoultryRepository` para operaciones de pollería (recibir)
- `ButcherSection.percentage` es **decimal** (0.3738 = 37.38%), se multiplica × peso para obtener kg
- `ButcherSectionResult.percentage` se almacena como **porcentaje entero** (37.38) para reportes
- Stock se guarda en subcolección `products/{id}/stockByStore/{storeId}`

### Firestore collections
- `businesses/{biz}/poultryReceivings/{id}` - recepciones de pollo
- `businesses/{biz}/butchering/{id}` - destazados (nuevo)
- `businesses/{biz}/butcherReceipts/{id}` - entradas legacy (chicken/parts)
- `businesses/{biz}/butcherRecipe/config` - receta de destazado
- `businesses/{biz}/config/poultry` - configuración de pollería (wholeProductId, sections)
- `businesses/{biz}/products/{id}/stockByStore/{storeId}` - stock por producto/sucursal

### Para compilar
```bash
cd pos_flutter_firebase
flutter pub get
dart analyze lib/
```
