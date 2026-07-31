import '../../../shared/models/modifier.dart';

abstract class ModifierRepository {
  Stream<List<Modifier>> watchModifiers({
    required String businessId,
  });

  List<Modifier>? getCachedModifiers(String businessId);

  Future<String> addModifier({
    required String businessId,
    required String name,
    required double price,
  });

  Future<void> updateModifier({
    required String businessId,
    required String modifierId,
    required String name,
    required double price,
  });

  Future<void> deactivateModifier({
    required String businessId,
    required String modifierId,
  });
}
