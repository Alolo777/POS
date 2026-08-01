import 'dart:typed_data';

import 'package:excel_community/excel_community.dart';

class ExcelSheetData {
  const ExcelSheetData({
    required this.title,
    required this.headers,
    required this.rows,
  });

  final String title;
  final List<String> headers;
  final List<List<Object?>> rows;
}

CellValue? _cellValue(Object? value) {
  if (value == null) return null;
  if (value is int) return IntCellValue(value);
  if (value is double) return DoubleCellValue(value);
  if (value is num) return DoubleCellValue(value.toDouble());
  if (value is bool) return BoolCellValue(value);
  return TextCellValue(value.toString());
}

Uint8List buildExcelWorkbook(List<ExcelSheetData> sheets) {
  final excel = Excel.createExcel();
  for (final data in sheets) {
    final sheet = excel[data.title];
    sheet.appendRow(data.headers.map(TextCellValue.new).toList());
    for (final row in data.rows) {
      sheet.appendRow(row.map(_cellValue).toList());
    }
  }
  excel.delete('Sheet1');
  final bytes = excel.encode();
  if (bytes == null) {
    throw StateError('No se pudo generar el archivo Excel');
  }
  return Uint8List.fromList(bytes);
}
