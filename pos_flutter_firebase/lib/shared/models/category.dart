import 'package:cloud_firestore/cloud_firestore.dart';

class Category {
  const Category({
    required this.id,
    required this.name,
    required this.color,
    required this.active,
  });

  final String id;
  final String name;
  final int color;
  final bool active;

  factory Category.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};

    return Category(
      id: doc.id,
      name: data['name'] as String? ?? '',
      color: (data['color'] as num? ?? 0xFF607D8B).toInt(),
      active: data['active'] as bool? ?? true,
    );
  }
}