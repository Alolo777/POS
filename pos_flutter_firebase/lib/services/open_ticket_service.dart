import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/cart_item.dart';
import '../models/open_ticket.dart';
import 'connectivity_service.dart';

class OpenTicketService {
  final _db = FirebaseFirestore.instance;
  final _connectivityService = ConnectivityService();

  Stream<List<OpenTicket>> watchOpenTickets({
    required String businessId,
    required String storeId,
  }) {
    return _db
        .collection('businesses')
        .doc(businessId)
        .collection('openTickets')
        .where('status', isEqualTo: 'open')
        .snapshots()
        .map((snapshot) {
      final tickets = snapshot.docs
          .map(OpenTicket.fromDoc)
          .where((ticket) => ticket.storeId == storeId)
          .toList();
      tickets.sort((a, b) {
        final aDate = a.updatedAt ?? a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bDate = b.updatedAt ?? b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return bDate.compareTo(aDate);
      });
      return tickets;
    });
  }

  Future<String> saveOpenTicket({
    required String businessId,
    required String storeId,
    required String employeeId,
    required String name,
    required List<CartItem> items,
    required double total,
    String? ticketId,
  }) async {
    await _connectivityService.requireConnection('Guardar ticket abierto');
    if (items.isEmpty) {
      throw StateError('Agrega productos antes de suspender el ticket');
    }

    final ticketsRef = _db.collection('businesses').doc(businessId).collection('openTickets');
    final docRef = ticketId == null ? ticketsRef.doc() : ticketsRef.doc(ticketId);
    final trimmedName = name.trim().isEmpty ? 'Ticket abierto' : name.trim();

    final data = {
      'businessId': businessId,
      'storeId': storeId,
      'employeeId': employeeId,
      'name': trimmedName,
      'items': items.map((item) => item.toMap()).toList(),
      'total': total,
      'status': 'open',
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (ticketId == null) {
      data['createdAt'] = FieldValue.serverTimestamp();
    }

    await docRef.set(data, SetOptions(merge: true));

    return docRef.id;
  }

  Future<void> closeOpenTicket({
    required String businessId,
    required String ticketId,
  }) async {
    await _connectivityService.requireConnection('Cerrar ticket abierto');
    await _db.collection('businesses').doc(businessId).collection('openTickets').doc(ticketId).update({
      'status': 'closed',
      'closedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> cancelOpenTicket({
    required String businessId,
    required String ticketId,
  }) async {
    await _connectivityService.requireConnection('Cancelar ticket abierto');
    await _db.collection('businesses').doc(businessId).collection('openTickets').doc(ticketId).update({
      'status': 'cancelled',
      'cancelledAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}
