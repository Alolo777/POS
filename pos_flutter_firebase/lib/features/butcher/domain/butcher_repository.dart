import 'butcher_recipe_repository.dart';
import 'butcher_receipt_repository.dart';
import 'butcher_stock_repository.dart';

abstract class ButcherRepository implements ButcherRecipeRepository, ButcherReceiptRepository, ButcherStockRepository {
  // This interface combines all three sub-interfaces for backward compatibility.
  // New code should depend on the specific sub-interfaces instead.
}
