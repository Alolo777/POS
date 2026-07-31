import 'package:firebase_auth/firebase_auth.dart';

abstract class AuthRepository {
  Stream<User?> get authStateChanges;
  Future<String?> signIn(String email, String password);
  Future<String?> signUp(String email, String password, String businessName);
  Future<void> signOut();
  Future<void> ensureCurrentUserWorkspace();
  Future<void> createOwnerWorkspace({required String businessName, User? user});
}
