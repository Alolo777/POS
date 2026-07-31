# Contexto completo del proyecto POS Flutter Firebase

Este documento existe para que otra IA, desarrollador o el mismo usuario pueda retomar el proyecto exactamente donde se quedo. Resume el objetivo, decisiones tecnicas, funcionalidades implementadas, errores corregidos, estructura actual y roadmap pendiente.

## Objetivo del proyecto

Se esta construyendo un sistema POS tipo Loyverse usando Flutter + Firebase, enfocado exclusivamente en Android para celular y tablet.

No se requiere soporte para iOS, Web, Windows ni macOS. Cualquier decision futura debe priorizar Android.

El objetivo final es crear un POS profesional para negocios pequenos/medianos con:

- Login con correo/contrasena para dueno.
- Negocios y sucursales.
- Empleados con roles y permisos.
- Productos, categorias, modificadores y descuentos.
- Punto de venta con carrito.
- Ventas con efectivo/tarjeta y otros metodos despues.
- Inventario por unidad y por peso/volumen.
- Recibos/tickets.
- Caja y turnos.
- Reportes.
- Clientes y lealtad.
- Restaurante, mesas y cocina/KDS en fases posteriores.
- Funcionamiento offline-first en una fase posterior.

El usuario es nuevo programando, por lo que el codigo debe mantenerse claro, modular y consistente.

## Reglas de arquitectura acordadas

- Proyecto modular usando carpetas como `models/`, `services/`, `screens/`, `widgets/`.
- No meter logica pesada de negocio directamente dentro de widgets si puede vivir en servicios/controladores.
- Los servicios usan `Stream` para datos en tiempo real y `Future` para acciones puntuales.
- Los modelos deben ser inmutables cuando sea practico.
- Firestore debe usar estructura jerarquica por negocio, no colecciones planas globales.
- No avanzar a otra fase grande del roadmap sin probar la actual.
- Android es la unica plataforma objetivo.
- Evitar soluciones que rompan arquitectura solo por funcionar rapido.
- Si hay ambiguedad importante, preguntar antes de decidir.

## Tecnologia actual

- Flutter stable.
- Dart.
- Firebase Core.
- Firebase Auth.
- Cloud Firestore.
- `image_picker` para elegir/tomar fotos.
- `image` para optimizar/comprimir imagenes localmente.
- `path_provider` para guardar imagenes locales privadas de la app.
- `connectivity_plus` para detectar conexion y mostrar mensajes claros cuando una accion requiere internet.

Dependencias importantes actuales en `pubspec.yaml`:

```yaml
firebase_core
firebase_auth
cloud_firestore
image_picker
connectivity_plus
image
path_provider
```

Firebase Storage fue removido porque el usuario quiere evitar servicios de pago. Las imagenes de productos se guardan localmente en el dispositivo Android.

## Estructura actual de Firestore

La app ya fue migrada desde colecciones planas `products` y `sales` hacia estructura jerarquica por negocio.

Estructura usada actualmente:

```text
users/{uid}
  businessId
  employeeId
  defaultStoreId
  email
  createdAt
  updatedAt

businesses/{businessId}
  name
  currency
  timezone
  active
  ownerUid
  createdAt
  updatedAt

businesses/{businessId}/stores/{storeId}
  businessId
  name
  address
  phone
  active
  createdAt
  updatedAt

businesses/{businessId}/employees/{employeeId}
  businessId
  authUid
  name
  email
  role
  storeIds
  permissions
  active
  createdAt
  updatedAt

businesses/{businessId}/categories/{categoryId}
  businessId
  name
  color
  active
  createdAt
  updatedAt

businesses/{businessId}/products/{productId}
  businessId
  name
  description
  sku
  barcode
  categoryId
  categoryName
  sellBy
  imageUrl
  localImagePath
  price
  cost
  ref
  trackStock
  stock
  stockQuantity
  lowStockAlert
  lowStockAlertQuantity
  presentationType
  presentationShape
  presentationColor
  active
  createdAt
  updatedAt

businesses/{businessId}/productRefs/{refId}
  productId
  ref
  createdAt

businesses/{businessId}/counters/products
  nextRefNumber
  updatedAt

businesses/{businessId}/sales/{saleId}
  businessId
  storeId
  employeeId
  createdByUid
  items
  subtotal
  discountTotal
  taxTotal
  total
  paymentMethod
  status
  createdAt
```

### Notas sobre colecciones viejas

Al inicio se usaban colecciones planas en la raiz:

```text
products
sales
```

Esas ya no las usa la app. No fueron borradas automaticamente para evitar perder pruebas previas.

## Reglas actuales recomendadas de Firestore

Estas reglas estan versionadas en `firestore.rules` y conectadas en `firebase.json`:

```js
rules_version = '2';

service cloud.firestore {
  match /databases/{database}/documents {
    function signedIn() {
      return request.auth != null;
    }

    function userDocPath() {
      return /databases/$(database)/documents/users/$(request.auth.uid);
    }

    function hasUserProfile() {
      return signedIn() && exists(userDocPath());
    }

    function userProfile() {
      return get(userDocPath());
    }

    function belongsToBusiness(businessId) {
      return hasUserProfile()
        && userProfile().data.businessId == businessId;
    }

    match /users/{userId} {
      allow read, create, update: if signedIn()
        && userId == request.auth.uid;
    }

    match /businesses/{businessId} {
      allow create: if signedIn()
        && request.resource.data.ownerUid == request.auth.uid;

      allow read, update: if signedIn()
        && (
          resource.data.ownerUid == request.auth.uid
          || belongsToBusiness(businessId)
        );

      match /stores/{storeId} {
        allow read, update: if belongsToBusiness(businessId);

        allow create: if signedIn()
          && request.resource.data.businessId == businessId;
      }

      match /employees/{employeeId} {
        allow read: if belongsToBusiness(businessId);

        allow create: if signedIn()
          && employeeId == request.auth.uid
          && request.resource.data.authUid == request.auth.uid
          && request.resource.data.businessId == businessId;

        allow update: if belongsToBusiness(businessId);
      }

      match /categories/{categoryId} {
        allow read, create, update: if belongsToBusiness(businessId);
      }

      match /products/{productId} {
        allow read, create, update: if belongsToBusiness(businessId);

        match /stockByStore/{storeId} {
          allow read, create, update: if belongsToBusiness(businessId);
        }
      }

      match /productRefs/{refId} {
        allow read, create: if belongsToBusiness(businessId);
      }

      match /counters/{counterId} {
        allow read, create, update: if belongsToBusiness(businessId);
      }

      match /sales/{saleId} {
        allow read, create, update: if belongsToBusiness(businessId);
      }

      match /inventoryMovements/{movementId} {
        allow read, create: if belongsToBusiness(businessId);
      }

      match /shifts/{shiftId} {
        allow read, create, update: if belongsToBusiness(businessId);
      }

      match /customers/{customerId} {
        allow read, create, update: if belongsToBusiness(businessId);
      }

      match /modifiers/{modifierId} {
        allow read, create, update: if belongsToBusiness(businessId);
      }

      match /discounts/{discountId} {
        allow read, create, update: if belongsToBusiness(businessId);
      }

      match /openTickets/{ticketId} {
        allow read, create, update: if belongsToBusiness(businessId);
      }
    }
  }
}
```

No se requieren reglas de Firebase Storage porque ya no se usa Firebase Storage.

## Flujo de autenticacion actual

Archivos relacionados:

- `lib/main.dart`
- `lib/services/auth_service.dart`
- `lib/services/app_context_service.dart`
- `lib/screens/login_screen.dart`
- `lib/screens/business_setup_screen.dart`
- `lib/screens/home_screen.dart`

### Registro

La pantalla de login permite registrarse con:

- Correo.
- Nombre de empresa.
- Contrasena.

Al registrarse se crea:

- Usuario en Firebase Auth.
- `businesses/{businessId}`.
- `businesses/{businessId}/stores/{storeId}` con nombre `Sucursal principal`.
- `businesses/{businessId}/employees/{uid}` con rol `owner`.
- `users/{uid}` como indice rapido de sesion.

### Login

Al iniciar sesion se consulta `users/{uid}` para encontrar el negocio, empleado y sucursal.

Si el usuario ya existia de pruebas anteriores y no tiene negocio, se muestra `BusinessSetupScreen`, donde puede crear la empresa.

### AuthGate

`AuthGate` en `main.dart` escucha `FirebaseAuth.instance.authStateChanges()`:

- Si hay usuario, abre `HomeScreen`.
- Si no hay usuario, abre `LoginScreen`.

## Pantalla principal actual

Archivo principal:

- `lib/screens/home_screen.dart`

La app tiene navegacion tipo POS con secciones:

- Punto de venta.
- Recibos.
- Productos.
- Configuraciones.
- Back Office.

En tablet/ancho grande usa `NavigationRail` lateral.

En pantalla pequena usa `Drawer`.

Si hay mas de una sucursal, aparece selector de sucursal en la barra superior.

## Punto de venta actual

Archivo principal:

- `lib/screens/pos_screen.dart`

Funcionalidades implementadas:

- Grid de productos.
- Buscador de productos.
- Carrito local.
- Agregar producto tocando tarjeta.
- Boton `Cobrar`.
- Dialogo de metodo de pago con `Efectivo` y `Tarjeta`.
- Menu de tres puntos con:
  - Borrar ticket actual.
  - Sincronizar recibos en linea, por ahora placeholder.
- Descuento de inventario al cobrar.
- Validacion de stock suficiente antes de vender.
- Si el producto no maneja inventario, se puede vender sin validar stock.

### Estado de cobro actual

La venta usa `SaleService.createSale()` con transaccion de Firestore.

Por ahora requiere internet, porque:

- Valida stock actual en Firestore.
- Descuenta inventario.
- Crea venta.

Cuando no hay conexion, se muestra mensaje de que la accion requiere internet por ahora y que en la fase offline-first se guardara localmente.

### Descuento de stock corregido

Se corrigio un error donde al vender varias unidades del mismo producto solo se descontaba una. Ahora descuenta la cantidad vendida:

```dart
FieldValue.increment(-item.quantity)
```

Tambien actualiza:

- `stock`.
- `stockQuantity`.

## Productos e Items

Archivo principal:

- `lib/screens/products_screen.dart`

El apartado `Productos` ahora tiene pestanas:

- Productos.
- Categorias.
- Modificadores.
- Descuentos.

El boton `+` solo aparece en la pestana `Productos`. Antes aparecia en todas las pestanas y se corrigio.

### Pestana Productos

Muestra lista de productos con:

- Imagen local o forma/color.
- Nombre.
- REF.
- Unidad o peso/volumen.
- Categoria si tiene.
- Stock si maneja inventario.
- Precio.

Si no hay productos, muestra mensaje indicando que ahi se pueden agregar.

### Pestana Categorias

Muestra categorias creadas con:

- Color.
- Nombre.

Las categorias se pueden crear por ahora desde el formulario de producto.

### Pestanas Modificadores y Descuentos

Son placeholders por ahora. Se agregaran en fases posteriores.

## Crear producto

Archivo principal:

- `lib/screens/add_product_screen.dart`

Campos actuales:

- Nombre obligatorio.
- Categoria opcional.
- Boton para crear categoria desde el mismo formulario.
- Se vende por:
  - Unidad.
  - Peso/volumen.
- Precio obligatorio.
- Coste opcional.
- REF obligatorio.
- Inventario activable.
- Inventario inicial.
- Inventario bajo.
- Presentacion en TPV:
  - Color y forma.
  - Imagen.

### REF automatico

`ProductService.getSuggestedRef()` consulta:

```text
businesses/{businessId}/counters/products
```

Y sugiere un REF tipo:

```text
000001
000002
000003
```

El usuario puede cambiarlo manualmente.

Para evitar duplicados se usa:

```text
businesses/{businessId}/productRefs/{REF}
```

La creacion de producto usa transaccion:

- Verifica que `productRefs/{REF}` no exista.
- Crea `productRefs/{REF}`.
- Actualiza contador si corresponde.
- Crea el producto.

### Categorias desde el formulario

Se corrigio un error que salia al cancelar/guardar categoria desde el dialogo:

```text
'package:flutter/src/widgets/framework.dart': Failed assertion: '_dependents.isEmpty'
```

La causa era manejar el `TextEditingController` del dialogo desde fuera del ciclo de vida correcto. Se reemplazo por un widget stateful interno `_AddCategoryDialog` que maneja su propio controller y lo libera correctamente.

Ahora al crear categoria:

- Se guarda en Firestore.
- Se selecciona para el producto actual.
- Aparece despues en el selector.
- Aparece en la pestana `Categorias`.

## Inventario actual

Se corrigio la diferencia entre productos por unidad y por peso/volumen.

Campos actuales:

- `sellBy`: `unit` o `weight`.
- `trackStock`: activa/desactiva inventario.
- `stock`: numero entero para compatibilidad y productos por unidad.
- `stockQuantity`: numero decimal para inventario real.
- `lowStockAlert`: entero para compatibilidad.
- `lowStockAlertQuantity`: decimal para alerta real.

### Producto por unidad

Debe usar cantidades enteras.

Ejemplo:

```text
Brasier
Se vende por: Unidad
Inventario: 50
Inventario bajo: 10
```

La app valida que si `sellBy == unit`, el inventario no tenga decimales.

### Producto por peso/volumen

Acepta decimales.

Ejemplo:

```text
Queso
Se vende por: Peso/volumen
Inventario: 12.50
Inventario bajo: 2.5
```

Nota importante: el POS todavia agrega productos de 1 en 1. En una fase posterior hay que permitir capturar cantidad decimal al agregar productos por peso/volumen.

## Imagenes de productos sin Firebase Storage

Firebase Storage fue eliminado porque el usuario quiere evitar pagar servicios.

Decision tomada:

- Las imagenes se guardan localmente en el dispositivo Android.
- Firestore solo guarda la ruta local en `localImagePath`.
- `imageUrl` queda en `null`.

Archivo principal:

- `lib/services/product_service.dart`

Proceso actual:

1. Usuario toma foto o elige imagen con `image_picker`.
2. Se lee como bytes.
3. Se decodifica con la libreria `image`.
4. Se corrige orientacion con `bakeOrientation`.
5. Se redimensiona a maximo `1200px` por lado.
6. Se convierte a JPG calidad `82`.
7. Se guarda en carpeta privada de la app usando `path_provider`.
8. Se guarda la ruta en Firestore como `localImagePath`.

Ruta local aproximada:

```text
{appDocumentsDirectory}/businesses/{businessId}/products/{productId}.jpg
```

Ventajas:

- No requiere Firebase Storage.
- No cuesta dinero.
- Funciona sin internet para mostrar imagenes ya guardadas.
- Es buena opcion para MVP en una sola tablet/celular.

Limitaciones:

- La imagen solo existe en el dispositivo donde se creo.
- Si se usa otro dispositivo, ese otro no tendra la imagen.
- Si se desinstala la app, Android borra las imagenes locales.
- Para multi-dispositivo real en el futuro se necesitara Storage u otra solucion de sincronizacion de archivos.

Widgets actualizados:

- `lib/widgets/product_presentation.dart`
- `lib/screens/pos_screen.dart`

Ambos leen `localImagePath` con `Image.file()`.

Si por compatibilidad existe `imageUrl`, todavia puede mostrar `Image.network()`, pero el flujo actual ya no crea URLs.

## Presentacion visual en TPV

El usuario pidio que el producto no se viera como recuadro blanco con linea de color, sino que toda la tarjeta use el color elegido.

Se corrigio:

- La tarjeta del TPV usa el color completo seleccionado.
- El texto tiene borde/linea blanca translucida para distinguirse.
- Los iconos/tarjetas son mas grandes.
- Si hay imagen local, ocupa toda la tarjeta.
- Si no hay imagen, usa color y forma.

Formas disponibles:

- Cuadrado.
- Circular.
- Hexagonal.

Colores disponibles:

- Gris.
- Rojo.
- Amarillo.
- Azul.
- Morado.
- Verde.
- Naranja.

## Servicios actuales

### AuthService

Archivo:

- `lib/services/auth_service.dart`

Responsabilidades:

- Login.
- Registro.
- Logout.
- Crear workspace inicial de dueno.
- Crear negocio, sucursal, empleado owner y documento `users/{uid}`.

### AppContextService

Archivo:

- `lib/services/app_context_service.dart`

Responsabilidades:

- Cargar sesion actual usando `users/{uid}`.
- Obtener negocio.
- Obtener empleado.
- Obtener sucursales activas.

### ProductService

Archivo:

- `lib/services/product_service.dart`

Responsabilidades:

- Stream de productos.
- Sugerir REF automatico.
- Crear producto.
- Validar REF unico con `productRefs`.
- Actualizar contador de REF.
- Optimizar y guardar imagen local.

### CategoryService

Archivo:

- `lib/services/category_service.dart`

Responsabilidades:

- Stream de categorias.
- Crear categoria.

### SaleService

Archivo:

- `lib/services/sale_service.dart`

Responsabilidades:

- Crear venta.
- Validar stock.
- Descontar stock.
- Guardar venta.

### ConnectivityService

Archivo:

- `lib/services/connectivity_service.dart`

Responsabilidades:

- Verificar si hay conexion.
- Mostrar error claro cuando una accion requiere internet por ahora.

Acciones que todavia requieren internet:

- Crear producto, porque usa transaccion Firestore para REF unico.
- Generar REF automatico.
- Cobrar venta, porque usa transaccion Firestore para inventario y venta.

## Offline-first: estado actual y decision

El usuario quiere que eventualmente todas las funciones importantes puedan operar sin internet.

Se explico que esto corresponde a la Fase K del roadmap:

```text
Fase K - Offline-first
Persistencia local con Hive/Isar para ventas y turnos.
Cola de sincronizacion con estados: sincronizado, pendiente, error, conflicto, reintentando.
Indicador visual de conexion y sincronizacion.
Resolucion de conflictos.
```

Decision tomada:

- No implementar offline-first completo todavia.
- Primero estabilizar productos, categorias, ventas, inventario y caja.
- Despues implementar offline-first correctamente.

Razon:

- Si se implementa demasiado pronto, habria que rehacerlo cada vez que cambie venta, inventario, caja o recibos.

Estado actual:

- Firestore puede cachear lecturas y algunas escrituras simples.
- Imagenes locales ya funcionan sin Storage y sin internet una vez guardadas.
- Ventas y productos todavia requieren internet por transacciones.
- Si no hay internet, se muestra mensaje claro.

## Errores importantes corregidos

### Error de usuario sin negocio

Problema:

Al entrar la app decia:

```text
No se encontro negocio o sucursal para este usuario
```

Causa:

El usuario fue creado antes del refactor multi-negocio.

Solucion:

- Agregar `BusinessSetupScreen`.
- Si no existe `users/{uid}`, pedir nombre de empresa y crear workspace.

### Boton + aparecia en todas las pestanas de Items

Problema:

El boton `+` aparecia en Productos, Categorias, Modificadores y Descuentos.

Solucion:

- `ProductsScreen` paso de stateless a stateful con `TabController`.
- El FAB solo aparece cuando `index == 0`.

### REF manual podia repetirse

Solucion:

- Crear `productRefs/{REF}` como candado.
- Usar transaccion al crear producto.

### Categoria no se guardaba o fallaba al cancelar

Solucion:

- Crear `_AddCategoryDialog` stateful con controller propio.

### Producto en TPV se veia mal

Solucion:

- Tarjeta usa color completo.
- Imagen llena tarjeta.
- Texto y separadores con blanco translucido.

### Stock solo descontaba una unidad

Solucion:

- Descontar `item.quantity`.
- Actualizar `stock` y `stockQuantity`.

### Firebase Storage requeria pago

Solucion:

- Remover `firebase_storage`.
- Guardar imagen local con `path_provider`.

### Error `[firebase_storage/object-not-found]`

Solucion final:

- Ya no se usa Firebase Storage.
- No deberia aparecer de nuevo.

## Archivos principales existentes

```text
lib/main.dart
lib/firebase_options.dart

lib/models/app_session.dart
lib/models/business.dart
lib/models/cart_item.dart
lib/models/category.dart
lib/models/employee.dart
lib/models/product.dart
lib/models/store.dart

lib/services/app_context_service.dart
lib/services/auth_service.dart
lib/services/category_service.dart
lib/services/connectivity_service.dart
lib/services/product_service.dart
lib/services/sale_service.dart

lib/screens/add_product_screen.dart
lib/screens/business_setup_screen.dart
lib/screens/home_screen.dart
lib/screens/login_screen.dart
lib/screens/placeholder_section_screen.dart
lib/screens/pos_screen.dart
lib/screens/products_screen.dart

lib/widgets/product_presentation.dart
```

## Comandos de verificacion usados

Siempre correr antes de dar por terminado un cambio:

```powershell
cd C:\Users\Alonso-Manuel\POS\pos_flutter_firebase
flutter analyze
flutter test
```

El ultimo estado antes de crear este documento fue:

```text
flutter analyze
No issues found!

flutter test
All tests passed!
```

## Como probar en Android

```powershell
cd C:\Users\Alonso-Manuel\POS\pos_flutter_firebase
flutter run
```

Flujo recomendado de prueba actual:

1. Iniciar sesion o registrarse.
2. Si pide empresa, crearla.
3. Ir a `Productos`.
4. Crear categoria desde formulario de producto.
5. Crear producto por unidad con inventario.
6. Crear producto por peso/volumen con inventario decimal.
7. Crear producto con imagen local.
8. Ver que aparezca en lista de productos.
9. Ir a `Punto de venta`.
10. Buscar producto.
11. Agregar varias veces al carrito.
12. Cobrar.
13. Revisar que el stock baje por la cantidad vendida.

## Roadmap pendiente recomendado

No saltarse fases grandes sin probar lo anterior.

## Actualizacion 2026-07-03: Catalogo y TPV ampliados

Se implemento el siguiente bloque de catalogo completo:

- Editar producto existente desde la lista de productos.
- Eliminar producto como desactivacion logica (`active: false`) sin borrar ventas historicas.
- CRUD de categorias desde la pestana `Categorias`.
- Al editar una categoria, se propaga `categoryName` a los productos que la usan.
- Al eliminar una categoria, se desactiva y se quita de los productos relacionados sin eliminar productos.
- TPV con filtro por categoria usando chips horizontales.
- Busqueda en TPV por nombre o REF.
- Productos por peso/volumen ahora piden cantidad decimal al agregarlos al carrito.
- El carrito usa cantidades `double` para soportar peso/volumen.
- La venta descuenta inventario decimal usando `stockQuantity`.
- Se reforzaron validaciones en servicios para no depender solo de la UI.

Notas tecnicas:

- `CartItem.quantity` cambio de `int` a `double`.
- `ProductService.updateProduct()` maneja cambio de REF con candado `productRefs/{REF}` en transaccion.
- `ProductService.deactivateProduct()` libera el REF y marca el producto como inactivo.
- `CategoryService.updateCategory()` y `deactivateCategory()` actualizan productos relacionados por lotes.

Flujo de prueba recomendado para este bloque:

1. Crear categoria desde `Productos > Categorias > +`.
2. Editar esa categoria y confirmar que cambia tambien en productos relacionados.
3. Crear producto por unidad con inventario entero.
4. Editar producto, cambiar precio, categoria, color/forma y REF.
5. Intentar usar un REF repetido y confirmar que se rechaza.
6. Eliminar/desactivar producto y confirmar que desaparece del catalogo y TPV.
7. Crear producto por peso/volumen con inventario decimal, por ejemplo `5.5`.
8. En TPV, tocar producto por peso/volumen e ingresar `0.250`.
9. Cobrar y verificar que el inventario baja decimalmente.
10. Usar filtro por categoria y busqueda por REF en TPV.

## Actualizacion 2026-07-03: Cobro y carrito mejorados

Se mejoro el flujo de cobro del TPV:

- El cobro con tarjeta confirma y guarda la venta como `paymentMethod: card`.
- El cobro en efectivo abre pantalla con `Dinero recibido` y `Cambio`.
- El campo de dinero recibido se llena por defecto con el total exacto.
- El campo de dinero recibido se puede editar manualmente.
- Se agregaron sugerencias de efectivo tomando como referencia billetes mexicanos: 20, 50, 100, 200, 500 y 1000.
- Si el dinero recibido no cubre el total, no permite cobrar.
- La venta guarda `cashReceived` y `changeDue` cuando aplica.
- Al tocar el titulo `Carrito`, aparece un desglose completo del ticket con productos, cantidades, subtotales, stock actual y total.

Flujo de prueba recomendado:

1. Agregar productos al carrito.
2. Tocar `Carrito` y revisar el desglose.
3. Cobrar con `Tarjeta` y confirmar que se guarda sin error.
4. Cobrar con `Efectivo` y verificar que el recibido inicia con el total exacto.
5. Probar sugerencias como 150, 200 o 500 segun el total.
6. Editar manualmente el recibido.
7. Intentar cobrar con monto menor al total y confirmar que se bloquea.
8. Cobrar efectivo y revisar el mensaje con el cambio.

### Correccion posterior del flujo de cobro

Se corrigieron dos errores detectados al probar:

- Error Firestore: `Transactions require all reads to be executed before all writes`.
- Causa: la transaccion de venta leia un producto, escribia stock y despues intentaba leer otro producto cuando el ticket tenia varios productos con inventario.
- Solucion: `SaleService.createSale()` ahora lee primero todos los documentos de productos con inventario y despues hace todas las escrituras de stock y venta.
- No fue un problema de reglas de Firebase.

Tambien se corrigio:

- Error Flutter: `_dependents.isEmpty` al usar botones sugeridos de efectivo.
- Causa: el `TextEditingController` del dialogo de efectivo vivia fuera del ciclo de vida normal del widget del dialogo.
- Solucion: se creo `_CashPaymentDialog` como `StatefulWidget`, con controller propio en `initState()` y `dispose()`.

### Ajuste UX de cobro

Se elimino el dialogo intermedio de metodo de pago. Ahora al presionar `Cobrar`:

- Abre directamente el dialogo de cobro con efectivo.
- Muestra total, dinero recibido, sugerencias de efectivo y cambio.
- En la parte inferior aparece tambien `Cobrar con tarjeta`.
- El boton principal queda como `Cobrar efectivo`.

## Actualizacion 2026-07-03: Recibos, cancelaciones, caja, descuentos y modificadores

Se agregaron funciones de POS mas completas:

- `Recibos` ahora muestra historial real de ventas por sucursal.
- Cada recibo muestra detalle de ticket: sucursal, fecha, metodo de pago, recibido, cambio, productos, cantidades, modificadores, descuentos, subtotal y total.
- Las ventas se pueden cancelar desde el detalle del recibo.
- Al cancelar, el usuario puede elegir si quiere regresar productos al inventario.
- La cancelacion no borra la venta; cambia `status` a `cancelled` y guarda motivo, fecha e indicador `inventoryReturned`.
- Se agrego caja/turnos obligatoria: si no hay caja abierta, el TPV bloquea venta y pide efectivo inicial.
- Desde el menu del TPV se puede cerrar caja.
- El cierre calcula ventas en efectivo, tarjeta, total, efectivo esperado y diferencia.
- Se agrego descuento basico al ticket completo desde el menu del TPV.
- Se agregaron modificadores basicos y descuento por producto tocando un item del carrito o el icono de ajustes.

Archivos agregados:

```text
lib/models/sale.dart
lib/models/shift.dart
lib/services/shift_service.dart
lib/screens/receipts_screen.dart
```

Archivos modificados:

```text
lib/models/cart_item.dart
lib/services/sale_service.dart
lib/screens/home_screen.dart
lib/screens/pos_screen.dart
```

Regla importante de Firestore:

Para cancelar ventas se necesita que `sales` permita `update`:

```js
match /sales/{saleId} {
  allow read, create, update: if belongsToBusiness(businessId);
}
```

Sin este cambio, crear ventas puede funcionar, pero cancelar ventas fallara por permisos.

## Actualizacion 2026-07-03: Devoluciones detalladas y apartado Turno

Se ajustaron las implementaciones anteriores:

- Cancelar una venta ahora se maneja como devolucion detallada.
- El usuario elige productos y cantidades a devolver.
- Se puede devolver todo el ticket o solo algunos productos.
- El ticket original cambia a:
  - `cancelled` si se devolvio completo.
  - `partially_cancelled` si solo se devolvieron algunos productos.
- Se crea un recibo separado de devolucion con folio propio (`status: refund`) y referencia `originalSaleId`.
- El recibo original conserva `returnedItems` para mostrar que productos se devolvieron.
- En lista de recibos:
  - Ticket pagado con tarjeta usa icono de tarjeta.
  - Ticket cancelado total se marca en rojo.
  - Ticket cancelado parcial se marca en naranja.
  - Devoluciones aparecen como recibos separados.
- La devolucion puede o no regresar inventario.

Se agrego apartado `Turno` en la navegacion principal:

- Informacion del turno.
- Numero de cierres de caja.
- Abierto por empleado.
- Fecha/hora de apertura.
- Cajon de efectivo:
  - Fondo de caja.
  - Cobros en efectivo.
  - Reembolsos en efectivo.
  - Depositos.
  - Pagos/Salidas.
  - Efectivo teorico en caja.
- Resumen de ventas:
  - Ventas brutas.
  - Reembolsos.
  - Descuentos.
  - Ventas netas.
- Tesoreria:
  - Deposito con cantidad y comentario.
  - Pago/Salida con cantidad y comentario.
- Cierre de turno:
  - Muestra efectivo teorico.
  - Campo editable de efectivo real con valor por defecto igual al teorico.
  - Muestra descuadre en verde si es positivo y rojo si es negativo.

Notas de datos:

- Los movimientos de tesoreria se guardan dentro del documento del turno en `cashMovements`.
- Los totales acumulados del turno usan `depositsTotal` y `payoutsTotal`.
- Los reembolsos en efectivo se calculan desde recibos con `status: refund` y `paymentMethod: cash`.

### Ajustes posteriores de TPV, dialogos y recibos

Se hicieron correcciones de estabilidad y UX:

- Se quitaron modificadores y descuentos desde productos del carrito en TPV.
- Se quito `Descuento al ticket` del menu del TPV.
- Se quito `Cerrar caja` del menu del TPV porque ahora vive en `Turno`.
- Se corrigieron dialogos para evitar el error Flutter `_dependents.isEmpty` al tocar fuera, cancelar o guardar.
- Los dialogos de `Deposito`, `Pagos/Salidas`, `Cerrar turno` y cantidad por peso/volumen ahora son `StatefulWidget` con controladores propios.
- La devolucion de recibos ahora usa botones `-`, `+` y `Todo`, no campos libres.
- Las cantidades de devolucion quedan limitadas al disponible real para devolver.
- Los recibos ahora se agrupan por dia.

### Ajuste posterior de devoluciones visibles y turno

Se reforzo el flujo de devoluciones:

- `watchSales()` ya no filtra por `storeId` directamente en Firestore; lee ventas del negocio y filtra en memoria para evitar que una devolucion quede invisible por datos pendientes.
- Las ventas y devoluciones guardan `clientCreatedAt` ademas de `createdAt` para que aparezcan inmediatamente aunque `serverTimestamp()` aun este pendiente.
- El resumen de turno ahora cuenta ventas originales y resta tickets `refund`.
- `Reembolsos en efectivo` se calcula desde tickets con `status: refund` y `paymentMethod: cash`.
- El efectivo teorico resta reembolsos en efectivo.
- El servicio valida que no se pueda devolver mas cantidad que la disponible, aunque la UI falle.
- Las devoluciones ahora se asignan al turno abierto actual del empleado si existe. Si no hay turno abierto, usan el turno original del ticket.
- `cancelSale()` devuelve el id/folio del ticket de devolucion creado para mostrar confirmacion visible.
- Si los reembolsos en efectivo superan el efectivo disponible del turno, `Turno` muestra un aviso rojo de faltante.
- Al cerrar turno se guarda `refundCashShortage` cuando el efectivo teorico queda negativo por devoluciones.

### Ajuste de diagnostico para tickets de devolucion

Se reforzo el documento de devolucion para que sea facil ubicarlo en Firebase:

- `status: refund`
- `type: refund`
- `refund: true`
- `folioType: refund`
- `originalSaleId: <ticket original>`
- `refundCreatedFrom: receipts_screen`

El ticket original guarda:

- `refundIds: [<ids de devoluciones>]`
- `lastRefundId`
- `returnedItems`

Despues de registrar una devolucion, la app lee directamente el documento creado. Si no existe, muestra un mensaje indicando que no encontro el ticket de devolucion.

### Correccion critica de contexto en devoluciones

Se corrigio una causa por la que la devolucion no se guardaba:

- El boton `Devolver productos` cerraba el dialogo de detalle del ticket.
- Despues intentaba abrir/usar la devolucion con el `BuildContext` del dialogo que acababa de cerrarse.
- Ese contexto quedaba desmontado y `_showReturnDialog()` regresaba antes de llamar a Firestore.
- Por eso no habia error visible, pero tampoco se creaba el documento `refund` ni se actualizaba el ticket original.

Solucion:

- `_showSaleDetails()` ahora conserva `screenContext` de la pantalla de Recibos.
- El dialogo usa `dialogContext` solo para cerrarse.
- La devolucion se abre y guarda usando `screenContext`.

## Actualizacion 2026-07-03: Folios reales y vista formal de ticket

Se implementaron folios consecutivos:

- Ventas usan folio `T-000001`, `T-000002`, etc.
- Devoluciones usan folio `D-000001`, `D-000002`, etc.
- Los contadores viven en `businesses/{businessId}/counters/sales`.
- Campos usados:
  - `nextSaleNumber`
  - `nextRefundNumber`

`SaleService.createSale()` ahora devuelve el folio creado para mostrar confirmacion en TPV.

`SaleService.cancelSale()` crea devoluciones con folio `D-...`.

Se agrego `TicketDetailScreen`:

- Muestra ticket formal con negocio, sucursal, folio, estado, fecha, pago, productos, subtotal, descuentos, total, recibido/cambio y productos devueltos.
- En `Recibos`, al abrir un ticket aparece opcion `Ver ticket`.
- Esta pantalla es una ruta normal, no un dialogo, para evitar problemas de `BuildContext` desmontado.

Nota de roadmap:

- Reportes, inventario avanzado y empleados/permisos se dejaran para un futuro apartado de administrador principal.

## Actualizacion 2026-07-03: Back Office administrador

Se implemento `BackOfficeScreen` como apartado real para administrador/dueno:

- Acceso permitido a empleados con rol `owner` o `admin`.
- Incluye filtro multi-sucursal: `Todas las sucursales` o una sucursal especifica.
- Pestaña `Reportes`:
  - Ventas brutas.
  - Ventas netas.
  - Efectivo.
  - Tarjeta.
  - Devoluciones.
  - Descuentos.
  - Productos mas vendidos.
- Pestaña `Inventario`:
  - Alertas de bajo stock.
  - Lista de productos con stock controlado.
  - Ajuste manual de inventario por sucursal seleccionada.
  - Historial de movimientos recientes.
- Pestaña `Empleados`:
  - Lista de empleados.
  - Crear empleado administrativo en Firestore.
  - Editar rol, sucursales, permisos y estado activo.

Archivos agregados:

```text
lib/screens/back_office_screen.dart
lib/services/employee_service.dart
lib/services/inventory_service.dart
```

Notas importantes:

- Crear empleados desde Back Office crea el documento en Firestore, no crea todavia usuario en Firebase Auth.
- Para que crear empleados arbitrarios funcione, las reglas de Firestore deberan permitir a owner/admin crear documentos en `employees`. Las reglas anteriores solo permitian crear el empleado dueño con `employeeId == request.auth.uid`.
- Reportes, inventario avanzado y empleados/permisos quedan concentrados en Back Office, no en TPV.

### Actualizacion de reportes Back Office

Se amplio la pestaña `Reportes`:

- Filtro de fechas por rango personalizado con calendario.
- Rangos rapidos:
  - Hoy.
  - Ayer.
  - Esta semana.
  - Semana pasada.
  - Este mes.
- Grafica simple de ventas por dia sin dependencias externas.
- Secciones:
  - Resumen de ventas.
  - Ventas por articulo.
  - Ventas por categoria.
  - Ventas por empleado.
  - Ventas por tipo de pago.
  - Recibos.

Notas:

- Los reportes respetan el filtro multi-sucursal del Back Office.
- Los items nuevos de venta ahora guardan `categoryId` y `categoryName` para reportes por categoria.
- Ventas viejas sin categoria apareceran como `Sin categoria`.

## Actualizacion 2026-07-03: Configuracion de negocio y sucursales

Se implemento la siguiente fase:

- `Configuraciones` ahora es pantalla real (`SettingsScreen`).
- Permite editar datos del negocio:
  - Nombre.
  - Moneda.
  - Zona horaria.
- Permite crear sucursales.
- Permite editar sucursales:
  - Nombre.
  - Direccion.
  - Telefono.
  - Activa/inactiva.
- Se agrego `BusinessService` para negocio y sucursales.
- `Store` ahora incluye `address` y `phone`.

Seleccion de sucursal al iniciar:

- Si el empleado tiene mas de una sucursal disponible, antes de entrar al POS debe seleccionar que sucursal va a abrir.
- Si solo tiene una sucursal, entra directo.
- `AppContextService` ahora filtra las sucursales disponibles segun `employee.storeIds`, excepto el dueño que puede ver todas.

Notas:

- Lo de configuracion de ticket se omitio por ahora por decision del usuario.
- Los dialogos nuevos son `StatefulWidget` con controladores propios para evitar errores de contexto/controladores al tocar fuera o cancelar.

### Ajuste posterior de sucursal fija y Back Office

Se ajusto el flujo de sucursales:

- La sucursal ya no se puede cambiar desde la barra superior del POS/app.
- La barra superior solo muestra el nombre de la sucursal seleccionada.
- El cambio de sucursal ocurre solo al iniciar sesion, en la pantalla de seleccion de sucursal.

Se ajusto Back Office:

- Reportes ahora inicia en `Este mes`, no solo `Hoy`, para evitar pantallas vacias si no hubo ventas hoy.
- Se agrego filtro rapido `Todo`.
- Se agregaron mensajes visibles cuando no hay ventas en el rango o sucursal seleccionada.
- Inventario y empleados muestran errores de Firestore si ocurren, en vez de quedar vacios.

## Actualizacion 2026-07-03: PIN interno de empleados

Se implemento acceso interno por PIN para empleados:

- El dueño/admin inicia sesion con Firebase Auth.
- Despues de seleccionar sucursal, aparece pantalla de acceso por empleado y PIN.
- El empleado activo se usa para POS, Recibos, Turno y Back Office.
- Empleados activos se cargan desde `businesses/{businessId}/employees`.
- Solo aparecen empleados activos asignados a la sucursal seleccionada.
- Dueños existentes sin PIN pueden entrar temporalmente con `0000`.
- Back Office > Empleados permite crear/editar PIN.

Permisos basicos por rol:

- Cajero: POS.
- Gerente: POS, Recibos, Productos, Turno.
- Admin/dueño: todo, incluyendo Configuraciones y Back Office.

Notas:

- El PIN se guarda como `pin` en el documento del empleado. Es suficiente para esta etapa local; mas adelante se puede migrar a hash.
- Si una sucursal no tiene empleados activos asignados, se muestra mensaje claro.

## Actualizacion 2026-07-03: Tickets abiertos / ventas suspendidas

Se implemento la fase de tickets abiertos:

- Nueva coleccion usada: `businesses/{businessId}/openTickets`.
- Nuevo modelo: `OpenTicket`.
- Nuevo servicio: `OpenTicketService`.
- En POS, menu de tres puntos ahora incluye:
  - `Suspender ticket`.
  - `Tickets abiertos`.
- Al suspender ticket se pide nombre:
  - Cliente Juan.
  - Mesa 1.
  - Pedido mostrador.
- El carrito se guarda como ticket abierto y se limpia.
- Se pueden recuperar tickets abiertos por sucursal.
- Al recuperar un ticket, el carrito actual se reemplaza con confirmacion si tenia productos.
- Al cobrar un ticket recuperado, el ticket abierto se marca como `closed`.
- Al borrar un ticket recuperado, el ticket abierto se marca como `cancelled`.

Notas:

- Por ahora los tickets abiertos requieren internet.
- El carrito recuperado reconstruye productos basicos desde los datos guardados del ticket.
- Las reglas actuales ya incluyen `openTickets` con read/create/update, por lo que no deberian requerir cambios.

## Actualizacion 2026-07-03: Inventario por sucursal

Se inicio migracion de stock global a stock por sucursal:

Nueva estructura:

```text
businesses/{businessId}/products/{productId}/stockByStore/{storeId}
  businessId
  storeId
  productId
  stock
  stockQuantity
  lowStockAlert
  lowStockAlertQuantity
  createdAt
  updatedAt
```

Cambios implementados:

- Nuevo modelo `ProductStock`.
- Nuevo servicio `StockService`.
- Crear producto ahora crea `stockByStore/{storeId}` para la sucursal actual.
- Editar producto actualiza el stock de la sucursal actual.
- POS lee stock de `stockByStore` para la sucursal seleccionada.
- Venta descuenta stock de `stockByStore/{storeId}`.
- Devolucion regresa stock a `stockByStore/{storeId}` del ticket original.
- Back Office > Inventario muestra y ajusta stock por sucursal cuando una sucursal esta seleccionada.
- Se mantiene actualizacion de `stockQuantity` en producto como compatibilidad temporal con productos viejos.
- Como el negocio ya tiene dos sucursales, se uso una herramienta temporal en Back Office > Inventario para dividir el stock global viejo entre sucursales activas en partes iguales.
- Esa herramienta temporal ya fue retirada despues de ejecutarse para evitar repetir la migracion por accidente.
- Despues de la migracion, si falta `stockByStore/{storeId}` para una sucursal, la app interpreta ese stock como `0`, no como el stock global viejo.
- Ventas, devoluciones y ajustes de inventario ya no incrementan/decrementan el stock global legacy del documento `products/{productId}`; trabajan sobre `stockByStore/{storeId}`.

Regla Firestore necesaria:

```js
match /products/{productId} {
  allow read, create, update: if belongsToBusiness(businessId);

  match /stockByStore/{storeId} {
    allow read, create, update: if belongsToBusiness(businessId);
  }
}
```

Sin esta regla, ventas/inventario por sucursal fallaran por permisos.

## Actualizacion 2026-07-04: Limpieza post-migracion de stock y catalogo de modificadores

Despues de dividir el inventario entre dos sucursales:

- Se retiro la herramienta temporal para dividir stock viejo entre sucursales.
- Se elimino el fallback activo al stock global legacy en POS, Productos e Inventario.
- Si una sucursal no tiene `stockByStore/{storeId}` para un producto, la app muestra stock `0` para esa sucursal.
- Ventas, devoluciones y ajustes ya no actualizan `products/{productId}.stockQuantity`; solo actualizan `products/{productId}/stockByStore/{storeId}`.
- El stock global en `products/{productId}` queda como campo legacy/historico y no debe usarse como fuente real.

Tambien se avanzo la siguiente fase de catalogo:

- Nuevo modelo `Modifier` en `lib/models/modifier.dart`.
- Nuevo servicio `ModifierService` en `lib/services/modifier_service.dart`.
- La pestana `Productos > Modificadores` ya no es placeholder.
- Se puede crear, editar y eliminar/desactivar modificadores.
- Cada modificador tiene nombre, precio extra y `active`.
- Firestore usa `businesses/{businessId}/modifiers/{modifierId}`.

Pendiente de modificadores:

- Conectar los modificadores configurados al dialogo del POS para seleccionarlos desde la lista real.
- Actualmente el carrito ya guarda `modifiers`, pero la configuracion nueva todavia no alimenta esa seleccion.

## Actualizacion 2026-07-04: Modificadores conectados al POS

Los modificadores configurados en Productos > Modificadores ahora se pueden seleccionar desde el POS:

- Se agrego `SelectedModifier` como modelo con id, nombre y precio.
- `CartItem.modifiers` cambio de `List<String>` a `List<SelectedModifier>`.
- `CartItem.subtotal` ahora incluye el precio de los modificadores multiplicado por cantidad.
- En el carrito del POS:
  - Cada producto se puede tocar para abrir el dialogo de modificadores.
  - El dialogo carga la lista real de modificadores desde Firestore.
  - Se puede marcar/desmarcar modificadores con checkbox.
  - Al aceptar, se actualiza el item del carrito con los modificadores seleccionados.
  - En el listado del carrito se muestra el nombre de los modificadores y su precio extra.
  - El subtotal del item se recalcula automaticamente incluyendo los extras.
- Los recibos y tickets muestran modificadores con precio (`Extra queso +$5.00`).
- Tickets abiertos guardan y restauran modificadores correctamente.
- Backward compatibility: modificadores guardados como strings viejos se siguen mostrando (sin precio).


### Siguiente trabajo recomendado inmediato

El bloque basico de Catalogo completo ya fue avanzado. Siguientes mejoras recomendadas:

1. Modificadores.
2. Descuentos.
3. Historial de ventas/recibos.
4. Caja/turnos.
5. Ajustes e historial de inventario.

### Despues

Inventario basico:

- Movimientos de inventario.
- Historial por producto.
- Alertas de bajo stock.
- Ajustes manuales.

Turnos/caja:

- Abrir caja.
- Cerrar caja.
- Registrar efectivo inicial.
- Totales por metodo de pago.

Recibos:

- Historial de ventas.
- Reimprimir ticket.
- Ticket simple en pantalla.

Offline-first completo:

- Elegir Hive o Isar.
- Guardar productos localmente.
- Guardar ventas pendientes localmente.
- Cola de sincronizacion.
- Resolver conflictos.
- Indicador de conexion/sync.

## Requerimientos completos de largo plazo

El sistema final debe aspirar a incluir:

- Roles: dueno/admin, gerente, cajero, mesero, cocina/KDS, contador/auditor.
- Permisos granulares.
- Multi-sucursal real.
- Productos avanzados con variantes.
- Modificadores.
- Descuentos.
- Impuestos.
- Clientes.
- Lealtad/puntos.
- Inventario avanzado.
- Proveedores.
- Turnos y caja.
- Tickets abiertos.
- Mesas/restaurante.
- Cocina/KDS.
- Reportes.
- Exportaciones.
- Recibos/tickets impresos o PDF.
- Offline-first completo.

## Notas para la siguiente IA

- No reintroducir Firebase Storage a menos que el usuario acepte costos o multi-dispositivo con imagenes sincronizadas.
- No volver a colecciones planas `products` y `sales`.
- Mantener todo bajo `businesses/{businessId}/...`.
- No implementar offline-first completo todavia salvo que el usuario lo pida explicitamente.
- Antes de cambiar ventas/inventario, considerar que `stockQuantity` es la fuente real de inventario.
- Productos por peso/volumen todavia necesitan UI para capturar cantidad decimal en el POS.
- Modificadores y descuentos son placeholders.
- El usuario valora explicaciones claras y pasos de prueba exactos.
- Siempre correr `flutter analyze` y `flutter test` despues de cambios.

## Actualizacion 2026-07-05: Catalogo de descuentos, descuento en POS y Cortes de Caja

Se completo el bloque de descuentos y reportes de caja:

### Catalogo de descuentos CRUD

- Nuevo modelo `Discount` en `lib/models/discount.dart` con `name`, `type` (percentage/fixed), `value` y `active`.
- Nuevo servicio `DiscountService` en `lib/services/discount_service.dart` con CRUD completo.
- La pestana `Productos > Descuentos` ya no es placeholder: lista descuentos activos, permite crear, editar y eliminar/desactivar.
- Filtros por tipo (porcentaje/fijo) y valor.

### Descuento por ticket en POS

- Nuevo menu item "Descuento ticket" en popup del POS.
- `_TicketDiscountDialog` en `lib/screens/pos_screen.dart`:
  - Carga descuentos configurados desde Firestore en vivo.
  - Muestra subtotal actual para referencia.
  - Descuentos porcentuales calculan el monto real sobre el subtotal.
  - Descuentos fijos no pueden superar el subtotal.
  - Si ya hay descuento aplicado, permite quitarlo.
- El descuento se guarda como `_ticketDiscount` (monto) y `_ticketDiscountName` (nombre).
- Se muestra en el carrito y resumen del ticket con el nombre del descuento.

### Descuento por item en POS

- `CartItem.discount` ya existia y se suma/reste en `subtotal`.
- `_ModifierSelectionDialog` ahora incluye seccion de descuentos debajo de los modificadores.
- Muestra descuentos del catalogo, calcula montos fijos/porcentuales sobre el precio base del item.
- Chip con monto y boton para quitar descuento.
- Se muestra descuento por item en la lista del carrito y en el desglose.

### Cortes de Caja en Back Office

- Nueva seccion `_cortesDeCajaCard` en `lib/screens/back_office_screen.dart`.
- Nuevo metodo `ShiftService.watchAllClosedShifts()` que filtra turnos con `status == 'closed'`.
- Respeta filtro de sucursal y rango de fechas de Reportes.
- Cada corte es tappable: muestra detalle completo con fondo inicial, ventas, reembolsos, depositos, salidas, efectivo esperado vs contado, y diferencia.
- Diferencia positiva en verde, negativa en rojo.

Archivos modificados:

```text
lib/models/cart_item.dart
lib/screens/pos_screen.dart
lib/screens/back_office_screen.dart
lib/services/shift_service.dart
```

Archivos agregados:

```text
lib/models/discount.dart
lib/services/discount_service.dart
```

Flujo de prueba recomendado:

1. Ir a `Productos > Descuentos` y crear un descuento fijo de $50.
2. Crear un descuento porcentual de 10%.
3. Ir al POS y agregar productos al carrito.
4. Usar menu > `Descuento ticket` y aplicar el descuento de 10%.
5. Verificar que el total se reduce correctamente y el nombre del descuento aparece.
6. Quitar el descuento desde el mismo dialogo.
7. Tocar un producto en el carrito para abrir personalizar.
8. En el dialogo, seleccionar el descuento fijo de $50.
9. Verificar que el subtotal del producto se reduce y aparece "Descuento: -$50.00".
10. Quitar el descuento del producto con la X en el chip.
11. Ir a Back Office > Reportes > seleccionar rango amplio.
12. Verificar que aparecen los cortes de caja con tienda, fechas y totales.
13. Tocar un corte para ver detalle completo y diferencia.

## Actualización 2026-07-25: Módulo de Pollería (Chicken Receiving + Config)

Se implementó un módulo completo para gestión de pollería:

### Estructura

```
lib/features/poultry/
  domain/
    poultry_repository.dart    # Interfaz abstracta
    poultry_config.dart        # Config: secciones de corte + tolerancia
    poultry_section.dart       # Sección individual (nombre, %, producto)
    chicken_receiving.dart     # Recepción de pollo (peso, merma, secciones)
  data/
    poultry_service.dart       # Implementación Firestore
  ui/
    poultry_config_screen.dart # Configurar cortes y tolerancia
    receive_chicken_screen.dart # Registrar recepción de pollo
```

### Firestore paths nuevos

```
businesses/{businessId}/config/poultry
  tolerancePercent    # double, ej: 5.0
  wholeProductId      # string opcional
  sections            # array de {id, name, defaultPercent, productId, sortOrder}

businesses/{businessId}/poultryReceivings/{receiptId}
  businessId, storeId, employeeId
  chickenCount, totalWeightKg
  butcheredCount, wholeCount
  butcheredWeightKg, wholeWeightKg
  sections            # array de {name, defaultPercent, expectedKg, actualKg, productId}
  sumActualKg, mermaKg, mermaPercent
  createdAt
```

### Reglas de Firestore requeridas

Dentro de `match /businesses/{businessId}`:

```javascript
match /config/{configId} {
  allow read: if canReadBusiness(businessId);
  allow write: if canManageCatalog(businessId);
}
match /poultryReceivings/{receiptId} {
  allow read: if canReadBusiness(businessId);
  allow create: if canManageCatalog(businessId) && hasBusinessId(businessId);
}
```

### Flujo de uso
1. Admin configura los cortes en Settings > Pollería (nombres y porcentajes predeterminados).
2. En navegación, el usuario recibe pollos y registra peso total, cantidad, peso real por sección.
3. El sistema calcula merma automáticamente, **crea productos automáticamente** para cada sección si no existen, y actualiza el stock de cada producto.

### Errores corregidos en el módulo de Pollería

1. **Pantalla negra tras guardar recepción**: 
   - `ReceiveChickenScreen` usaba `Navigator.pop()` al terminar, pero como es una pantalla embebida en `HomeScreen` (no una ruta empujada), esto destruía el shell de GoRouter y dejaba la pantalla en negro.
   - **Solución**: reemplazar `Navigator.pop()` por `_resetForm()` que limpia el formulario sin navegar.

2. **Pantalla negra al navegar a Config > Pollería**:
   - `PoultryConfigScreen` se navegaba desde `SettingsScreen` sin `rootNavigator: true`, quedando dentro del shell de GoRouter en vez de en el navigador raíz.
   - **Solución**: usar `Navigator.of(context, rootNavigator: true).push(...)`.

3. **Pantalla negra por falta de color de fondo en el shell**:
   - `_ShellWrapper` (GoRouter ShellRoute) no definía color de fondo, por lo que cualquier error/rebuild que no renderizara el hijo dejaba la pantalla en negro.
   - **Solución**: agregar `Container(color: scaffoldBackgroundColor)` en `_ShellWrapper`.

4. **_save() sin try-catch en PoultryConfigScreen**:
   - Si `saveConfig()` fallaba por reglas de Firestore, la excepción no se manejaba y colgaba el árbol de widgets.
   - **Solución**: agregar `try/catch/finally` con estado `_saving` y SnackBar de error.

5. **TextEditingControllers huérfanos en _resetForm()**:
   - `_resetForm()` limpiaba `_sectionCtrls` sin `dispose()` de los `TextEditingController`, dejando callbacks vivos que disparaban `setState()` innecesarios.
   - **Solución**: dispose de cada controller antes de limpiar la lista. También en `_calculate()`.

6. **Productos de pollería no se creaban automáticamente**:
   - `saveReceiving()` solo actualizaba stock de secciones con `productId` (casi siempre nulo porque el usuario no ingresaba IDs manuales).
   - **Solución**: `_resolveProductId()` que busca productos por nombre de sección. Si no existe, lo crea con REF tipo `PO{timestamp}`, `sellBy: 'weight'`, precio 0, stock inicial 0. El stock se suma en la transacción principal.

7. **Firestore rules faltantes para `config` y `poultryReceivings`**:
   - Las reglas no tenían `match` para estas subcolecciones, provocando `PERMISSION_DENIED` en todas las operaciones de pollería.
   - **Solución**: agregar reglas dentro de `match /businesses/{businessId}`.

8. **Sin captura global de errores**:
   - `FlutterError.onError` no estaba configurado. Errores fuera del build (async) no se mostraban.
   - **Solución**: agregar `FlutterError.onError` + `runZonedGuarded` en `main.dart` para capturar cualquier error no manejado y loguearlo con `debugPrint`.

### NOTA IMPORTANTE — Pruebas pendientes

Este módulo fue corregido pero NO se han probado todos los flujos de forma completa en dispositivo real. 
Antes de considerar el módulo estable, se debe ejecutar la checklist de funciones (ver más abajo).

---

## Actualizacion 2026-07-07: PDF tickets e historial de inventario

Se implementaron dos mejoras importantes:

### PDF de tickets (generacion y visualizacion)

- Nuevas dependencias: `pdf` y `printing` en `pubspec.yaml`.
- Nuevo servicio `PdfService` en `lib/services/pdf_service.dart`:
  - Genera PDF tamaño ticket (80mm) con encabezado (negocio, sucursal, direccion, telefono), informacion de venta, productos con cantidades/precios/modificadores/descuentos, subtotal/total, y productos devueltos si aplica.
  - Usa `pw.MultiPage` con formato rollo.
- Boton PDF en `ReceiptsScreen` (dialogo de detalle de venta) y en `TicketDetailScreen` (AppBar).
- Al tocar PDF se abre el visor del sistema (`Printing.layoutPdf`) que permite previsualizar, imprimir o guardar como archivo.

### Historial de movimientos de inventario

- Nuevo modelo `InventoryMovement` en `lib/models/inventory_movement.dart` con campos: `id`, `storeId`, `productId`, `productName`, `type` (sale/refund/adjustment), `previousQuantity`, `newQuantity`, `difference`, `reason`, `employeeId`, `createdAt`.
- `SaleService.createSale()` ahora registra movimiento por cada producto vendido (type: 'sale') dentro de la misma transaccion.
- `SaleService.cancelSale()` ahora registra movimiento por cada producto devuelto con restock (type: 'refund') dentro de la misma transaccion.
- `InventoryService.adjustStock()` ya registraba movimientos (type: 'adjustment').
- `InventoryService.watchMovements()` ahora devuelve `List<InventoryMovement>` tipado en vez de `List<Map<String, dynamic>>`.
- Back Office > Inventario > "Movimientos recientes" usa el modelo tipado.

Archivos agregados:
```text
lib/models/inventory_movement.dart
lib/services/pdf_service.dart
```

Archivos modificados:
```text
pubspec.yaml
lib/services/sale_service.dart
lib/services/inventory_service.dart
lib/screens/receipts_screen.dart
lib/screens/ticket_detail_screen.dart
lib/screens/back_office_screen.dart
```

Flujo de prueba:
1. Ir a POS y hacer una venta con productos con inventario.
2. Ir a Back Office > Inventario y verificar que aparece el movimiento de tipo "Venta".
3. Ir a Recibos, abrir la venta, tocar PDF y verificar que se genera correctamente con todos los datos.
4. Ir a TicketDetailScreen y usar el icono PDF en AppBar.
5. Cancelar/devolver la venta con regreso de inventario.
6. Verificar en Back Office > Inventario que aparece el movimiento de tipo "Devolucion".
7. Ajustar stock manualmente y verificar movimiento de tipo "Ajuste".

---

## Checklist de pruebas — Módulo de Pollería

### Configuración de cortes (PoultryConfigScreen)

| # | Función | Prueba | Estado |
|---|---------|--------|--------|
| 1.1 | Cargar configuración | Navegar a Settings > Pollería, debe mostrar secciones por defecto | ⬜ Pendiente |
| 1.2 | Guardar configuración | Modificar porcentajes y guardar, debe mostrar SnackBar de éxito | ⬜ Pendiente |
| 1.3 | Guardar con error | Desconectar internet y guardar, debe mostrar SnackBar de error | ⬜ Pendiente |
| 1.4 | Agregar sección | Tocar "+ Agregar", debe agregar una fila nueva en blanco | ⬜ Pendiente |
| 1.5 | Eliminar sección | Tocar ícono rojo de eliminar, debe quitar la sección | ⬜ Pendiente |
| 1.6 | Cambiar tolerancia | Editar el campo de tolerancia y guardar, debe persistir | ⬜ Pendiente |
| 1.7 | Volver atrás | Presionar back, debe regresar a Settings sin errores | ⬜ Pendiente |
| 1.8 | Persistencia al recargar | Guardar, volver, entrar de nuevo, deben aparecer los mismos datos | ⬜ Pendiente |

### Recepción de pollo (ReceiveChickenScreen)

| # | Función | Prueba | Estado |
|---|---------|--------|--------|
| 2.1 | Cargar pantalla | Navegar a Pollería desde menú principal, debe mostrar formulario vacío | ⬜ Pendiente |
| 2.2 | Sin configuración | Si no hay cortes configurados, debe mostrar mensaje "Configura los cortes en Configuración → Pollería" | ⬜ Pendiente |
| 2.3 | Error al cargar | Bloquear lectura de config, debe mostrar pantalla de error con Reintentar | ⬜ Pendiente |
| 2.4 | Calcular promedios | Ingresar cantidad y peso total, debe calcular peso promedio | ⬜ Pendiente |
| 2.5 | Calcular secciones | Ingresar pollos a destazar, debe mostrar las secciones con pesos esperados | ⬜ Pendiente |
| 2.6 | Editar peso real | Modificar el peso real de una sección, debe reflejarse en la merma | ⬜ Pendiente |
| 2.7 | Guardar recepción exitosa | Llenar formulario y guardar, debe mostrar SnackBar de éxito y limpiar el formulario | ⬜ Pendiente |
| 2.8 | Guardar con error | Desconectar internet (o bloquear escritura) y guardar, debe mostrar SnackBar de error | ⬜ Pendiente |
| 2.9 | Desviación > tolerancia | Ingresar un peso real con desviación mayor a la tolerancia, debe mostrar advertencia | ⬜ Pendiente |
| 2.10 | Desviación: cancelar | En la advertencia de desviación, tocar Cancelar, no debe guardar | ⬜ Pendiente |
| 2.11 | Desviación: continuar | En la advertencia de desviación, tocar Continuar, debe guardar | ⬜ Pendiente |
| 2.12 | Validación: cantidad 0 | Intentar guardar con cantidad 0, debe mostrar error | ⬜ Pendiente |
| 2.13 | Validación: peso 0 | Intentar guardar con peso 0, debe mostrar error | ⬜ Pendiente |
| 2.14 | Validación: destazados > total | Ingresar más pollos destazados que recibidos, debe mostrar error | ⬜ Pendiente |
| 2.15 | Botón de guardar deshabilitado | Durante el guardado, el botón debe mostrar spinner y estar deshabilitado | ⬜ Pendiente |

### Creación automática de productos

| # | Función | Prueba | Estado |
|---|---------|--------|--------|
| 3.1 | Producto creado automáticamente | Guardar recepción, ir a Productos y verificar que aparecen los productos creados (Pechuga, Maciza, etc.) | ⬜ Pendiente |
| 3.2 | Stock actualizado | Verificar que el stock de cada producto corresponde al peso real ingresado | ⬜ Pendiente |
| 3.3 | Producto existente reusado | Si el producto ya existe por nombre, no debe duplicarse; debe sumar stock al existente | ⬜ Pendiente |
| 3.4 | Productos con precio configurable | Ir a Productos, editar precio/coste de los productos creados por pollería | ⬜ Pendiente |

### Navegación y estabilidad

| # | Función | Prueba | Estado |
|---|---------|--------|--------|
| 4.1 | Volver de pollería a menú | Estando en pantalla de recepción, cambiar a otra sección del menú (ej. POS), debe funcionar sin error | ⬜ Pendiente |
| 4.2 | Múltiples guardados seguidos | Guardar recepción 3 veces seguidas sin recargar, el formulario debe limpiarse cada vez | ⬜ Pendiente |
| 4.3 | Rotación de pantalla | Rotar dispositivo en medio del formulario, los datos deben conservarse | ⬜ Pendiente |
| 4.4 | Sin pantalla negra | Después de guardar, la pantalla NO debe quedar negra | ⬜ Pendiente |
| 4.5 | Sin pantalla negra al navegar | Navegar entre Config > Pollería y Pollería > Recepción y volver, sin pantalla negra | ⬜ Pendiente |

### Funciones relacionadas (dependencias)

| # | Módulo | Relación | Estado |
|---|--------|----------|--------|
| 5.1 | Productos | Los productos de pollería deben aparecer en lista de productos con stock correcto | ⬜ Pendiente |
| 5.2 | POS | Los productos de pollería deben aparecer en el grid del POS para vender | ⬜ Pendiente |
| 5.3 | Stock por sucursal | El stock de pollería debe respetar la sucursal donde se registró la recepción | ⬜ Pendiente |
| 5.4 | Recibos | Las ventas de productos de pollería deben aparecer en Recibos | ⬜ Pendiente |
| 5.5 | Back Office > Inventario | El stock de pollería debe verse en Back Office con movimientos correctos | ⬜ Pendiente |
| 5.6 | Firestore rules | Las reglas deben permitir lectura/escritura de config y poultryReceivings | ⬜ Pendiente |
| 5.7 | Firestore rules | Las reglas deben permitir creación de productos por el servicio de pollería (canManageCatalog) | ⬜ Pendiente |
