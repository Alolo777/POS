import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:excel_community/excel_community.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:pos_flutter_firebase/features/business/data/excel_book_builder.dart';
import 'package:pos_flutter_firebase/features/business/data/report_definition.dart';

void main() {
  ReportDefinition definition(DateTime generatedAt) => ReportDefinition(
        businessName: 'Pollos Marcos',
        currencySymbol: r'$',
        generatedAt: generatedAt,
        sheets: [
          ReportSheet(
            title: 'Ventas',
            tables: [
              ReportTable(
                headers: const ['Folio', 'Total', 'Descuento'],
                moneyColumns: const {1, 2},
                rows: const [
                  ['V-001', 120.5, 0],
                  ['V-002', null, 10.0],
                ],
                totalsRow: const ['Total', 120.5, 10.0],
              ),
            ],
          ),
          ReportSheet(
            title: 'Productos',
            tables: [
              ReportTable(
                headers: const ['Nombre', 'Activo'],
                rows: const [
                  ['Pollo', true],
                ],
              ),
            ],
          ),
        ],
      );

  test('genera un xlsx válido con las hojas y filas esperadas', () {
    final bytes = buildExcelWorkbook(definition(DateTime(2026, 8, 8, 10, 30)));

    expect(bytes, isNotNull);
    expect(bytes.length, greaterThan(0));

    final excel = Excel.decodeBytes(bytes);
    expect(excel.tables.containsKey('Ventas'), isTrue);
    expect(excel.tables.containsKey('Productos'), isTrue);
    expect(excel.tables.containsKey('Sheet1'), isFalse);

    // Bloque de título: nombre del negocio (fila 0), título de hoja (fila 1),
    // fecha de generación (fila 2), encabezado (fila 4) y datos (fila 5).
    final ventas = excel.tables['Ventas']!;
    expect(ventas.maxRows, greaterThanOrEqualTo(6));

    final businessCell = ventas
        .cell(CellIndex.indexByColumnRow(rowIndex: 0, columnIndex: 0))
        .value;
    expect((businessCell as TextCellValue).value.text, 'Pollos Marcos');

    final headerCell = ventas
        .cell(CellIndex.indexByColumnRow(rowIndex: 4, columnIndex: 0))
        .value;
    expect((headerCell as TextCellValue).value.text, 'Folio');

    final folioCell = ventas
        .cell(CellIndex.indexByColumnRow(rowIndex: 5, columnIndex: 0))
        .value;
    expect((folioCell as TextCellValue).value.text, 'V-001');

    final totalCell = ventas
        .cell(CellIndex.indexByColumnRow(rowIndex: 5, columnIndex: 1))
        .value;
    expect(totalCell is DoubleCellValue, isTrue);
    expect((totalCell as DoubleCellValue).value, 120.5);

    final nullCell = ventas
        .cell(CellIndex.indexByColumnRow(rowIndex: 6, columnIndex: 1))
        .value;
    expect(nullCell, isNull);
  });

  test('congela la fila del encabezado', () {
    final bytes = buildExcelWorkbook(definition(DateTime(2026, 8, 8)));
    final excel = Excel.decodeBytes(bytes);
    expect(excel.tables['Ventas']!.frozenRows, 5);
  });

  test('aplica formato de moneda a las columnas indicadas', () {
    final bytes = buildExcelWorkbook(definition(DateTime(2026, 8, 8)));
    final excel = Excel.decodeBytes(bytes);
    final totalCell = excel.tables['Ventas']!
        .cell(CellIndex.indexByColumnRow(rowIndex: 5, columnIndex: 1));
    final style = totalCell.cellStyle;
    expect(style, isNotNull);
    expect(style!.numberFormat.formatCode, contains(r'"$"'));
  });

  test('los valores de fecha se guardan como celdas DateTime', () {
    final bytes = buildExcelWorkbook(ReportDefinition(
      businessName: 'Mi negocio',
      currencySymbol: r'$',
      generatedAt: DateTime(2026, 8, 8),
      sheets: [
        ReportSheet(
          title: 'Turnos',
          tables: [
            ReportTable(
              headers: const ['Sucursal', 'Apertura'],
              rows: [
                ['Sucursal principal', DateTime(2026, 8, 8, 9, 0)],
              ],
            ),
          ],
        ),
      ],
    ));
    final excel = Excel.decodeBytes(bytes);
    final cell = excel.tables['Turnos']!
        .cell(CellIndex.indexByColumnRow(rowIndex: 5, columnIndex: 1))
        .value;
    expect(cell is DateTimeCellValue, isTrue);
    expect((cell as DateTimeCellValue).asDateTimeLocal(), DateTime(2026, 8, 8, 9, 0));
  });

  test('inyecta el filtro automático (autoFilter) en cada hoja', () {
    final bytes = buildExcelWorkbook(definition(DateTime(2026, 8, 8)));

    final archive = ZipDecoder().decodeBytes(bytes);
    final rels = utf8.decode(archive.findFile('xl/_rels/workbook.xml.rels')!.content as List<int>);
    final relRegex = RegExp(r'<Relationship Id="rId(\d+)"[^>]*Target="(worksheets/sheet\d+\.xml)"');
    final sheetFiles = <String>{};
    for (final m in relRegex.allMatches(rels)) {
      sheetFiles.add('xl/${m.group(2)}');
    }

    expect(sheetFiles, isNotEmpty);
    for (final path in sheetFiles) {
      final xml = utf8.decode(archive.findFile(path)!.content as List<int>);
      expect(xml, contains('<autoFilter ref="A5:'));
    }
  });
}
