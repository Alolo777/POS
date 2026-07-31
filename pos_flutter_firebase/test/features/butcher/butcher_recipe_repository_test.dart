import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pos_flutter_firebase/shared/models/butcher_section.dart';
import 'package:pos_flutter_firebase/features/butcher/data/butcher_recipe_service.dart';

const businessId = 'test_business';

void main() {
  group('ButcherRecipeService.saveRecipe', () {
    test('saves sections sorted by sortOrder', () async {
      final db = FakeFirebaseFirestore();
      final service = ButcherRecipeService(firestore: db);

      await service.saveRecipe(
        businessId: businessId,
        sections: [
          ButcherSection(name: 'Pechuga', percentage: 35, sortOrder: 2),
          ButcherSection(name: 'Pierna', percentage: 25, sortOrder: 1),
          ButcherSection(name: 'Ala', percentage: 20, sortOrder: 3),
        ],
      );

      final doc = await db
          .collection('businesses').doc(businessId)
          .collection('butcherRecipe').doc('config').get();
      final sections = (doc.data()?['sections'] as List)
          .map((s) => ButcherSection.fromMap(s as Map<String, dynamic>))
          .toList();

      expect(sections.length, 3);
      expect(sections[0].name, 'Pierna');
      expect(sections[1].name, 'Pechuga');
      expect(sections[2].name, 'Ala');
    });
  });

  group('ButcherRecipeService.getRecipe', () {
    test('returns empty list when no recipe exists', () async {
      final db = FakeFirebaseFirestore();
      final service = ButcherRecipeService(firestore: db);

      final recipe = await service.getRecipe(businessId);
      expect(recipe, isEmpty);
    });

    test('returns saved sections sorted by sortOrder', () async {
      final db = FakeFirebaseFirestore();
      final service = ButcherRecipeService(firestore: db);

      await db.collection('businesses').doc(businessId)
          .collection('butcherRecipe').doc('config').set({
        'sections': [
          {'name': 'B', 'percentage': 50, 'sortOrder': 2},
          {'name': 'A', 'percentage': 50, 'sortOrder': 1},
        ],
      });

      final recipe = await service.getRecipe(businessId);
      expect(recipe.length, 2);
      expect(recipe[0].name, 'A');
      expect(recipe[1].name, 'B');
    });
  });

  group('ButcherRecipeService.watchRecipe (stream)', () {
    test('emits sections from Firestore', () async {
      final db = FakeFirebaseFirestore();
      final service = ButcherRecipeService(firestore: db);

      await db.collection('businesses').doc(businessId)
          .collection('butcherRecipe').doc('config').set({
        'sections': [
          {'name': 'Muslo', 'percentage': 30, 'sortOrder': 1},
        ],
      });

      final sections = await service.watchRecipe(businessId).first;
      expect(sections.length, 1);
      expect(sections.first.name, 'Muslo');
    });
  });
}
