import 'package:excel_community/excel_community.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:pos_flutter_firebase/features/business/data/excel_book_builder.dart';

void main() {
  test('buildExcelWorkbook genera un archivo xlsx valido con las hojas y filas', () {
    final bytes = buildExcelWorkbook([
      ExcelSheetData(
        title: 'Ventas',
        headers: const ['folio', 'total'],
        rows: const [
          ['V-001', 120.5],
          ['V-002', null],
        ],
      ),
      ExcelSheetData(
        title: 'Productos',
        headers: const ['nombre', 'activo'],
        rows: const [
          ['Pollo', true],
        ],
      ),
    ]);

    expect(bytes, isNotNull);
    expect(bytes.length, greaterThan(0));

    final excel = Excel.decodeBytes(bytes);
    expect(excel.tables.containsKey('Ventas'), isTrue);
    expect(excel.tables.containsKey('Productos'), isTrue);
    expect(excel.tables.containsKey('Sheet1'), isFalse);

    final sales = excel.tables['Ventas']!;
    expect(sales.maxRows, 3);

    final header = sales.cell(CellIndex.indexByColumnRow(rowIndex: 0, columnIndex: 0)).value;
    expect(header is TextCellValue, isTrue);
    expect((header as TextCellValue).value.text, 'folio');

    final folioCell = sales.cell(CellIndex.indexByColumnRow(rowIndex: 1, columnIndex: 0)).value;
    expect(folioCell is TextCellValue, isTrue);
    expect((folioCell as TextCellValue).value.text, 'V-001');

    final totalCell = sales.cell(CellIndex.indexByColumnRow(rowIndex: 1, columnIndex: 1)).value;
    expect(totalCell is DoubleCellValue, isTrue);
    expect((totalCell as DoubleCellValue).value, 120.5);

    final nullCell = sales.cell(CellIndex.indexByColumnRow(rowIndex: 2, columnIndex: 1)).value;
    expect(nullCell, isNull);

    final products = excel.tables['Productos']!;
    expect(products.maxRows, 2);
    final activeCell =
        products.cell(CellIndex.indexByColumnRow(rowIndex: 1, columnIndex: 1)).value;
    expect(activeCell is BoolCellValue, isTrue);
    expect((activeCell as BoolCellValue).value, isTrue);
  });
}
