import '../../../shared/models/butcher_section.dart';
import 'butcher_record.dart';

abstract class ButcherReceiptRepository {
  Future<({String receiptId, List<({String name, double weight, double percentage})> yields})> registerEntry({
    required String businessId,
    required String storeId,
    required String employeeId,
    required int chickenCount,
    required double avgWeight,
    required List<ButcherSection> sections,
    String? sourceStoreId,
  });

  Future<({String receiptId, List<({String name, double weight, double percentage})> yields})> registerPartsEntry({
    required String businessId,
    required String storeId,
    required String employeeId,
    required List<({String name, double weight})> parts,
    String? sourceStoreId,
  });

  Future<String> registerButchering({
    required String businessId,
    required String storeId,
    required String employeeId,
    required String employeeName,
    required int chickenCount,
    required double exactWeightKg,
    required String wholeProductId,
    required List<ButcherSectionResult> sections,
  });

  Future<void> cancelEntry({
    required String businessId,
    required String receiptId,
    required String reason,
    required String cancelledBy,
  });

  Future<void> cancelButchering({
    required String businessId,
    required String recordId,
    required String reason,
    required String cancelledBy,
  });

  Stream<List<Map<String, dynamic>>> watchReceipts(
    String businessId, {
    String? storeId,
  });

  Stream<List<ButcherRecord>> watchButcheringRecords(
    String businessId, {
    String? storeId,
  });

  Future<List<ButcherRecord>> getButcheringRecords(
    String businessId, {
    String? storeId,
    DateTime? from,
    DateTime? to,
  });
}
