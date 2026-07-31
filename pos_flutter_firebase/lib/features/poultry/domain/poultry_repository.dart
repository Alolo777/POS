import 'dart:async';
import 'poultry_config.dart';
import 'chicken_receiving.dart';

abstract class PoultryRepository {
  Future<PoultryConfig?> getConfig(String businessId);
  Future<void> saveConfig(String businessId, PoultryConfig config);

  Future<void> saveReceiving(
    String businessId,
    ChickenReceiving receiving,
  );
  Stream<List<ChickenReceiving>> watchReceivings(
    String businessId,
    String storeId,
  );
}
