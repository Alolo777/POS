import '../../../shared/models/butcher_section.dart';

abstract class ButcherRecipeRepository {
  Stream<List<ButcherSection>> watchRecipe(String businessId);
  Future<List<ButcherSection>> getRecipe(String businessId);
  Future<void> saveRecipe({
    required String businessId,
    required List<ButcherSection> sections,
  });
}
