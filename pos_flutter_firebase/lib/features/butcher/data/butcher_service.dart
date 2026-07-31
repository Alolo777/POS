import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../shared/models/butcher_section.dart';
import '../../../core/network/connectivity_service.dart';
import '../domain/butcher_repository.dart';
import '../domain/butcher_record.dart';
import 'butcher_recipe_service.dart';
import 'butcher_receipt_service.dart';
import 'butcher_stock_service.dart';

class ButcherService implements ButcherRepository {
  factory ButcherService.create({
    required ConnectivityService connectivityService,
    FirebaseFirestore? firestore,
  }) {
    final instance = ButcherService._internal(
      connectivityService: connectivityService,
      firestore: firestore,
    );
    instance._init(connectivityService);
    return instance;
  }

  ButcherService._internal({
    required ConnectivityService connectivityService,
    FirebaseFirestore? firestore,
  })  : _stockService = ButcherStockService(firestore: firestore),
        _recipeService = ButcherRecipeService(firestore: firestore);

  final ButcherStockService _stockService;
  final ButcherRecipeService _recipeService;
  late final ButcherReceiptService _receiptService;

  void _init(ConnectivityService connectivityService) {
    _receiptService = ButcherReceiptService(
      connectivityService: connectivityService,
      stockService: _stockService,
      firestore: _stockService.firestore,
    );
  }

  @override
  Stream<List<ButcherSection>> watchRecipe(String businessId) =>
      _recipeService.watchRecipe(businessId);

  @override
  Future<List<ButcherSection>> getRecipe(String businessId) =>
      _recipeService.getRecipe(businessId);

  @override
  Future<void> saveRecipe({
    required String businessId,
    required List<ButcherSection> sections,
  }) =>
      _recipeService.saveRecipe(businessId: businessId, sections: sections);

  @override
  Future<({String receiptId, List<({String name, double weight, double percentage})> yields})> registerEntry({
    required String businessId,
    required String storeId,
    required String employeeId,
    required int chickenCount,
    required double avgWeight,
    required List<ButcherSection> sections,
    String? sourceStoreId,
  }) =>
      _receiptService.registerEntry(
        businessId: businessId,
        storeId: storeId,
        employeeId: employeeId,
        chickenCount: chickenCount,
        avgWeight: avgWeight,
        sections: sections,
        sourceStoreId: sourceStoreId,
      );

  @override
  Future<({String receiptId, List<({String name, double weight, double percentage})> yields})> registerPartsEntry({
    required String businessId,
    required String storeId,
    required String employeeId,
    required List<({String name, double weight})> parts,
    String? sourceStoreId,
  }) =>
      _receiptService.registerPartsEntry(
        businessId: businessId,
        storeId: storeId,
        employeeId: employeeId,
        parts: parts,
        sourceStoreId: sourceStoreId,
      );

  @override
  Future<String> registerButchering({
    required String businessId,
    required String storeId,
    required String employeeId,
    required String employeeName,
    required int chickenCount,
    required double exactWeightKg,
    required String wholeProductId,
    required List<ButcherSectionResult> sections,
  }) =>
      _receiptService.registerButchering(
        businessId: businessId,
        storeId: storeId,
        employeeId: employeeId,
        employeeName: employeeName,
        chickenCount: chickenCount,
        exactWeightKg: exactWeightKg,
        wholeProductId: wholeProductId,
        sections: sections,
      );

  @override
  Future<void> cancelEntry({
    required String businessId,
    required String receiptId,
    required String reason,
    required String cancelledBy,
  }) =>
      _receiptService.cancelEntry(
        businessId: businessId,
        receiptId: receiptId,
        reason: reason,
        cancelledBy: cancelledBy,
      );

  @override
  Future<void> cancelButchering({
    required String businessId,
    required String recordId,
    required String reason,
    required String cancelledBy,
  }) =>
      _receiptService.cancelButchering(
        businessId: businessId,
        recordId: recordId,
        reason: reason,
        cancelledBy: cancelledBy,
      );

  @override
  Stream<List<Map<String, dynamic>>> watchReceipts(
    String businessId, {
    String? storeId,
  }) =>
      _receiptService.watchReceipts(businessId, storeId: storeId);

  @override
  Stream<List<ButcherRecord>> watchButcheringRecords(
    String businessId, {
    String? storeId,
  }) =>
      _receiptService.watchButcheringRecords(businessId, storeId: storeId);

  @override
  Future<List<ButcherRecord>> getButcheringRecords(
    String businessId, {
    String? storeId,
    DateTime? from,
    DateTime? to,
  }) =>
      _receiptService.getButcheringRecords(
        businessId,
        storeId: storeId,
        from: from,
        to: to,
      );

  @override
  Future<void> assignPendingStockToProduct({
    required String businessId,
    required String sectionName,
    required String productId,
    required String storeId,
  }) =>
      _stockService.assignPendingStockToProduct(
        businessId: businessId,
        sectionName: sectionName,
        productId: productId,
        storeId: storeId,
      );

  @override
  Future<List<({String name, double totalWeight, double percentage})>> getPendingStockBySection(
    String businessId, {
    String? storeId,
  }) =>
      _stockService.getPendingStockBySection(businessId, storeId: storeId);

  @override
  Future<void> clearStoreStock({
    required String businessId,
    required String storeId,
  }) =>
      _stockService.clearStoreStock(businessId: businessId, storeId: storeId);

  @override
  Future<Map<String, ({double price, double stock, double sales})>> getSectionRealData({
    required String businessId,
    required String storeId,
    required List<String> sectionNames,
  }) =>
      _stockService.getSectionRealData(
        businessId: businessId,
        storeId: storeId,
        sectionNames: sectionNames,
      );
}