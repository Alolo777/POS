import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';

const e2eEmail = String.fromEnvironment('E2E_EMAIL', defaultValue: 'test@test.com');
const e2ePassword = String.fromEnvironment('E2E_PASSWORD', defaultValue: '123456');

void main() {
  patrolTest(
    'POS: crear producto, agregar al carrito y cobrar',
    ($) async {
      // 1. Login
      await $(#emailField).enterText(e2eEmail);
      await $(#passwordField).enterText(e2ePassword);
      await $(#submitButton).tap();
      await $.pumpAndSettle();

      // 2. Navegar a POS
      await $('Punto de venta').tap();
      await $.pumpAndSettle();

      // 3. Buscar producto
      await $(#searchField).enterText('Producto 1');
      await $.pumpAndSettle();

      // 4. Agregar al carrito
      await $('Producto 1').tap();
      await $.pumpAndSettle();

      // 5. Cobrar
      await $('Cobrar').tap();
      await $.pumpAndSettle();
      await $('Cobrar efectivo').tap();
      await $.pumpAndSettle();

      // 6. Verificar mensaje de exito
      expect(find.textContaining('Venta'), findsOneWidget);
    },
  );
}
