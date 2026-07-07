import 'package:cloud_firestore/cloud_firestore.dart';

class Store {
  const Store({
    required this.id,
    required this.name,
    required this.address,
    required this.phone,
    required this.active,
  });

  final String id;
  final String name;
  final String address;
  final String phone;
  final bool active;

  factory Store.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};

    return Store(
      id: doc.id,
      name: data['name'] as String? ?? 'Sucursal principal',
      address: data['address'] as String? ?? '',
      phone: data['phone'] as String? ?? '',
      active: data['active'] as bool? ?? true,
    );
  }
}
