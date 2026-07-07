import 'package:cloud_firestore/cloud_firestore.dart';

class Modifier {
  const Modifier({
    required this.id,
    required this.name,
    required this.price,
    required this.active,
  });

  final String id;
  final String name;
  final double price;
  final bool active;

  factory Modifier.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return Modifier(
      id: doc.id,
      name: data['name'] as String? ?? '',
      price: (data['price'] as num? ?? 0).toDouble(),
      active: data['active'] as bool? ?? true,
    );
  }
}
