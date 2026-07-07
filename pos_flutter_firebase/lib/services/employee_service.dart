import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/employee.dart';
import 'connectivity_service.dart';

class EmployeeService {
  final _db = FirebaseFirestore.instance;
  final _connectivityService = ConnectivityService();

  Stream<List<Employee>> watchEmployees({required String businessId}) {
    return _db
        .collection('businesses')
        .doc(businessId)
        .collection('employees')
        .snapshots()
        .map((snapshot) {
      final employees = snapshot.docs.map(Employee.fromDoc).toList();
      employees.sort((a, b) => a.name.compareTo(b.name));
      return employees;
    });
  }

  Future<void> addEmployee({
    required String businessId,
    required String name,
    required String email,
    required String role,
    required String pin,
    required List<String> storeIds,
    required List<String> permissions,
  }) async {
    await _connectivityService.requireConnection('Crear empleado');
    final trimmedName = name.trim();
    final trimmedEmail = email.trim().toLowerCase();
    if (trimmedName.isEmpty || trimmedEmail.isEmpty) {
      throw StateError('Nombre y correo son obligatorios');
    }
    if (storeIds.isEmpty) {
      throw StateError('Selecciona al menos una sucursal');
    }
    if (pin.trim().length < 4) {
      throw StateError('El PIN debe tener al menos 4 digitos');
    }

    await _db.collection('businesses').doc(businessId).collection('employees').add({
      'businessId': businessId,
      'authUid': '',
      'name': trimmedName,
      'email': trimmedEmail,
      'role': role,
      'storeIds': storeIds,
      'permissions': permissions,
      'pin': pin.trim(),
      'active': true,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateEmployee({
    required String businessId,
    required Employee employee,
    required String role,
    required String pin,
    required List<String> storeIds,
    required List<String> permissions,
    required bool active,
  }) async {
    await _connectivityService.requireConnection('Editar empleado');
    if (storeIds.isEmpty) {
      throw StateError('Selecciona al menos una sucursal');
    }
    if (pin.trim().length < 4) {
      throw StateError('El PIN debe tener al menos 4 digitos');
    }

    await _db
        .collection('businesses')
        .doc(businessId)
        .collection('employees')
        .doc(employee.id)
        .update({
      'role': role,
      'storeIds': storeIds,
      'permissions': permissions,
      'pin': pin.trim(),
      'active': active,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}
