import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  Future<String?> signIn(String email, String password) async {
    try {
      await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return null;
    } on FirebaseAuthException catch (e) {
      return _mapError(e.code);
    } catch (e) {
      return e.toString();
    }
  }

  Future<String?> signUp(String email, String password, String businessName) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      await createOwnerWorkspace(businessName: businessName, user: credential.user);
      return null;
    } on FirebaseAuthException catch (e) {
      return _mapError(e.code);
    } catch (e) {
      return e.toString();
    }
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }

  Future<void> ensureCurrentUserWorkspace() async {
    final user = _auth.currentUser;
    if (user == null) return;

    final userDoc = await _db.collection('users').doc(user.uid).get();
    if (userDoc.exists) return;

    await createOwnerWorkspace(businessName: 'Mi negocio', user: user);
  }

  Future<void> createOwnerWorkspace({
    required String businessName,
    User? user,
  }) async {
    user ??= _auth.currentUser;
    if (user == null) return;

    final existingUser = await _db.collection('users').doc(user.uid).get();
    if (existingUser.exists) return;

    final businessRef = _db.collection('businesses').doc();
    final storeRef = businessRef.collection('stores').doc();
    final employeeRef = businessRef.collection('employees').doc(user.uid);
    final now = FieldValue.serverTimestamp();

    final batch = _db.batch();

    batch.set(businessRef, {
      'name': businessName.trim().isEmpty ? 'Mi negocio' : businessName.trim(),
      'currency': 'MXN',
      'timezone': 'America/Mexico_City',
      'active': true,
      'ownerUid': user.uid,
      'createdAt': now,
      'updatedAt': now,
    });

    batch.set(storeRef, {
      'businessId': businessRef.id,
      'name': 'Sucursal principal',
      'address': '',
      'phone': '',
      'active': true,
      'createdAt': now,
      'updatedAt': now,
    });

    // El empleado dueño se crea junto con el negocio para que todo acceso futuro
    // dependa del rol y del businessId, no del UID suelto en colecciones planas.
    batch.set(employeeRef, {
      'businessId': businessRef.id,
      'authUid': user.uid,
      'name': user.email ?? 'Dueno',
      'email': user.email ?? '',
      'role': 'owner',
      'storeIds': [storeRef.id],
      'permissions': ['*'],
      'pin': '0000',
      'active': true,
      'createdAt': now,
      'updatedAt': now,
    });

    // users/{uid} funciona como indice de sesion: evita buscar con
    // collectionGroup cada vez y facilita reglas de seguridad por negocio.
    batch.set(_db.collection('users').doc(user.uid), {
      'businessId': businessRef.id,
      'employeeId': employeeRef.id,
      'defaultStoreId': storeRef.id,
      'email': user.email ?? '',
      'createdAt': now,
      'updatedAt': now,
    });

    await batch.commit();
  }

  String _mapError(String code) {
    switch (code) {
      case 'user-not-found':
        return 'No existe una cuenta con ese correo';
      case 'wrong-password':
        return 'Contrasena incorrecta';
      case 'email-already-in-use':
        return 'Ese correo ya esta registrado';
      case 'invalid-email':
        return 'Correo invalido';
      case 'weak-password':
        return 'La contrasena debe tener al menos 6 caracteres';
      case 'invalid-credential':
        return 'Correo o contrasena incorrectos';
      default:
        return 'Error: $code';
    }
  }
}
