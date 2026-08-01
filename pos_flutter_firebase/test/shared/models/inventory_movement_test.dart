import 'package:flutter_test/flutter_test.dart';
import 'package:pos_flutter_firebase/shared/models/inventory_movement.dart';

void main() {
  group('InventoryMovement.fromMap', () {
    test('reads canonical previousQuantity/newQuantity fields', () {
      final movement = InventoryMovement.fromMap({
        'businessId': 'b1',
        'storeId': 's1',
        'productId': 'p1',
        'productName': 'Pechuga',
        'type': 'butchering',
        'previousQuantity': 10.0,
        'newQuantity': 15.0,
        'reason': 'Destazado',
        'employeeId': 'e1',
      }, 'm1');

      expect(movement.previousQuantity, 10.0);
      expect(movement.newQuantity, 15.0);
      expect(movement.difference, 5.0);
    });

    test('reads legacy sale schema (previousStock/newStock)', () {
      final movement = InventoryMovement.fromMap({
        'businessId': 'b1',
        'storeId': 's1',
        'productId': 'p1',
        'productName': 'Pierna',
        'type': 'sale',
        'quantity': -2.0,
        'previousStock': 7.0,
        'newStock': 5.0,
        'saleFolio': 'T-000001',
        'employeeId': 'e1',
      }, 'm2');

      expect(movement.previousQuantity, 7.0);
      expect(movement.newQuantity, 5.0);
      expect(movement.difference, -2.0);
    });

    test('uses stored difference field when present', () {
      final movement = InventoryMovement.fromMap({
        'businessId': 'b1',
        'storeId': 's1',
        'productId': 'p1',
        'productName': 'Ala',
        'type': 'refund',
        'difference': 2.0,
        'previousQuantity': 3.0,
        'newQuantity': 5.0,
        'employeeId': 'e1',
      }, 'm3');

      expect(movement.difference, 2.0);
    });

    test('computes newQuantity from quantity when newStock is missing', () {
      final movement = InventoryMovement.fromMap({
        'businessId': 'b1',
        'storeId': 's1',
        'productId': 'p1',
        'productName': 'Pollo Entero',
        'type': 'sale',
        'quantity': -1.5,
        'previousStock': 4.0,
        'employeeId': 'e1',
      }, 'm4');

      expect(movement.newQuantity, 2.5);
      expect(movement.difference, -1.5);
    });
  });
}
