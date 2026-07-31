import '../../../shared/models/shift.dart';

abstract class ShiftRepository {
  Stream<Shift?> watchOpenShift({
    required String businessId,
    required String storeId,
    required String employeeId,
  });

  Future<Shift?> getOpenShift({
    required String businessId,
    required String storeId,
    required String employeeId,
  });

  Stream<List<Shift>> watchShifts({
    required String businessId,
    required String storeId,
  });

  Stream<List<Shift>> watchAllClosedShifts({
    required String businessId,
  });

  Future<void> openShift({
    required String businessId,
    required String storeId,
    required String employeeId,
    required double openingCash,
  });

  Future<void> addCashMovement({
    required String businessId,
    required Shift shift,
    required String type,
    required double amount,
    required String comment,
  });

  Future<void> closeShift({
    required String businessId,
    required Shift shift,
    required double closingCash,
  });
}
