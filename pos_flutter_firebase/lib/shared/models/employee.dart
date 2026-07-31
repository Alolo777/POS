import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert';
import 'package:crypto/crypto.dart';

class Employee {
  const Employee({
    required this.id,
    required this.businessId,
    required this.authUid,
    required this.name,
    required this.email,
    required this.role,
    required this.storeIds,
    required this.permissions,
    required this.pin,
    required this.active,
  });

  final String id;
  final String businessId;
  final String authUid;
  final String name;
  final String email;
  final String role;
  final List<String> storeIds;
  final List<String> permissions;
  final String pin;
  final bool active;

  bool get isOwner => role == 'owner';
  bool get isAdmin => role == 'admin' || isOwner;
  bool get isManager => role == 'manager';

  bool hasPermission(String permission) {
    return permissions.contains('*') || permissions.contains(permission);
  }

  bool verifyPin(String input) {
    if (pin.isEmpty) return input == '0000';
    final isLegacyPlaintext = pin.length == 4 && RegExp(r'^\d{4}$').hasMatch(pin);
    if (isLegacyPlaintext) return pin == input;
    return hashPin(input) == pin;
  }

  static String hashPin(String input) {
    final bytes = utf8.encode(input);
    return sha256.convert(bytes).toString();
  }

  factory Employee.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};

    return Employee(
      id: doc.id,
      businessId: data['businessId'] as String? ?? '',
      authUid: data['authUid'] as String? ?? '',
      name: data['name'] as String? ?? 'Usuario',
      email: data['email'] as String? ?? '',
      role: data['role'] as String? ?? 'cashier',
      storeIds: List<String>.from(data['storeIds'] as List? ?? const []),
      permissions: List<String>.from(data['permissions'] as List? ?? const []),
      pin: data['pin'] as String? ?? '',
      active: data['active'] as bool? ?? true,
    );
  }
}