import 'dart:async';
import 'transfer.dart';
import 'transfer_item.dart';

abstract class TransferRepository {
  Future<void> sendTransfer(
    String businessId,
    Transfer transfer,
  );
  Future<void> confirmTransfer(
    String businessId,
    String transferId,
    List<TransferItem> updatedItems,
    String toEmployeeId,
  );
  Future<void> cancelTransfer(
    String businessId,
    String transferId,
  );
  Stream<List<Transfer>> watchSentTransfers(
    String businessId,
    String storeId,
  );
  Stream<List<Transfer>> watchReceivedTransfers(
    String businessId,
    String storeId,
  );
}
