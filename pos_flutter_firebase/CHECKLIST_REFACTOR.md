# Checklist de Refactorización

## Fase 0 — Seguridad

- [x] 0.1 PINs con hash
- [x] 0.2 Variables de entorno (flutter_dotenv)

## Fase 1 — Arquitectura

- [x] 1.1 Estructura de carpetas (core/data/domain/presentation)
- [x] 1.2 Sistema de DI (providers)
- [x] 1.3 Interfaces de repositorios
- [x] 1.4 Migrar servicios a repositorios

## Fase 2 — Refactor de Servicios

- [x] 2.1 Dividir ButcherService
- [x] 2.2 Dividir SaleService (use cases)
- [x] 2.3 Limpiar modelos (campos duplicados)
- [x] 2.4 Hive TypeAdapters

## Fase 3 — Navegación + Estado

- [x] 3.1 Migrar a GoRouter
- [x] 3.2 AppSessionNotifier
- [x] 3.3 CartProvider global

## Fase 4 — Firebase Performance

- [x] 4.1 Optimizar watchSales (filtro servidor)
- [x] 4.2 Optimizar watchStockByStore (sin StreamController manual)
- [x] 4.3 Agregar índices compuestos faltantes
- [x] 4.4 Optimizar ButcherService.getSectionRealData (N+1)

## Fase 5 — Testing

- [x] 5.1 Unit tests para repositorios
- [x] 5.2 Widget tests para screens principales (LoginScreen, ProductGrid)
- [ ] 5.2.1 ProductsScreen widget test (pendiente: requiere GoRouter + 5 providers)
- [ ] 5.2.2 PosScreen widget test (pendiente: requiere 4+ providers + CartProvider)
- [x] 5.3 Integration tests con Patrol (3 tests E2E: POS flow, Sale flow, Offline sync)

## Fase 6 — Limpieza Final

- [x] 6.1 Eliminar archivos service obsoletos (no hay archivos realmente obsoletos; ButcherService y SaleService son facades activas)
- [x] 6.2 Eliminar imports innecesarios
- [x] 6.3 flutter analyze sin warnings (0 warnings, 0 errors)
- [x] 6.4 flutter test all pass (148/148)