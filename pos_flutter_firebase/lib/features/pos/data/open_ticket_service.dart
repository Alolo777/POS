import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../shared/models/cart_item.dart';
import '../../../shared/models/open_ticket.dart';
import '../../../core/offline/local_database.dart';
import '../../../core/offline/sync_queue.dart';
import '../../../core/network/connectivity_service.dart';
import '../domain/open_ticket_repository.dart';

class OpenTicketService implements OpenTicketRepository {
  OpenTicketService({FirebaseFirestore? firestore, ConnectivityService? connectivityService})
      : _db = firestore ?? FirebaseFirestore.instance,
        _connectivityService = connectivityService ?? ConnectivityService();

  final FirebaseFirestore _db;
  final ConnectivityService _connectivityService;

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
      LocalDatabase.cacheOpenTickets(businessId, tickets);
      return tickets;
    });
  }

  List<OpenTicket>? getCachedOpenTickets(String businessId) {
    return LocalDatabase.getCachedOpenTickets(businessId);
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
    if (items.isEmpty) {
      throw StateError('Agrega productos antes de suspender el ticket');
    }

    final trimmedName = name.trim().isEmpty ? 'Ticket abierto' : name.trim();
    final docRef = ticketId == null ? _db.collection('businesses').doc(businessId).collection('openTickets').doc() : null;

    if (await _connectivityService.hasConnection()) {
      final ref = docRef ?? _db.collection('businesses').doc(businessId).collection('openTickets').doc(ticketId);
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

      await ref.set(data, SetOptions(merge: true));
      return ref.id;
    } else {
      final tempId = ticketId ?? 'temp_${DateTime.now().millisecondsSinceEpoch}';
      await SyncQueue.enqueue(type: 'saveOpenTicket', data: {
        'businessId': businessId,
        'storeId': storeId,
        'employeeId': employeeId,
        'name': trimmedName,
        'items': items.map((item) => item.toMap()).toList(),
        'total': total,
        'ticketId': ticketId,
        'tempId': tempId,
      });
      return tempId;
    }
  }

  Future<void> closeOpenTicket({
    required String businessId,
    required String ticketId,
  }) async {
    if (await _connectivityService.hasConnection()) {
      await _db.collection('businesses').doc(businessId).collection('openTickets').doc(ticketId).update({
        'status': 'closed',
        'closedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } else {
      await SyncQueue.enqueue(type: 'closeOpenTicket', data: {
        'businessId': businessId,
        'ticketId': ticketId,
      });
    }
  }

  Future<void> cancelOpenTicket({
    required String businessId,
    required String ticketId,
  }) async {
    if (await _connectivityService.hasConnection()) {
      await _db.collection('businesses').doc(businessId).collection('openTickets').doc(ticketId).update({
        'status': 'cancelled',
        'cancelledAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } else {
      await SyncQueue.enqueue(type: 'cancelOpenTicket', data: {
        'businessId': businessId,
        'ticketId': ticketId,
      });
    }
  }
}