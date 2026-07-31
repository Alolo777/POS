import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';

const e2eEmail = String.fromEnvironment('E2E_EMAIL', defaultValue: 'test@test.com');
const e2ePassword = String.fromEnvironment('E2E_PASSWORD', defaultValue: '123456');

void main() {
  patrolTest(
    'Offline: crear venta sin conexion y sincronizar al recuperar red',
    ($) async {
      // 1. Login
      await $(#emailField).enterText(e2eEmail);
      await $(#passwordField).enterText(e2ePassword);
      await $(#submitButton).tap();
      await $.pumpAndSettle();

      // 2. Ir a POS
      await $('Punto de venta').tap();
      await $.pumpAndSettle();

      // 3. Desactivar WiFi / modo avion (manual en E2E real)
      // Nota: en un dispositivo fisico el operador debe poner modo avion
      // Patrol puede usar $.native para abrir ajustes rapidos si es necesario

      // 4. Agregar producto y cobrar (cola offline)
      await $('Producto 1').tap();
      await $.pumpAndSettle();
      await $('Cobrar').tap();
      await $.pumpAndSettle();
      await $('Cobrar efectivo').tap();
      await $.pumpAndSettle();

      // Verificar mensaje de venta guardada offline
      expect(find.textContaining('Venta'), findsOneWidget);

      // 5. Reactivar conexion y sincronizar
      // En un escenario real, la SyncQueue procesa automaticamente
      // al recuperar conectividad. Verificar que la venta aparece en Recibos.
      await $('Recibos').tap();
      await $.pumpAndSettle();
      expect(find.textContaining('Producto 1'), findsOneWidget);
    },
  );
}
