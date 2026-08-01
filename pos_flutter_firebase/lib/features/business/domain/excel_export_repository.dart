class ExcelExportResult {
  const ExcelExportResult({
    required this.path,
    required this.message,
    required this.counts,
  });

  final String path;
  final String message;
  final Map<String, int> counts;
}

abstract class ExcelExportRepository {
  Future<ExcelExportResult> exportAllData({
    required String businessId,
  });
}
