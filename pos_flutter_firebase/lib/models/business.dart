import 'package:cloud_firestore/cloud_firestore.dart';

class Business {
  const Business({
    required this.id,
    required this.name,
    required this.currency,
    required this.timezone,
    required this.active,
  });

  final String id;
  final String name;
  final String currency;
  final String timezone;
  final bool active;

  factory Business.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};

    return Business(
      id: doc.id,
      name: data['name'] as String? ?? 'Mi negocio',
      currency: data['currency'] as String? ?? 'MXN',
      timezone: data['timezone'] as String? ?? 'America/Mexico_City',
      active: data['active'] as bool? ?? true,
    );
  }
}
