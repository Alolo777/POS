import '../../../shared/models/employee.dart';

abstract class EmployeeRepository {
  Stream<List<Employee>> watchEmployees({
    required String businessId,
  });

  List<Employee>? getCachedEmployees(String businessId);

  Future<void> addEmployee({
    required String businessId,
    required String name,
    required String email,
    required String role,
    required String pin,
    required List<String> storeIds,
    required List<String> permissions,
  });

  Future<void> updateEmployee({
    required String businessId,
    required Employee employee,
    required String role,
    required String pin,
    required List<String> storeIds,
    required List<String> permissions,
    required bool active,
  });

  Future<void> deactivateEmployee({
    required String businessId,
    required String employeeId,
  });
}
