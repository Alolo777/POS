import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert';
import 'dart:math';
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

  bool verifyPin(String input) => verifyHashedPin(input, pin);

  /// Comprueba un PIN contra el hash almacenado. Soporta tres formatos:
  ///   - `pbkdf2$...` (nuevo, con sal e iteraciones).
  ///   - SHA-256 puro de 64 hex (legacy, sin sal).
  ///   - PIN plano de 4 dígitos (legacy).
  static bool verifyHashedPin(String input, String storedPin) {
    if (storedPin.isEmpty) return input == '0000';
    final trimmed = input.trim();
    if (storedPin.startsWith(r'pbkdf2$')) {
      return _verifyPbkdf2(trimmed, storedPin);
    }
    if (storedPin.length == 64 && RegExp(r'^[0-9a-f]{64}$').hasMatch(storedPin)) {
      return sha256.convert(utf8.encode(trimmed)).toString() == storedPin;
    }
    final isLegacyPlaintext = storedPin.length == 4 && RegExp(r'^\d{4}$').hasMatch(storedPin);
    if (isLegacyPlaintext) return storedPin == trimmed;
    return false;
  }

  /// Genera un hash del PIN con PBKDF2-HMAC-SHA256, sal aleatoria de 16 bytes y
  /// 60.000 iteraciones. El resultado lleva el formato
  /// `pbkdf2$<iteraciones>$<salB64>$<digestB64>`.
  static String hashPin(String input) {
    final salt = List<int>.generate(16, (_) => Random.secure().nextInt(256));
    final digest = _pbkdf2(utf8.encode(input.trim()), salt, iterations: _pbkdf2Iterations);
    return 'pbkdf2\$$_pbkdf2Iterations\$${base64Encode(salt)}\$${base64Encode(digest)}';
  }

  static const int _pbkdf2Iterations = 60000;

  static List<int> _pbkdf2(List<int> password, List<int> salt, {required int iterations}) {
    final hmac = Hmac(sha256, password);
    final block = <int>[...salt, 0, 0, 0, 1];
    var u = hmac.convert(block).bytes;
    final result = List<int>.from(u);
    for (var i = 1; i < iterations; i++) {
      u = hmac.convert(u).bytes;
      for (var j = 0; j < result.length; j++) {
        result[j] ^= u[j];
      }
    }
    return result;
  }

  static bool _verifyPbkdf2(String input, String stored) {
    final parts = stored.split(r'$');
    if (parts.length != 4) return false;
    final iterations = int.tryParse(parts[1]) ?? 0;
    if (iterations <= 0) return false;
    final List<int> salt;
    final List<int> expected;
    try {
      salt = base64Decode(parts[2]);
      expected = base64Decode(parts[3]);
    } on FormatException {
      return false;
    }
    final computed = _pbkdf2(utf8.encode(input), salt, iterations: iterations);
    if (computed.length != expected.length) return false;
    var diff = 0;
    for (var i = 0; i < computed.length; i++) {
      diff |= computed[i] ^ expected[i];
    }
    return diff == 0;
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