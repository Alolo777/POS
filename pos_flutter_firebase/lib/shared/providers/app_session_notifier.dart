import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../shared/models/app_session.dart';
import '../../shared/models/employee.dart';
import '../../shared/models/store.dart';
import '../../core/domain/app_context_repository.dart';

class AppSessionNotifier extends ChangeNotifier {
  AppSessionNotifier({required AppContextRepository appContextService})
      : _appContextService = appContextService;

  final AppContextRepository _appContextService;

  AppSession? _session;
  Store? _selectedStore;
  Employee? _activeEmployee;
  bool _isLoading = false;
  String? _error;

  AppSession? get session => _session;
  Store? get selectedStore => _selectedStore;
  Employee? get activeEmployee => _activeEmployee;
  bool get isLoading => _isLoading;
  String? get error => _error;

  bool get isAuthenticated => FirebaseAuth.instance.currentUser != null;
  bool get hasSession => _session != null;
  bool get hasStores => _session != null && _session!.stores.isNotEmpty;
  bool get needsStoreSelection => hasSession && _selectedStore == null && _session!.stores.length > 1;
  bool get needsPinEntry => _activeEmployee == null && _selectedStore != null;

  List<Employee> get employeesForStore {
    if (_session == null || _selectedStore == null) return [];
    return _session!.employees
        .where((e) => e.active && (e.isOwner || e.storeIds.contains(_selectedStore!.id)))
        .toList();
  }

  Store get resolvedStore {
    final selected = _selectedStore;
    if (selected != null && _session != null) {
      for (final store in _session!.stores) {
        if (store.id == selected.id) {
          _selectedStore = store;
          return store;
        }
      }
    }
    if (_session != null && _session!.stores.isNotEmpty) {
      _selectedStore = _session!.stores.first;
      return _selectedStore!;
    }
    throw StateError('No stores available');
  }

  bool get isCurrentEmployeeValid {
    final employee = _activeEmployee;
    if (employee == null) return false;
    return employeesForStore.any((e) => e.id == employee.id && e.active);
  }

  Employee get resolvedEmployee => _activeEmployee ?? _session!.employee;

  Future<void> loadSession() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _session = await _appContextService.loadSession();
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> refreshSession() async {
    await loadSession();
  }

  void selectStore(Store store) {
    _selectedStore = store;
    notifyListeners();
  }

  void clearStore() {
    _selectedStore = null;
    _activeEmployee = null;
    notifyListeners();
  }

  void selectEmployee(Employee employee) {
    _activeEmployee = employee;
    notifyListeners();
  }

  void clearEmployee() {
    _activeEmployee = null;
    notifyListeners();
  }

  void clearSession() {
    _session = null;
    _selectedStore = null;
    _activeEmployee = null;
    _error = null;
    notifyListeners();
  }
}
