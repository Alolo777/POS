import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/sale.dart';
import '../models/shift.dart';
import 'connectivity_service.dart';

class ShiftService {
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

    return null;
  }

  Future<void> openShift({
    required String businessId,
    required String storeId,
    required String employeeId,
    required double openingCash,
  }) async {
    await _connectivityService.requireConnection('Abrir caja');
    if (openingCash < 0) {
      throw StateError('El efectivo inicial no puede ser negativo');
    }

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

  Future<void> addCashMovement({
    required String businessId,
    required Shift shift,
    required String type,
    required double amount,
    required String comment,
  }) async {
    await _connectivityService.requireConnection('Registrar movimiento de caja');
    if (amount <= 0) {
      throw StateError('La cantidad debe ser mayor a cero');
    }
    if (type != 'deposit' && type != 'payout') {
      throw StateError('Tipo de movimiento no valido');
    }

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
  }

  Future<void> closeShift({
    required String businessId,
    required Shift shift,
    required double closingCash,
  }) async {
    await _connectivityService.requireConnection('Cerrar caja');
    if (closingCash < 0) {
      throw StateError('El efectivo final no puede ser negativo');
    }

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
    final refundCashShortage = expectedCash < 0 ? expectedCash.abs() : 0.0;

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
      'refundCashShortage': refundCashShortage,
      'closedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}
