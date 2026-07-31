import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../shared/models/employee.dart';
import '../../../core/offline/local_database.dart';
import '../../../core/offline/sync_queue.dart';
import '../../../core/network/connectivity_service.dart';
import '../domain/employee_repository.dart';

String _hashedPin(String rawPin) => Employee.hashPin(rawPin.trim());

class EmployeeService implements EmployeeRepository {
  EmployeeService({FirebaseFirestore? firestore, ConnectivityService? connectivityService})
      : _db = firestore ?? FirebaseFirestore.instance,
        _connectivityService = connectivityService ?? ConnectivityService();

  final FirebaseFirestore _db;
  final ConnectivityService _connectivityService;

  Stream<List<Employee>> watchEmployees({required String businessId}) {
    return _db
        .collection('businesses')
        .doc(businessId)
        .collection('employees')
        .snapshots()
        .map((snapshot) {
      final employees = snapshot.docs.map(Employee.fromDoc).toList();
      employees.sort((a, b) => a.name.compareTo(b.name));
      LocalDatabase.cacheEmployees(businessId, employees);
      return employees;
    });
  }

  List<Employee>? getCachedEmployees(String businessId) {
    return LocalDatabase.getCachedEmployees(businessId);
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

    if (await _connectivityService.hasConnection()) {
      await _db.collection('businesses').doc(businessId).collection('employees').add({
        'businessId': businessId,
        'authUid': '',
        'name': trimmedName,
        'email': trimmedEmail,
        'role': role,
        'storeIds': storeIds,
        'permissions': permissions,
        'pin': _hashedPin(pin),
        'active': true,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } else {
      await SyncQueue.enqueue(type: 'addEmployee', data: {
        'businessId': businessId,
        'name': trimmedName,
        'email': trimmedEmail,
        'role': role,
        'pin': _hashedPin(pin),
        'storeIds': storeIds,
        'permissions': permissions,
      });
    }
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
    if (storeIds.isEmpty) {
      throw StateError('Selecciona al menos una sucursal');
    }
    final finalPin = pin.trim();
    if (finalPin.isNotEmpty && finalPin.length < 4) {
      throw StateError('El PIN debe tener al menos 4 digitos');
    }

    if (await _connectivityService.hasConnection()) {
      await _db
          .collection('businesses')
          .doc(businessId)
          .collection('employees')
          .doc(employee.id)
          .update({
        'role': role,
        'storeIds': storeIds,
        'permissions': permissions,
        if (finalPin.isNotEmpty) 'pin': _hashedPin(pin),
        'active': active,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } else {
      await SyncQueue.enqueue(type: 'updateEmployee', data: {
        'businessId': businessId,
        'employeeId': employee.id,
        'role': role,
        if (finalPin.isNotEmpty) 'pin': _hashedPin(pin),
        'storeIds': storeIds,
        'permissions': permissions,
        'active': active,
      });
    }
  }

  Future<void> deactivateEmployee({
    required String businessId,
    required String employeeId,
  }) async {
    if (await _connectivityService.hasConnection()) {
      await _db
          .collection('businesses')
          .doc(businessId)
          .collection('employees')
          .doc(employeeId)
          .update({'active': false, 'updatedAt': FieldValue.serverTimestamp()});
    } else {
      await SyncQueue.enqueue(type: 'deactivateEmployee', data: {
        'businessId': businessId,
        'employeeId': employeeId,
      });
    }
  }
}