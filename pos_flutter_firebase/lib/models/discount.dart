import 'package:cloud_firestore/cloud_firestore.dart';

class Discount {
  const Discount({
    required this.id,
    required this.name,
    required this.type,
    required this.value,
    required this.active,
  });

  final String id;
  final String name;
  final String type;
  final double value;
  final bool active;

  bool get isPercentage => type == 'percentage';

  factory Discount.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return Discount(
      id: doc.id,
      name: data['name'] as String? ?? '',
      type: data['type'] as String? ?? 'fixed',
      value: (data['value'] as num? ?? 0).toDouble(),
      active: data['active'] as bool? ?? true,
    );
  }
}
