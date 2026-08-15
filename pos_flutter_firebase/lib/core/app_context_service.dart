import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../shared/models/app_session.dart';
import '../shared/models/business.dart';
import '../shared/models/employee.dart';
import '../shared/models/store.dart';
import 'offline/local_database.dart';
import 'domain/app_context_repository.dart';

class AppContextService implements AppContextRepository {
  final _db = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  Future<AppSession?> loadSession() async {
    final user = _auth.currentUser;
    if (user == null) return null;

    try {
      final session = await _loadOnline(user.uid);
      if (session != null) {
        // Persistimos la última sesión para poder reconstruirla sin conexión.
        await LocalDatabase.cacheLastSession(
          businessId: session.business.id,
          employeeId: session.employee.id,
        );
      }
      return session;
    } catch (_) {
      // Sin conexión: reconstruimos la sesión desde la caché local.
      return _loadCached(user.uid);
    }
  }

  Future<AppSession?> _loadOnline(String uid) async {
    final userDoc = await _db.collection('users').doc(uid).get();
    if (!userDoc.exists) return null;

    final userData = userDoc.data() ?? {};
    final businessId = userData['businessId'] as String? ?? '';
    final employeeId = userData['employeeId'] as String? ?? uid;
    if (businessId.isEmpty) return null;

    final businessDoc = await _db.collection('businesses').doc(businessId).get();
    final employeeDoc = await _db
        .collection('businesses')
        .doc(businessId)
        .collection('employees')
        .doc(employeeId)
        .get();
    if (!businessDoc.exists || !employeeDoc.exists) return null;

    final employee = Employee.fromDoc(employeeDoc);
    final employeesQuery = await _db
        .collection('businesses')
        .doc(businessId)
        .collection('employees')
        .where('active', isEqualTo: true)
        .get();
    final employees = employeesQuery.docs.map(Employee.fromDoc).toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    final storesQuery = await _db
        .collection('businesses')
        .doc(businessId)
        .collection('stores')
        .where('active', isEqualTo: true)
        .get();

    final stores = storesQuery.docs
        .map(Store.fromDoc)
        .where((store) => employee.isOwner || employee.storeIds.contains(store.id))
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));

    return AppSession(
      business: Business.fromDoc(businessDoc),
      employee: employee,
      employees: employees,
      stores: stores,
    );
  }

  /// Reconstruye la sesión desde la caché de Hive (para abrir la app sin
  /// conexión a internet). Devuelve null si no hay sesión previa guardada.
  AppSession? _loadCached(String uid) {
    final last = LocalDatabase.getLastSession();
    if (last == null) return null;
    final businessId = last['businessId']!;
    final employeeId = last['employeeId']!;

    final business = LocalDatabase.getCachedBusiness(businessId);
    final employees = LocalDatabase.getCachedEmployees(businessId) ?? [];
    if (business == null || employees.isEmpty) return null;

    Employee employee = employees.first;
    for (final e in employees) {
      if (e.id == employeeId || e.authUid == employeeId || e.id == uid) {
        employee = e;
        break;
      }
    }

    final stores = (LocalDatabase.getCachedStores(businessId) ?? [])
        .where((s) => s.active && (employee.isOwner || employee.storeIds.contains(s.id)))
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));

    return AppSession(
      business: business,
      employee: employee,
      employees: employees,
      stores: stores,
    );
  }
}
