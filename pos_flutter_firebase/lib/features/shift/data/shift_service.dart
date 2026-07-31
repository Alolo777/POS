import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../shared/models/sale.dart';
import '../../../shared/models/shift.dart';
import '../../../core/offline/local_database.dart';
import '../../../core/offline/sync_queue.dart';
import '../../../core/network/connectivity_service.dart';
import '../domain/shift_repository.dart';

class ShiftService implements ShiftRepository {
  ShiftService({FirebaseFirestore? firestore, ConnectivityService? connectivityService})
      : _db = firestore ?? FirebaseFirestore.instance,
        _connectivityService = connectivityService ?? ConnectivityService();

  final FirebaseFirestore _db;
  final ConnectivityService _connectivityService;

  Stream<Shift?> watchOpenShift({
    required String businessId,
    required String storeId,
    required String employeeId,
  }) {
    return _db
        .collection('businesses')
        .doc(businessId)
        .collection('shifts')
        .where('status', isEqualTo: 'open')
        .snapshots()
        .map((snapshot) {
      for (final doc in snapshot.docs) {
        final shift = Shift.fromDoc(doc);
        if (shift.storeId == storeId && shift.employeeId == employeeId) {
          LocalDatabase.cacheShifts(businessId, [shift]);
          return shift;
        }
      }
      return null;
    });
  }

  Future<Shift?> getOpenShift({
    required String businessId,
    required String storeId,
    required String employeeId,
  }) async {
    if (await _connectivityService.hasConnection()) {
      final snapshot = await _db
          .collection('businesses')
          .doc(businessId)
          .collection('shifts')
          .where('status', isEqualTo: 'open')
          .get();

      for (final doc in snapshot.docs) {
        final shift = Shift.fromDoc(doc);
        if (shift.storeId == storeId && shift.employeeId == employeeId) {
          return shift;
        }
      }
    }

    List<Shift>? cached;
    try {
      cached = LocalDatabase.getCachedShifts(businessId);
    } catch (_) {
      cached = null;
    }
    if (cached != null) {
      for (final shift in cached) {
        if (shift.storeId == storeId && shift.employeeId == employeeId && shift.status == 'open') {
          return shift;
        }
      }
    }

    return null;
  }

  Stream<List<Shift>> watchShifts({
    required String businessId,
    required String storeId,
  }) {
    return _db.collection('businesses').doc(businessId).collection('shifts').snapshots().map((snapshot) {
      final shifts = snapshot.docs.map(Shift.fromDoc).where((shift) => shift.storeId == storeId).toList();
      shifts.sort((a, b) {
        final aDate = a.openedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bDate = b.openedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return bDate.compareTo(aDate);
      });
      return shifts;
    });
  }

  Stream<List<Shift>> watchAllClosedShifts({
    required String businessId,
  }) {
    return _db
        .collection('businesses')
        .doc(businessId)
        .collection('shifts')
        .where('status', isEqualTo: 'closed')
        .snapshots()
        .map((snapshot) {
      final shifts = snapshot.docs.map(Shift.fromDoc).toList();
      shifts.sort((a, b) {
        final aDate = a.closedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bDate = b.closedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return bDate.compareTo(aDate);
      });
      return shifts;
    });
  }

  Future<void> openShift({
    required String businessId,
    required String storeId,
    required String employeeId,
    required double openingCash,
  }) async {
    if (openingCash < 0) {
      throw StateError('El efectivo inicial no puede ser negativo');
    }

    if (await _connectivityService.hasConnection()) {
      final shiftsRef = _db.collection('businesses').doc(businessId).collection('shifts');
      final openShifts = await shiftsRef.where('status', isEqualTo: 'open').get();
      final alreadyOpen = openShifts.docs.map(Shift.fromDoc).any(
            (shift) => shift.storeId == storeId && shift.employeeId == employeeId,
          );
      if (alreadyOpen) {
        throw StateError('Ya tienes una caja abierta');
      }

      await shiftsRef.add({
        'businessId': businessId,
        'storeId': storeId,
        'employeeId': employeeId,
        'status': 'open',
        'openingCash': openingCash,
        'closingCash': null,
        'cashSales': 0,
        'cardSales': 0,
        'totalSales': 0,
        'cashRefunds': 0,
        'depositsTotal': 0,
        'payoutsTotal': 0,
        'cashMovements': [],
        'openedAt': FieldValue.serverTimestamp(),
        'closedAt': null,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } else {
      await SyncQueue.enqueue(type: 'openShift', data: {
        'businessId': businessId,
        'storeId': storeId,
        'employeeId': employeeId,
        'openingCash': openingCash,
      });
    }
  }

  Future<void> addCashMovement({
    required String businessId,
    required Shift shift,
    required String type,
    required double amount,
    required String comment,
  }) async {
    if (amount <= 0) {
      throw StateError('La cantidad debe ser mayor a cero');
    }
    if (type != 'deposit' && type != 'payout') {
      throw StateError('Tipo de movimiento no valido');
    }

    if (await _connectivityService.hasConnection()) {
      final movement = {
        'type': type,
        'amount': amount,
        'comment': comment.trim(),
        'createdAt': Timestamp.now(),
      };

      await _db.collection('businesses').doc(businessId).collection('shifts').doc(shift.id).update({
        'cashMovements': FieldValue.arrayUnion([movement]),
        if (type == 'deposit') 'depositsTotal': FieldValue.increment(amount),
        if (type == 'payout') 'payoutsTotal': FieldValue.increment(amount),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } else {
      await SyncQueue.enqueue(type: 'addCashMovement', data: {
        'businessId': businessId,
        'shiftId': shift.id,
        'type': type,
        'amount': amount,
        'comment': comment.trim(),
      });
    }
  }

  Future<void> closeShift({
    required String businessId,
    required Shift shift,
    required double closingCash,
  }) async {
    if (closingCash < 0) {
      throw StateError('El efectivo final no puede ser negativo');
    }

    if (await _connectivityService.hasConnection()) {
      final sales = await _db
          .collection('businesses')
          .doc(businessId)
          .collection('sales')
          .where('shiftId', isEqualTo: shift.id)
          .get();
      final parsedSales = sales.docs.map(Sale.fromDoc).toList();
      final originalSales = parsedSales.where((sale) => !sale.isRefund).toList();
      final refunds = parsedSales.where((sale) => sale.isRefund).toList();
      final cashSales = parsedSales
          .where((sale) => !sale.isRefund && sale.paymentMethod == 'cash')
          .fold<double>(0, (total, sale) => total + sale.total);
      final cardSales = parsedSales
          .where((sale) => !sale.isRefund && sale.paymentMethod == 'card')
          .fold<double>(0, (total, sale) => total + sale.total);
      final cashRefunds = refunds
          .where((sale) => sale.paymentMethod == 'cash')
          .fold<double>(0, (total, sale) => total + sale.total);
      final totalSales = originalSales.fold<double>(0, (total, sale) => total + sale.total);
      final expectedCash = shift.openingCash + cashSales - cashRefunds + shift.depositsTotal - shift.payoutsTotal;

      final shiftStart = shift.openedAt ?? DateTime.now().subtract(const Duration(days: 1));
      final shiftEnd = DateTime.now();

      final receivingsDocs = await _db
          .collection('businesses').doc(businessId)
          .collection('poultryReceivings')
          .where('storeId', isEqualTo: shift.storeId)
          .get();
      final chickensReceived = receivingsDocs.docs.fold<int>(0, (sum, doc) {
        final data = doc.data();
        final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
        if (createdAt != null && (createdAt.isBefore(shiftStart) || createdAt.isAfter(shiftEnd))) return sum;
        return sum + ((data['totalChickens'] as num? ?? 0).toInt());
      });
      final kgReceived = receivingsDocs.docs.fold<double>(0, (sum, doc) {
        final data = doc.data();
        final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
        if (createdAt != null && (createdAt.isBefore(shiftStart) || createdAt.isAfter(shiftEnd))) return sum;
        return sum + ((data['totalWeightKg'] as num? ?? 0).toDouble());
      });

      final butcheringDocs = await _db
          .collection('businesses').doc(businessId)
          .collection('butchering')
          .where('storeId', isEqualTo: shift.storeId)
          .get();
      int chickensButchered = 0;
      double kgButchered = 0;
      double butcherMermaKg = 0;
      for (final doc in butcheringDocs.docs) {
        final data = doc.data();
        final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
        if (createdAt != null && (createdAt.isBefore(shiftStart) || createdAt.isAfter(shiftEnd))) continue;
        chickensButchered += (data['chickenCount'] as num? ?? 0).toInt();
        kgButchered += (data['exactWeightKg'] as num? ?? 0).toDouble();
        butcherMermaKg += (data['mermaKg'] as num? ?? 0).toDouble();
      }

      final transfersDocs = await _db
          .collection('businesses').doc(businessId)
          .collection('transfers')
          .get();
      int transfersSent = 0;
      int transfersReceived = 0;
      for (final doc in transfersDocs.docs) {
        final data = doc.data();
        final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
        if (createdAt != null && (createdAt.isBefore(shiftStart) || createdAt.isAfter(shiftEnd))) continue;
        if (data['fromStoreId'] == shift.storeId) transfersSent++;
        if (data['toStoreId'] == shift.storeId) transfersReceived++;
      }

      await _db
          .collection('businesses')
          .doc(businessId)
          .collection('shifts')
          .doc(shift.id)
          .update({
        'status': 'closed',
        'closingCash': closingCash,
        'cashSales': cashSales,
        'cardSales': cardSales,
        'totalSales': totalSales,
        'cashRefunds': cashRefunds,
        'expectedCash': expectedCash,
        'cashDifference': closingCash - expectedCash,
        'closedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'chickensReceived': chickensReceived,
        'kgReceived': kgReceived,
        'chickensButchered': chickensButchered,
        'kgButchered': kgButchered,
        'butcherMermaKg': butcherMermaKg,
        'transfersSent': transfersSent,
        'transfersReceived': transfersReceived,
      });
    } else {
      await SyncQueue.enqueue(type: 'closeShift', data: {
        'businessId': businessId,
        'shiftId': shift.id,
        'closingCash': closingCash,
      });
    }
  }
}