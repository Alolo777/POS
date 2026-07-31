abstract class BackupRepository {
  Future<String> exportLocalBackup({
    required String businessId,
  });

  Future<String> exportSalesCsv({
    required String businessId,
  });
}
