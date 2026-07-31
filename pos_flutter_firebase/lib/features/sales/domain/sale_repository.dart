import 'sale_creator_repository.dart';
import 'sale_refund_repository.dart';
import 'sale_query_repository.dart';

export 'sale_query_repository.dart' show SalesPage;

abstract class SaleRepository implements SaleCreatorRepository, SaleRefundRepository, SaleQueryRepository {
  // This interface combines all three sub-interfaces for backward compatibility.
  // New code should depend on the specific sub-interfaces instead.
}
