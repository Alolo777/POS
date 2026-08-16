abstract class BackupRepository {
  Future<String> exportLocalBackup({
    required String businessId,
  });

  Future<String> importLocalBackup({
    required String businessId,
    required String filePath,
  });

  Future<String> exportSalesCsv({
    required String businessId,
  });
}
