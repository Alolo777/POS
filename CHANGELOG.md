# CHANGELOG

## [2026-07-14]

### Corregido: Limpiar stock de sucursal no limpiaba la caché local

**Archivos modificados:**
- `pos_flutter_firebase/lib/services/butcher_service.dart`
  - Se agregó import de `LocalDatabase`
  - `clearStoreStock()` ahora llama a `LocalDatabase.clearCachedStockForStore()` después de actualizar Firestore

- `pos_flutter_firebase/lib/offline/local_database.dart`
  - Se agregó el método `clearCachedStockForStore(businessId, storeId)` que pone a 0 el `stockQuantity` y `lowStockAlertQuantity` en la caché de Hive para todos los productos de la sucursal indicada

**Problema:**
Al usar "Limpiar stock de sucursal" desde Ajustes, `ButcherService.clearStoreStock()` actualizaba correctamente Firestore (stock a 0), pero no actualizaba la caché local de Hive. `StockService.watchStockByStore()` primero emite los datos cacheados (con valores viejos), y su listener está en la colección `products` (no en `stockByStore`), por lo que los cambios en el subdocumento de stock no disparaban un refresco. Esto hacía que el stock siguiera viéndose con los valores anteriores.

**Solución:**
Después de limpiar el stock en Firestore, se actualiza también la caché local (`productStock` box en Hive) poniendo a 0 los valores de stock para la sucursal seleccionada. Así, cuando `watchStockByStore()` emite la caché, los valores ya están en 0.
