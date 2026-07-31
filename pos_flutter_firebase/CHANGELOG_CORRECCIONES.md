# Changelog de Correcciones

## 2026-07-25 - Bugfix: SnackBars y diálogos con texto invisible

### Problema
Al realizar acciones (cobrar, guardar, eliminar), los SnackBars y AlertDialog se veían como ventanas blancas sin texto visible.

### Causa raíz
- `SnackBarThemeData` en ambos temas no tenía `backgroundColor` definido, y `contentTextStyle` no especificaba `color`, por lo que el texto heredaba un color que se volvía invisible (blanco sobre blanco).
- `DialogThemeData` no tenía `contentTextStyle`, dejando el texto del contenido sin color explícito.

### Archivo modificado
- `lib/core/theme/glass_theme.dart`:
  - **Light theme**: `snackBarTheme.backgroundColor = darkBg`, `contentTextStyle.color = white`. `dialogTheme.contentTextStyle` con color explícito.
  - **Dark theme**: misma corrección.

## 2026-07-25 - Bugfix: Botón de regresar (back) sale de la app sin confirmación

### Problema
Al presionar el botón de regreso en Android estando en la pantalla principal, la app se cerraba inmediatamente sin navegar hacia atrás ni preguntar.

### Causa raíz
`_ShellWrapper` en `app_router.dart` era un widget vacío sin `PopScope`. GoRouter no tenía rutas previas en el shell que popear, por lo que el back button cerraba la app directamente.

### Archivo modificado
- `lib/core/router/app_router.dart`: `_ShellWrapper` ahora usa `PopScope` con `canPop: false`. Al presionar back muestra un diálogo de confirmación "¿Salir de la aplicación?" con opciones Cancelar/Salir.

## 2026-07-25 - Bugfix: Pantalla de Pollería se queda cargando (PERMISSION_DENIED)

### Problema
Al navegar a la opción de Pollería desde el menú, la pantalla se quedaba cargando infinitamente. El error en log era: `[cloud_firestore/permission-denied] Missing or insufficient permissions.`

### Causa raíz
La app intentaba leer `businesses/{businessId}/config/poultry` pero no existían reglas de Firestore para la subcolección `config` dentro de `businesses`. Tampoco existían reglas para `poultryReceivings`.

### Archivos modificados

#### 1. `lib/features/poultry/ui/receive_chicken_screen.dart`
- Agregado manejo de error en `_loadConfig()` con `try/catch`.
- Nuevos estados: `_loadError` y `_loadErrorMessage`.
- UI de error con ícono, mensaje y botón **Reintentar**.

#### 2. `lib/features/poultry/ui/poultry_config_screen.dart`
- Misma correción: error handling, estado `_loadError` y botón Reintentar.

### Reglas de Firestore agregadas (dentro de `match /businesses/{businessId}`)
```javascript
match /config/{configId} {
  allow read: if canReadBusiness(businessId);
  allow write: if canManageCatalog(businessId);
}
match /poultryReceivings/{receiptId} {
  allow read: if canReadBusiness(businessId);
  allow create: if canSell(businessId) && hasBusinessId(businessId);
}
```

### Notas
- Sin estas reglas, cualquier intento de leer o guardar configuración de pollería falla silenciosamente.

## 2026-07-25 - Bugfix: Error de compilación TransferItem no encontrado

### Problema
Error de compilación: `Type 'TransferItem' not found` en `transfer_repository.dart`.

### Causa raíz
Faltaba el import del archivo `transfer_item.dart` en el repositorio de transferencias.

### Archivo modificado
- `lib/features/transfers/domain/transfer_repository.dart` — agregado `import 'transfer_item.dart'`.

## 2026-07-25 - Bugfix: Pantalla negra tras guardar recepción de pollo

### Problema
Después de guardar una recepción de pollo, la pantalla se volvía completamente negra sin posibilidad de recuperación.

### Causa raíz
`ReceiveChickenScreen` es una pantalla **embebida** dentro de `HomeScreen._buildSelectedPage()`, no una ruta independiente. Al finalizar el guardado, el código llamaba `Navigator.of(context).pop()`, lo que destruía la ruta shell de GoRouter en lugar de solo limpiar el formulario.

Adicionalmente, `_ShellWrapper` (el builder del ShellRoute) no definía color de fondo, por lo que cualquier error/transición dejaba la pantalla negra.

### Archivos modificados
- `lib/features/poultry/ui/receive_chicken_screen.dart`:
  - Reemplazar `Navigator.pop()` por `_resetForm()` (limpia controllers, resetea valores, setState).
  - `_resetForm()` ahora hace `dispose()` de los `TextEditingController` huérfanos antes de limpiar la lista.
  - `_calculate()` ahora hace `dispose()` de los controllers viejos antes de crear nuevos.
- `lib/core/router/app_router.dart`:
  - `_ShellWrapper` ahora envuelve child en `Container(color: scaffoldBackgroundColor)`.
  - Eliminado `PopScope` que causaba `_debugLocked` al intentar hacer pop desde una ruta shell.

## 2026-07-25 - Bugfix: PoultryConfigScreen con navegación incorrecta y sin try-catch

### Problema
1. Al tocar "Pollería" en Settings, la navegación a `PoultryConfigScreen` se hacía dentro del shell de GoRouter, y al volver podía causar pantalla negra.
2. Si `saveConfig()` fallaba (Firestore rules), la excepción no se manejaba y colgaba el árbol de widgets.

### Archivos modificados
- `lib/features/settings/ui/settings_screen.dart`:
  - Cambiar `Navigator.of(context).push(...)` por `Navigator.of(context, rootNavigator: true).push(...)`.
- `lib/features/poultry/ui/poultry_config_screen.dart`:
  - Agregar `try/catch/finally` en `_save()`.
  - Agregar estado `_saving` con botón deshabilitado + spinner mientras guarda.
  - SnackBar de error en caso de fallo.

## 2026-07-25 - Bugfix: Pantalla negra por error global no capturado

### Problema
Errores fuera del build (por ejemplo, en streams o callbacks asíncronos) no se capturaban, dejando la app en un estado inconsistente sin retroalimentación visible.

### Archivo modificado
- `lib/main.dart`:
  - Agregar `FlutterError.onError` que loguea el error con `debugPrint`.
  - Envolver `runApp` en `runZonedGuarded` para capturar cualquier error no manejado.
  - `ErrorWidget.builder` ya estaba configurado para errores en build.

## 2026-07-25 - Bugfix: Productos de pollería no se creaban automáticamente

### Problema
Al guardar una recepción de pollo, los productos (Pechuga, Maciza, etc.) no se creaban en el catálogo. El stock nunca se actualizaba porque `saveReceiving()` solo operaba sobre secciones con `productId`, y los cortes de configuración no tenían IDs de producto asignados.

### Causa raíz
`PoultryService.saveReceiving()` dentro de la transacción solo actualizaba stock si `section.productId != null`, pero los cortes configurados tenían `productId = null` (nunca se vinculaban a productos existentes).

### Archivo modificado
- `lib/features/poultry/data/poultry_service.dart`:
  - Antes de la transacción, `_resolveProductId()` busca un producto por nombre de sección.
  - Si no existe, lo crea con REF tipo `PO{timestamp}`, `sellBy: weight`, precio 0, stock 0.
  - El `productId` resuelto se usa en la transacción para actualizar stock.
  - Esto evita que el usuario tenga que vincular manualmente cada sección a un producto.

### Artefacto creado
Cada sección se crea como producto independiente:
```text
Producto: Pechuga (sellBy: weight, ref: PO12345678, trackStock: true, stock inicial: 0)
Producto: Maciza  (sellBy: weight, ref: PO12345679, trackStock: true, stock inicial: 0)
...
```

## 2026-07-25 - Bugfix: Firestore rules faltantes para config y poultryReceivings

### Problema
Las reglas de Firestore no tenían `match` para las subcolecciones `config` y `poultryReceivings`, causando `PERMISSION_DENIED` en todas las operaciones de pollería.

### Archivo modificado
- `firestore.rules`: agregar dentro de `match /businesses/{businessId}`:
```javascript
match /config/{docId} {
  allow read: if canReadBusiness(businessId);
  allow create, update: if canManageCatalog(businessId);
}
match /poultryReceivings/{receivingId} {
  allow read: if canReadBusiness(businessId);
  allow create: if canManageCatalog(businessId)
    && hasBusinessId(businessId);
}
```

## 2026-07-25 - Bugfix: Error de tipo num vs double en mermaPercent

### Problema
Error de compilación: `The argument type 'num' can't be assigned to the parameter type 'double'` en `receive_chicken_screen.dart:157`.

### Causa raíz
La expresión ternaria `... ? ... : 0` retorna `num`, pero `ChickenReceiving.mermaPercent` espera `double`.

### Archivo modificado
- `lib/features/poultry/ui/receive_chicken_screen.dart` — cambiado `0` a `0.0`.

## 2026-07-14 - Bugfix: Stock no se actualiza en tiempo real después de limpiar/asignar

### Problema
Cuando se usaba **Settings > Limpiar stock de sucursal** y luego se asignaba pollo (destazado) al inventario, el stock seguía apareciendo como si no se hubiera limpiado.

### Causa raíz
`StockService.watchStockByStore()` (`lib/services/stock_service.dart:13`) escuchaba cambios en la colección `products` de Firestore. Pero cuando se limpia o ajusta el stock, solo cambian los documentos de la subcolección `stockByStore/{storeId}`, NO los documentos de `products`. Por lo tanto, el listener nunca se disparaba y la UI no reflejaba los cambios.

Además, el caché local (Hive) se emitía SIN filtrar por `storeId`, lo que causaba que se mostrara stock de otras sucursales.

### Archivos modificados

#### 1. `lib/services/stock_service.dart`
- **`watchStockByStore()`**: Cambiado el listener de `products` a `collectionGroup('stockByStore')` con filtro por `storeId`. Ahora detecta cualquier cambio en los documentos de stock (limpiar, ajustar, vender, devolver) en tiempo real.
- **`watchStockByStore()`**: El caché emitido al inicio ahora se filtra por `storeId` para evitar mostrar stock incorrecto de otras sucursales.

#### 2. `lib/services/butcher_service.dart`
- **`clearStoreStock()`**: Optimizado para usar `WriteBatch` en lugar de `await` individuales por producto. Esto hace la operación atómica (todo o nada) y más rápida.

### Notas
- El `collectionGroup('stockByStore')` requiere un índice compuesto en Firestore. Firebase lo creará automáticamente o mostrará un enlace en la consola para crearlo.
- Los consumidores de `watchStockByStore()` (`ProductGrid`, `ProductsScreen`, `InventoryTab`) no requieren cambios porque su interfaz no cambió.

## 2026-07-26 - Bugfix: Error "Cannot have read after write in a transaction" al recibir pollos

### Problema
Al guardar una recepción de pollos aparecía: `FirebaseException: Cannot have a read after a write in a transaction.` En el recibimiento se ejecutaba `transaction.get(sectionRef)` después de `transaction.set(receivingRef)`, lo que viola la regla de Firestore de que en una transacción no puede haber lecturas después de escrituras.

### Causa raíz
`PoultryService.saveReceiving()` usaba `runTransaction` con el siguiente orden: primero `transaction.set(...)` para crear el recibo, y luego `transaction.get(...)` para cada sección. Firestore no permite lecturas después de escrituras dentro de una misma transacción.

### Archivo modificado
- `lib/features/poultry/data/poultry_service.dart`:
  - Reemplazar `runTransaction` por `WriteBatch`.
  - Las lecturas de stock se hacen **antes** del batch con `get()` independientes.
  - El batch solo contiene escrituras: `set` del recibo y `update` + `FieldValue.increment` para el stock de cada sección/producto.

## 2026-07-26 - Bugfix: Zone mismatch en runZonedGuarded (main.dart)

### Problema
Error en tiempo de ejecución: `Zone mismatch: The current zone is not the zone in which the widget binding was initialized.` Ocurría porque `WidgetsFlutterBinding.ensureInitialized()` se llamaba **fuera** del `runZonedGuarded`, creando el binding en una zona diferente a la que ejecutaba `runApp`.

### Causa raíz
- `WidgetsFlutterBinding.ensureInitialized()` estaba antes del `runZonedGuarded`, por lo que el binding se creaba en la zona principal (main zone).
- `runApp()` se ejecutaba dentro del `runZonedGuarded`, que crea una subzona.
- Cualquier callback o microtask que necesitara el binding desde dentro de `runZonedGuarded` fallaba porque la zona no coincidía.

### Archivo modificado
- `lib/main.dart`: Mover `WidgetsFlutterBinding.ensureInitialized()` **dentro** del `runZonedGuarded`, antes de `runApp()`.

## 2026-07-26 - Bugfix: Error en PosScreen.dispose() por context.read<>() después de deactivation

### Problema
Error: `Looking up a deactivated widget's ancestor is not supported.` Ocurría al cerrar la pantalla POS cuando `dispose()` intentaba acceder a providers mediante `context.read<>()`, pero el widget ya estaba desactivado (deactivated) y no tenía contexto de ancestro.

### Causa raíz
`PosScreen.dispose()` usaba getters como `context.read<SaleCubit>()`, `context.read<CalculatorCubit>()` que requieren el árbol de widgets activo. Cuando se ejecuta `dispose()`, el widget ya fue desactivado y no se puede navegar el árbol.

### Archivo modificado
- `lib/features/pos/ui/pos_screen.dart`:
  - Los providers se asignan a variables `late final` en `initState()` (donde el contexto aún es válido).
  - `dispose()` ahora usa esas variables en lugar de `context.read<>()`.
  - Se asegura que las pantallas hijas (CobrarDialog, TicketPreviewScreen) también usen el provider inyectado.

## 2026-07-26 - Bugfix: PERMISSION_DENIED al vender por falta de businessId en inventoryMovements

### Problema
Al realizar una venta, la operación fallaba con `PERMISSION_DENIED` porque las reglas de Firestore para `inventoryMovements` requieren `hasBusinessId(businessId)`, pero los movimientos de inventario creados en `SaleCreatorService` no incluían el campo `businessId`.

### Causa raíz
`SaleCreatorService.doIncrementSale()` creaba `inventoryMovements` sin el campo `businessId`. Firestore rules rechazaban la escritura porque `hasBusinessId()` verificaba que el documento tuviera `request.resource.data.businessId == businessId`.

### Archivo modificado
- `lib/features/sales/data/sale_creator_service.dart:132` — al construir cada `inventoryMovement`, agregar `'businessId': businessId`.

## 2026-07-26 - Bugfix: Diálogo Cobrar con autofocus bloqueante

### Problema
Al abrir el diálogo "Cobrar" en POS, el teclado aparecía inmediatamente en el campo "Dinero recibido", bloqueando la visibilidad del total y los botones de acción. El usuario debía cerrar el teclado manualmente para ver la información completa.

### Causa raíz
El `TextField` de dinero recibido tenía `autofocus: true`, lo que forzaba el foco y el teclado al abrir el diálogo.

### Archivo modificado
- `lib/features/pos/ui/pos_screen.dart:1073` — cambiar `autofocus: true` a `autofocus: false`.

## 2026-07-26 - Bugfix: PERMISSION_DENIED al devolver (refund) por falta de businessId en inventoryMovements

### Problema
Al realizar una devolución, la operación fallaba con `PERMISSION_DENIED` por la misma razón que la venta: los `inventoryMovements` no incluían `businessId`.

### Causa raíz
`SaleRefundService.doRefund()` creaba movimientos de inventario sin `businessId`. Firestore rules rechazaban la escritura.

### Archivo modificado
- `lib/features/sales/data/sale_refund_service.dart`: al construir cada `inventoryMovement` en el refund, agregar `'businessId': businessId`.

## 2026-07-26 - Bugfix: PDF de ticket no se genera por pageFormat.height infinito

### Problema
Al intentar generar el PDF del ticket de venta, el método `PdfGenerator.generate()` (de `printing` package) lanzaba error o no generaba nada porque `PdfPageFormat.roll80` tiene `height` establecido a `double.infinity`. `MultiPage` requiere una altura finita para saber cuándo partir las páginas.

### Causa raíz
`PdfPageFormat.roll80` es una constante predefinida con `height: double.infinity`, diseñada para impresoras térmicas de rollo continuo. Sin embargo, `PdfGenerator.generate()` con `MultiPage` necesita una altura finita para calcular los saltos de página. Al ser infinito, el cálculo fallaba y no se generaba el PDF correctamente.

### Archivo modificado
- `lib/features/sales/data/pdf_service.dart:9`: Reemplazar `PdfPageFormat.roll80` por `PdfPageFormat(227, 2000)` (227mm de ancho = 80mm de rollo, 2000mm de alto = ~2 metros de ticket, suficiente para cualquier venta).

### Notas
- 227 unidades = ~80mm en puntos (1mm ≈ 2.83 puntos). `printing` usa puntos (1 punto = 1/72 pulgada).
- Si se requiere una altura dinámica, se podría calcular basado en la cantidad de items, pero 2000mm es más que suficiente para tickets estándar.
- `MultiPage` automáticamente genera páginas adicionales si el contenido excede la altura.

## 2026-07-26 - Bugfix: Ticket de devolución no visible en lista de ventas

### Problema
Al hacer una devolución parcial (devolver algunos productos de un ticket con varios), la venta original se marcaba como `partially_cancelled` pero el nuevo ticket de devolución no aparecía en la lista de ventas.

### Causa raíz
El documento de devolución se creaba sin el campo `clientCreatedAt`. Todos los queries de lista de ventas en `SaleQueryService` ordenan por `clientCreatedAt` y Firestore excluye los documentos que no tienen el campo usado en `orderBy`.

### Archivo modificado
- `lib/features/sales/data/sale_refund_service.dart`:
  - Agregado `'clientCreatedAt': FieldValue.serverTimestamp()` al mapa `refundData`.

## 2026-07-26 - Bugfix: transacción con lecturas después de escrituras en devolución (refund)

### Problema
Al devolver TODOS los productos de un ticket con múltiples items, fallaba con: `Failed assertion: line 47 pos 12: '_commands.isEmpty'` en `method_channel_transaction.dart`. En tickets de un solo item funcionaba bien.

### Causa raíz
`cancelSale()` usaba `runTransaction` mezclando lecturas (`txn.get`) y escrituras (`txn.set`) dentro del mismo loop. En la primera iteración se ejecutaban lecturas → escrituras. En la segunda iteración, el `txn.get()` encontraba `_commands` no vacío (por las escrituras de la iteración anterior) y lanzaba el assertion error, porque Firestore requiere que TODAS las lecturas se ejecuten antes que CUALQUIER escritura.

### Archivo modificado
- `lib/features/sales/data/sale_refund_service.dart`:
  - Separar la transacción en dos fases: primero todas las lecturas (`txn.get`) en un loop, guardando los resultados en `stockSnapshots`.
  - Luego todas las escrituras (`txn.set`/`txn.update`) en un segundo loop y las operaciones finales.

## 2026-07-26 - Bugfix: refundExists busca por folio como si fuera ID de documento

### Problema
Después de una devolución, el mensaje "No se encontró el ticket de devolución" aparecía siempre aunque la devolución se hubiera creado correctamente.

### Causa raíz
`refundExists()` usaba `_salesRef(businessId).doc(refundId)` donde `refundId` es el folio (`D-000001`), pero el documento se crea con ID autogenerado (`txn.set(_salesRef(businessId).doc(), refundData)`). La búsqueda por ID nunca encontraba el documento.

### Archivo modificado
- `lib/features/sales/data/sale_refund_service.dart`:
  - Cambiar `refundExists()` para usar `where('folio', isEqualTo: refundId).where('type', isEqualTo: 'refund')`.

## 2026-07-26 - Bugfix: Manejador offline de cancelSale inconsistente con el online

### Problema
Cuando una devolución se hacía sin conexión y luego se sincronizaba, el manejador offline (`_handleCancelSale`) tenía varias diferencias con el flujo online:
1. Siempre marcaba `isCancelled: true` e `isPartiallyCancelled: true` sin distinguir entre devolución total o parcial.
2. Guardaba `total: -refundTotal` (negativo) mientras el online guarda `total: refundSubtotal` (positivo).
3. No guardaba `status: 'refund'` en el documento de devolución.
4. No actualizaba `returnedQuantity` en los items de la venta original.
5. Usaba la ruta antigua de stock (`stores/{storeId}/stock/{productId}`) en lugar de la nueva (`products/{productId}/stockByStore/{storeId}`).

### Archivo modificado
- `lib/core/offline/sync_handlers.dart`:
  - Leer la venta original desde Firestore para determinar si es devolución total o parcial.
  - Actualizar `items` con `returnedQuantity` como el flujo online.
  - Usar `'status': newStatus` en lugar de `isCancelled`/`isPartiallyCancelled`.
  - Usar `'total': refundTotal` (positivo).
  - Agregar `'status': 'refund'` al documento de devolución.
  - Usar ruta `products/{productId}/stockByStore/{storeId}` para stock.

## 2026-07-26 - Bugfix: Editar empleado muestra el hash del PIN en lugar del PIN

### Problema
Al editar un empleado en Back Office > Empleados, el campo PIN mostraba una cadena larga de caracteres hexadecimales (el hash SHA-256) en lugar del PIN original. Al guardar sin cambiar el PIN, se aplicaba doble hash y el empleado ya no podía iniciar sesión.

### Causa raíz
`_EmployeeDialogState.initState()` cargaba `employee.pin` directamente en el `TextEditingController` del PIN. Pero `employee.pin` contiene el hash SHA-256 (ej: `a665a4592042...`), no el PIN original. Al guardar, `EmployeeService.updateEmployee()` volvía a aplicar `_hashedPin()` sobre el hash, creando un doble hash.

### Archivo modificado
- `lib/features/home/ui/back_office_screen.dart`:
  - `initState()`: Eliminar `_pinController.text = employee?.pin ?? ''` — el PIN no se pre-rellena al editar.
  - `_submit()`: Solo validar longitud del PIN si es un empleado nuevo. En edición, permitir PIN vacío (significa "no cambiar").
  - `_showEmployeeDialog()`: Si el PIN está vacío en edición, usar `employee.pin` (el hash existente).

## 2026-07-26 - Bugfix: Sin botón para cambiar de sucursal en la pantalla principal

### Problema
No había forma de cambiar de sucursal desde la pantalla principal de POS. La única manera era entrar al panel de PIN (empleado) y presionar "Cambiar sucursal", un flujo poco intuitivo.

### Causa raíz
`_buildMainScaffold()` en `home_screen.dart` solo tenía botones para "Cambiar empleado" y "Cerrar sesión". No había un botón de "Cambiar sucursal" accesible directamente.

### Archivo modificado
- `lib/features/home/ui/home_screen.dart`:
  - Agregar `IconButton` con icono `Icons.store` en el AppBar, visible solo cuando hay más de 1 sucursal.
  - Al presionarlo, llama a `sessionNotifier.clearStore()` que redirige al flujo de selección de sucursal.
  - Eliminados imports no usados.

## 2026-07-26 - Bugfix: Sin botón para cambiar sucursal en pantalla principal + info movida al nav

### Problema
No había forma visible de cambiar de sucursal desde la pantalla principal. La info de "sucursal · empleado" ocupaba espacio en la barra superior.

### Cambios
- `home_screen.dart`: Eliminado texto "store name · employee name" del AppBar.
- `home_screen.dart`: Agregada la info de sucursal/empleado en el NavigationRail (leading) y en el Drawer (header).
- `employee_pin_screen.dart`: Reemplazado el viejo botón "Cambiar sucursal" por un DropdownButton directamente en el AppBar que lista todas las sucursales y permite cambiar al instante.
- `home_screen.dart`: Actualizada la creación de `EmployeePinScreen` para pasar `stores` y el nuevo callback `onSelectStore`.

### Archivos modificados
- `lib/features/home/ui/home_screen.dart`
- `lib/features/employees/ui/employee_pin_screen.dart`

## 2026-07-14 - Bugfix: Stock pendiente de destazado aparece igual en todas las sucursales

### Problema
En **Back Office > Inventario**, el stock pendiente de destazado (pollos recibidos) se mostraba idéntico sin importar qué sucursal estuviera seleccionada. Además, al limpiar el inventario de una sucursal, el stock pendiente seguía apareciendo con kilogramos.

### Causa raíz
1. `ButcherService.getPendingStockBySection()` (`lib/services/butcher_service.dart:387`) no filtraba por `storeId` — devolvía el stock pendiente de TODAS las sucursales.
2. `_InventoryTabState._loadPendingStock()` (`lib/screens/back_office_screen.dart:174`) no pasaba el `selectedStoreId` al cargar el stock pendiente.
3. Al cambiar de sucursal en el dropdown, no se recargaba el stock pendiente (`didUpdateWidget` solo comparaba `businessId`).
4. `clearStoreStock()` solo limpiaba los documentos `stockByStore`, pero no las secciones pendientes de las entradas de destazado.

### Archivos modificados

#### 1. `lib/services/butcher_service.dart`
- **`getPendingStockBySection()`**: Agregado parámetro opcional `storeId`. Cuando se proporciona, filtra los recibos por `storeId` para que cada sucursal vea solo su propio stock pendiente.
- **`clearStoreStock()`**: Ahora también llama a `_consumePendingSectionsForStore()` para marcar como consumidas todas las secciones pendientes de las entradas de destazado de la sucursal que se está limpiando.
- **`_consumePendingSectionsForStore()`** (nuevo método): Busca recibos de destazado no cancelados de la sucursal en los últimos 7 días y agrega sus secciones pendientes a `consumedSections`, eliminándolas del stock pendiente.

#### 2. `lib/screens/back_office_screen.dart`
- **`_loadPendingStock()`**: Ahora pasa `widget.selectedStoreId` a `getPendingStockBySection()` para cargar solo el stock pendiente de la sucursal seleccionada.
- **`didUpdateWidget()`**: Ahora también recarga el stock pendiente cuando cambia `selectedStoreId`, no solo cuando cambia `businessId`.
