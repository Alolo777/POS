import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:excel_community/excel_community.dart';

import 'report_definition.dart';

/// Colores de la paleta corporativa del reporte.
const _accentHex = 'FFB45309'; // ámbar oscuro
const _totalHex = 'FFFEF3C7'; // fondo de la fila de totales
const _mutedHex = 'FF78716C'; // gris cálido para metadatos
const _headerBgHex = 'FFB45309';
const _headerTextHex = 'FFFFFFFF';

/// Convierte un valor del modelo de reporte a una celda de Excel.
///
/// `null` produce una celda vacía; los [DateTime] se guardan como celdas de
/// fecha reales (ordenables y filtrables en Excel).
CellValue? _cellValue(Object? value) {
  if (value == null) return null;
  if (value is int) return IntCellValue(value);
  if (value is double) return DoubleCellValue(value);
  if (value is num) return DoubleCellValue(value.toDouble());
  if (value is bool) return BoolCellValue(value);
  if (value is DateTime) return DateTimeCellValue.fromDateTime(value);
  return TextCellValue(value.toString());
}

/// Genera el archivo Excel del reporte con estilo profesional:
/// encabezado con nombre del negocio, fecha de generación, fila de encabezado
/// resaltada y congelada, anchos automáticos, formato de moneda/porcentaje,
/// totales resaltados y filtros automáticos en cada hoja.
Uint8List buildExcelWorkbook(ReportDefinition definition) {
  final excel = Excel.createExcel();
  excel.delete('Sheet1');

  final moneyFormat = _moneyFormat(definition.currencySymbol);
  final percentFormat = _percentFormat();
  final filterRanges = <String, String>{};

  for (final sheet in definition.sheets) {
    filterRanges[sheet.title] = _renderSheet(
      excel,
      sheet,
      businessName: definition.businessName,
      generatedAt: definition.generatedAt,
      moneyFormat: moneyFormat,
      percentFormat: percentFormat,
    );
  }

  final bytes = excel.encode();
  if (bytes == null) {
    throw StateError('No se pudo generar el archivo Excel');
  }
  final withFilters = _injectAutoFilters(
    Uint8List.fromList(bytes),
    filterRanges,
  );
  if (withFilters == null) {
    throw StateError('No se pudo generar el archivo Excel');
  }
  return withFilters;
}

/// Pinta una hoja completa (bloque de título + tablas) y devuelve el rango
/// `A{h}:{col}{lastRow}` que debe cubrir el filtro automático.
String _renderSheet(
  Excel excel,
  ReportSheet sheet, {
  required String businessName,
  required DateTime generatedAt,
  required NumFormat moneyFormat,
  required NumFormat percentFormat,
}) {
  final ws = excel[sheet.title];

  var cursor = 0;
  _writeTitleBlock(
    ws,
    businessName: businessName,
    sheetTitle: sheet.title,
    generatedAt: generatedAt,
    columnCount: sheet.tables
        .fold<int>(0, (max, t) => t.headers.length > max ? t.headers.length : max),
    row: cursor,
  );
  cursor += 4;

  int? firstHeaderRow;
  for (final table in sheet.tables) {
    firstHeaderRow ??= cursor;
    if (table.caption != null) {
      _writeCaption(ws, table.caption!, row: cursor);
      cursor += 1;
    }
    final headerRow = cursor;
    _writeHeaderRow(ws, table.headers, row: headerRow);
    cursor += 1;

    if (table.rows.isEmpty && table.totalsRow == null) {
      _writeEmptyNote(ws, table.headers.length, row: cursor);
      cursor += 1;
    } else {
      for (var i = 0; i < table.rows.length; i++) {
        _writeDataRow(
          ws,
          table.rows[i],
          rowIndex: cursor,
          moneyColumns: table.moneyColumns,
          percentColumns: table.percentColumns,
          moneyFormat: moneyFormat,
          percentFormat: percentFormat,
        );
        if (table.boldRows.contains(i)) {
          _styleRow(ws, row: cursor, bold: true);
        }
        cursor += 1;
      }
      if (table.totalsRow != null) {
        _writeTotalsRow(
          ws,
          table.totalsRow!,
          rowIndex: cursor,
          moneyColumns: table.moneyColumns,
          percentColumns: table.percentColumns,
          moneyFormat: moneyFormat,
          percentFormat: percentFormat,
        );
        cursor += 1;
      }
    }

    _autoWidthColumns(ws, table, headerRow, firstHeaderRow: firstHeaderRow == headerRow);
    cursor += 1; // separador entre tablas
  }

  final headerRow = firstHeaderRow ?? 0;
  if (sheet.tables.isNotEmpty) {
    ws.frozenRows = headerRow + 1;
  }

  final lastRow = cursor - 1;
  final lastCol = sheet.tables
      .fold<int>(0, (max, t) => t.headers.length > max ? t.headers.length : max);
  return 'A${headerRow + 1}:${_columnLetter(lastCol)}${lastRow}';
}

void _writeTitleBlock(
  Sheet ws, {
  required String businessName,
  required String sheetTitle,
  required DateTime generatedAt,
  required int columnCount,
  required int row,
}) {
  final lastColIndex = columnCount == 0 ? 0 : columnCount - 1;
  ws.merge(
    CellIndex.indexByColumnRow(rowIndex: row, columnIndex: 0),
    CellIndex.indexByColumnRow(rowIndex: row, columnIndex: lastColIndex),
  );
  ws.cell(CellIndex.indexByColumnRow(rowIndex: row, columnIndex: 0)).cellStyle =
      _titleStyle();
  ws.cell(CellIndex.indexByColumnRow(rowIndex: row, columnIndex: 0)).value =
      TextCellValue(businessName);

  ws.merge(
    CellIndex.indexByColumnRow(rowIndex: row + 1, columnIndex: 0),
    CellIndex.indexByColumnRow(rowIndex: row + 1, columnIndex: lastColIndex),
  );
  ws.cell(CellIndex.indexByColumnRow(rowIndex: row + 1, columnIndex: 0)).cellStyle =
      _sheetTitleStyle();
  ws.cell(CellIndex.indexByColumnRow(rowIndex: row + 1, columnIndex: 0)).value =
      TextCellValue(sheetTitle);

  ws.merge(
    CellIndex.indexByColumnRow(rowIndex: row + 2, columnIndex: 0),
    CellIndex.indexByColumnRow(rowIndex: row + 2, columnIndex: lastColIndex),
  );
  ws.cell(CellIndex.indexByColumnRow(rowIndex: row + 2, columnIndex: 0)).cellStyle =
      _metaStyle();
  ws.cell(CellIndex.indexByColumnRow(rowIndex: row + 2, columnIndex: 0)).value =
      TextCellValue('Generado el ${_formatDate(generatedAt)} a las ${_formatTime(generatedAt)}');
}

void _writeCaption(Sheet ws, String caption, {required int row}) {
  ws.merge(
    CellIndex.indexByColumnRow(rowIndex: row, columnIndex: 0),
    CellIndex.indexByColumnRow(rowIndex: row, columnIndex: 0),
  );
  ws.cell(CellIndex.indexByColumnRow(rowIndex: row, columnIndex: 0)).cellStyle =
      _captionStyle();
  ws.cell(CellIndex.indexByColumnRow(rowIndex: row, columnIndex: 0)).value =
      TextCellValue(caption);
}

void _writeHeaderRow(Sheet ws, List<String> headers, {required int row}) {
  for (var c = 0; c < headers.length; c++) {
    ws.cell(CellIndex.indexByColumnRow(rowIndex: row, columnIndex: c)).cellStyle =
        _headerStyle();
    ws.cell(CellIndex.indexByColumnRow(rowIndex: row, columnIndex: c)).value =
        TextCellValue(headers[c]);
  }
}

void _writeDataRow(
  Sheet ws,
  List<Object?> row, {
  required int rowIndex,
  required Set<int> moneyColumns,
  required Set<int> percentColumns,
  required NumFormat moneyFormat,
  required NumFormat percentFormat,
}) {
  for (var c = 0; c < row.length; c++) {
    final value = _cellValue(row[c]);
    ws.cell(CellIndex.indexByColumnRow(rowIndex: rowIndex, columnIndex: c)).value = value;
    if (value != null) {
      if (moneyColumns.contains(c)) {
        ws.cell(CellIndex.indexByColumnRow(rowIndex: rowIndex, columnIndex: c)).cellStyle =
            _moneyStyle(moneyFormat);
      } else if (percentColumns.contains(c)) {
        ws.cell(CellIndex.indexByColumnRow(rowIndex: rowIndex, columnIndex: c)).cellStyle =
            _percentStyle(percentFormat);
      }
    }
  }
}

void _writeTotalsRow(
  Sheet ws,
  List<Object?> row, {
  required int rowIndex,
  required Set<int> moneyColumns,
  required Set<int> percentColumns,
  required NumFormat moneyFormat,
  required NumFormat percentFormat,
}) {
  for (var c = 0; c < row.length; c++) {
    final cell = ws.cell(CellIndex.indexByColumnRow(rowIndex: rowIndex, columnIndex: c));
    cell.cellStyle = _totalStyle();
    cell.value = _cellValue(row[c]);
    if (moneyColumns.contains(c)) {
      cell.cellStyle = _moneyStyle(moneyFormat).copyWith(
        backgroundColorHexVal: ExcelColor.fromHexString(_totalHex),
        boldVal: true,
      );
    } else if (percentColumns.contains(c)) {
      cell.cellStyle = _percentStyle(percentFormat).copyWith(
        backgroundColorHexVal: ExcelColor.fromHexString(_totalHex),
        boldVal: true,
      );
    }
  }
}

void _writeEmptyNote(Sheet ws, int columnCount, {required int row}) {
  ws.merge(
    CellIndex.indexByColumnRow(rowIndex: row, columnIndex: 0),
    CellIndex.indexByColumnRow(rowIndex: row, columnIndex: columnCount - 1),
  );
  ws.cell(CellIndex.indexByColumnRow(rowIndex: row, columnIndex: 0)).cellStyle =
      _emptyNoteStyle();
  ws.cell(CellIndex.indexByColumnRow(rowIndex: row, columnIndex: 0)).value =
      TextCellValue('Sin registros');
}

void _styleRow(Sheet ws, {required int row, required bool bold}) {
  if (!bold) return;
  var c = 0;
  while (true) {
    final cell = ws.cell(CellIndex.indexByColumnRow(rowIndex: row, columnIndex: c));
    if (cell.value == null) break;
    cell.cellStyle = _boldStyle();
    c += 1;
  }
}

void _autoWidthColumns(
  Sheet ws,
  ReportTable table,
  int headerRow, {
  required bool firstHeaderRow,
}) {
  if (firstHeaderRow) {
    for (var c = 0; c < table.headers.length; c++) {
      var maxLen = table.headers[c].length;
      for (var r = 0; r < table.rows.length; r++) {
        final value = table.rows[r][c];
        if (value == null) continue;
        if (value is DateTime) {
          final len = '${_formatDate(value)} ${_formatTime(value)}'.length;
          if (len > maxLen) maxLen = len;
        } else if (value is bool) {
          maxLen = maxLen < 5 ? 5 : maxLen;
        } else {
          final len = value.toString().length;
          if (len > maxLen) maxLen = len;
        }
      }
      if (table.totalsRow != null && c < table.totalsRow!.length) {
        final len = table.totalsRow![c].toString().length;
        if (len > maxLen) maxLen = len;
      }
      var width = (maxLen + 2).clamp(10, 45).toDouble();
      if (table.moneyColumns.contains(c)) {
        width = width < 14 ? 14 : width;
      }
      ws.setColumnWidth(c, width);
    }
  }
}

// ---------------------------------------------------------------------------
// Estilos
// ---------------------------------------------------------------------------

CellStyle _titleStyle() => CellStyle(
      bold: true,
      fontSize: 16,
      fontColorHex: ExcelColor.fromHexString(_accentHex),
    );

CellStyle _sheetTitleStyle() => CellStyle(
      bold: true,
      fontSize: 12,
      fontColorHex: ExcelColor.fromHexString(_mutedHex),
    );

CellStyle _metaStyle() => CellStyle(
      italic: true,
      fontSize: 10,
      fontColorHex: ExcelColor.fromHexString(_mutedHex),
    );

CellStyle _captionStyle() => CellStyle(
      bold: true,
      fontSize: 11,
      fontColorHex: ExcelColor.fromHexString(_accentHex),
    );

CellStyle _headerStyle() => CellStyle(
      bold: true,
      fontColorHex: ExcelColor.fromHexString(_headerTextHex),
      backgroundColorHex: ExcelColor.fromHexString(_headerBgHex),
      horizontalAlign: HorizontalAlign.Center,
      verticalAlign: VerticalAlign.Center,
    );

CellStyle _moneyStyle(NumFormat format) => CellStyle(
      numberFormat: format,
      horizontalAlign: HorizontalAlign.Right,
    );

CellStyle _percentStyle(NumFormat format) => CellStyle(
      numberFormat: format,
      horizontalAlign: HorizontalAlign.Right,
    );

CellStyle _totalStyle() => CellStyle(
      bold: true,
      backgroundColorHex: ExcelColor.fromHexString(_totalHex),
    );

CellStyle _boldStyle() => CellStyle(bold: true);

CellStyle _emptyNoteStyle() => CellStyle(
      italic: true,
      fontColorHex: ExcelColor.fromHexString(_mutedHex),
    );

NumFormat _moneyFormat(String symbol) =>
    NumFormat.custom(formatCode: '"$symbol"#,##0.00');

NumFormat _percentFormat() => NumFormat.custom(formatCode: '0.0"%"');

// ---------------------------------------------------------------------------
// Utilidades
// ---------------------------------------------------------------------------

String _formatDate(DateTime date) {
  final d = date.day.toString().padLeft(2, '0');
  final m = date.month.toString().padLeft(2, '0');
  return '$d/$m/${date.year}';
}

String _formatTime(DateTime date) {
  final h = date.hour.toString().padLeft(2, '0');
  final min = date.minute.toString().padLeft(2, '0');
  return '$h:$min';
}

String _columnLetter(int column) {
  var value = column;
  var letters = '';
  while (value > 0) {
    value -= 1;
    letters = String.fromCharCode(65 + (value % 26)) + letters;
    value ~/= 26;
  }
  return letters.isEmpty ? 'A' : letters;
}

/// Inserta un `<autoFilter>` en cada hoja del archivo XLSX (que es un ZIP)
/// para que el administrador pueda filtrar y ordenar desde Excel.
Uint8List? _injectAutoFilters(Uint8List bytes, Map<String, String> ranges) {
  if (ranges.isEmpty) return bytes;

  final archive = ZipDecoder().decodeBytes(bytes);
  final workbook = _readEntry(archive, 'xl/workbook.xml');
  final rels = _readEntry(archive, 'xl/_rels/workbook.xml.rels');
  if (workbook == null || rels == null) return null;

  final sheetToRid = <String, String>{};
  final reSheet =
      RegExp(r'<sheet\b[^>]*\bname="([^"]+)"[^>]*\br:id="([^"]+)"');
  for (final m in reSheet.allMatches(workbook)) {
    sheetToRid[m.group(1)!] = m.group(2)!;
  }

  final ridToTarget = <String, String>{};
  final reRel = RegExp(r'<Relationship Id="([^"]+)"[^>]*Target="([^"]+)"');
  for (final m in reRel.allMatches(rels)) {
    ridToTarget[m.group(1)!] = m.group(2)!;
  }

  final modified = <String, List<int>>{};
  for (final entry in ranges.entries) {
    final rid = sheetToRid[entry.key];
    if (rid == null) continue;
    var target = ridToTarget[rid];
    if (target == null) continue;
    if (target.startsWith('/')) {
      target = target.substring(1);
    } else if (!target.startsWith('xl/')) {
      target = 'xl/$target';
    }
    final xml = _readEntry(archive, target);
    if (xml == null) continue;
    modified[target] = utf8.encode(_insertAutoFilter(xml, entry.value));
  }

  if (modified.isEmpty) return bytes;

  final out = Archive();
  for (final file in archive.files) {
    final replacement = modified[file.name];
    out.addFile(ArchiveFile(
      file.name,
      replacement?.length ?? file.size,
      replacement ?? file.content,
    ));
  }
  final encoded = ZipEncoder().encode(out);
  return Uint8List.fromList(encoded);
}

String? _readEntry(Archive archive, String path) {
  final file = archive.findFile(path);
  if (file == null) return null;
  return utf8.decode(file.content);
}

/// Coloca el elemento `<autoFilter>` en el orden correcto del esquema XLSX:
/// después de `<sheetData>` y antes de `<mergeCells>`.
String _insertAutoFilter(String xml, String range) {
  final autoFilter = '<autoFilter ref="$range"/>';
  final mergeIndex = xml.indexOf('<mergeCells');
  final sheetDataEnd = xml.indexOf('</sheetData>');
  if (mergeIndex != -1 && sheetDataEnd != -1 && mergeIndex > sheetDataEnd) {
    return xml.replaceRange(mergeIndex, mergeIndex, autoFilter);
  }
  if (sheetDataEnd != -1) {
    return xml.replaceRange(
      sheetDataEnd + '</sheetData>'.length,
      sheetDataEnd + '</sheetData>'.length,
      autoFilter,
    );
  }
  return xml;
}
