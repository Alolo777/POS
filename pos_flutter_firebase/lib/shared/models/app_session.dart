import 'business.dart';
import 'employee.dart';
import 'store.dart';

class AppSession {
  const AppSession({
    required this.business,
    required this.employee,
    required this.employees,
    required this.stores,
  });

  final Business business;
  final Employee employee;
  final List<Employee> employees;
  final List<Store> stores;
}