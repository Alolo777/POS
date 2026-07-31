import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';

const e2eEmail = String.fromEnvironment('E2E_EMAIL', defaultValue: 'test@test.com');
const e2ePassword = String.fromEnvironment('E2E_PASSWORD', defaultValue: '123456');

void main() {
  patrolTest(
    'Sale: realizar venta y ver en historial de recibos',
    ($) async {
      // 1. Login
      await $(#emailField).enterText(e2eEmail);
      await $(#passwordField).enterText(e2ePassword);
      await $(#submitButton).tap();
      await $.pumpAndSettle();

      // 2. Navegar a POS
      await $('Punto de venta').tap();
      await $.pumpAndSettle();

      // 3. Agregar primer producto al carrito
      await $('Producto 1').tap();
      await $.pumpAndSettle();

      // 4. Cobrar
      await $('Cobrar').tap();
      await $.pumpAndSettle();
      await $('Cobrar efectivo').tap();
      await $.pumpAndSettle();

      // 5. Ir a Recibos
      await $('Recibos').tap();
      await $.pumpAndSettle();

      // 6. Verificar que aparece la venta
      expect(find.textContaining('Producto 1'), findsOneWidget);
    },
  );
}
