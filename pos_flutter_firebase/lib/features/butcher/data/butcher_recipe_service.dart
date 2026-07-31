import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../shared/models/butcher_section.dart';

class ButcherRecipeService {
  ButcherRecipeService({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  static const _configDocId = 'config';

  DocumentReference _configRef(String businessId) =>
      _db.collection('businesses').doc(businessId).collection('butcherRecipe').doc(_configDocId);

  CollectionReference _productsRef(String businessId) =>
      _db.collection('businesses').doc(businessId).collection('products');

  Stream<List<ButcherSection>> watchRecipe(String businessId) {
    return _configRef(businessId).snapshots().map((doc) {
      final data = doc.data() as Map<String, dynamic>?;
      if (data == null || !doc.exists) return <ButcherSection>[];
      final sections = (data['sections'] as List<dynamic>?) ?? [];
      return sections
          .map((s) => ButcherSection.fromMap(s as Map<String, dynamic>))
          .toList()
        ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    });
  }

  Future<List<ButcherSection>> getRecipe(String businessId) async {
    final doc = await _configRef(businessId).get();
    final data = doc.data() as Map<String, dynamic>?;
    if (data == null || !doc.exists) return <ButcherSection>[];
    final sections = (data['sections'] as List<dynamic>?) ?? [];
    return sections
        .map((s) => ButcherSection.fromMap(s as Map<String, dynamic>))
        .toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
  }

  Future<void> saveRecipe({
    required String businessId,
    required List<ButcherSection> sections,
  }) async {
    final sorted = List<ButcherSection>.from(sections)
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    await _configRef(businessId).set({
      'sections': sorted.map((s) => s.toMap()).toList(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    for (final section in sections) {
      final existing = await _productsRef(businessId)
          .where('name', isEqualTo: section.name)
          .where('active', isEqualTo: true)
          .limit(1)
          .get();
      if (existing.docs.isNotEmpty) continue;

      final ref = _generateSectionRef(section.name);
      final productRef = _productsRef(businessId).doc();
      final now = FieldValue.serverTimestamp();
      await productRef.set({
        'businessId': businessId,
        'name': section.name,
        'description': 'Sección de destazado: ${section.name}',
        'sku': ref,
        'barcode': '',
        'categoryId': null,
        'categoryName': null,
        'sellBy': 'weight',
        'imageUrl': null,
        'localImagePath': null,
        'price': 0.0,
        'cost': 0.0,
        'ref': ref,
        'trackStock': true,
        'stock': 0,
        'stockQuantity': 0.0,
        'lowStockAlert': 0,
        'lowStockAlertQuantity': 0.0,
        'presentationType': 'shape',
        'presentationShape': 'square',
        'presentationColor': 0xFF868E96,
        'active': true,
        'createdAt': now,
        'updatedAt': now,
      });
    }
  }

  String _generateSectionRef(String name) {
    final ts = DateTime.now().millisecondsSinceEpoch;
    final cleanName = name.replaceAll(RegExp(r'[^A-Z0-9]'), '').toUpperCase();
    return 'SEC${cleanName.length > 6 ? cleanName.substring(0, 6) : cleanName}${(ts % 1000000).toString().padLeft(6, '0')}';
  }
}
