import '../../../shared/models/open_ticket.dart';
import '../../../shared/models/cart_item.dart';

abstract class OpenTicketRepository {
  Stream<List<OpenTicket>> watchOpenTickets({
    required String businessId,
    required String storeId,
  });

  List<OpenTicket>? getCachedOpenTickets(String businessId);

  Future<String> saveOpenTicket({
    required String businessId,
    required String storeId,
    required String employeeId,
    required String name,
    required List<CartItem> items,
    required double total,
    String? ticketId,
  });

  Future<void> closeOpenTicket({
    required String businessId,
    required String ticketId,
  });

  Future<void> cancelOpenTicket({
    required String businessId,
    required String ticketId,
  });
}
