import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/app_session.dart';
import '../models/business.dart';
import '../models/employee.dart';
import '../models/store.dart';

class AppContextService {
  final _db = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  Future<AppSession?> loadSession() async {
    final user = _auth.currentUser;
    if (user == null) return null;

    final userDoc = await _db.collection('users').doc(user.uid).get();
    if (!userDoc.exists) return null;

    final userData = userDoc.data() ?? {};
    final businessId = userData['businessId'] as String? ?? '';
    final employeeId = userData['employeeId'] as String? ?? user.uid;
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
}
