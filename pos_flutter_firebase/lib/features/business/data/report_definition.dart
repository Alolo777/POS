/// Modelos que describen un reporte de Excel de forma declarativa.
///
/// El servicio de exportación construye una [ReportDefinition] (datos ya
/// transformados, sin IDs internos) y el builder ([buildExcelWorkbook]) se
/// encarga únicamente de pintarla con estilo profesional.
class ReportDefinition {
  const ReportDefinition({
    required this.businessName,
    required this.currencySymbol,
    required this.generatedAt,
    required this.sheets,
  });

  /// Nombre del negocio, mostrado en el encabezado de cada hoja.
  final String businessName;

  /// Símbolo de la moneda configurada (p. ej. `$`, `€`, `£`).
  final String currencySymbol;

  /// Fecha y hora de generación del reporte.
  final DateTime generatedAt;

  /// Hojas del libro (la primera suele ser el Resumen).
  final List<ReportSheet> sheets;
}

/// Una hoja del libro, formada por una o más tablas.
///
/// La mayoría de las hojas usan una sola tabla. La hoja "Resumen" usa varias
/// (indicadores, ventas por sucursal, productos más vendidos).
class ReportSheet {
  const ReportSheet({
    required this.title,
    required this.tables,
  });

  /// Nombre de la hoja (se muestra en la pestaña de Excel).
  final String title;

  /// Tablas que se renderizan en orden (de arriba hacia abajo).
  final List<ReportTable> tables;
}

/// Una tabla rectangular con encabezado, filas y formato opcional.
class ReportTable {
  const ReportTable({
    required this.headers,
    required this.rows,
    this.caption,
    this.moneyColumns = const {},
    this.percentColumns = const {},
    this.totalsRow,
    this.boldRows = const {},
  });

  /// Título opcional de la sección (p. ej. "Ventas por sucursal").
  final String? caption;

  /// Nombres de columna (fila de encabezado).
  final List<String> headers;

  /// Filas de datos. Los valores pueden ser `String`, `int`, `double`,
  /// `bool` o `DateTime`; el builder los convierte al tipo de celda correcto.
  final List<List<Object?>> rows;

  /// Columnas (índice 0-based) que se formatean como moneda.
  final Set<int> moneyColumns;

  /// Columnas (índice 0-based) que se formatean como porcentaje.
  final Set<int> percentColumns;

  /// Fila de totales (opcional) que se dibuja al final con estilo resaltado.
  final List<Object?>? totalsRow;

  /// Índices de fila (dentro de [rows]) que se dibujan en negrita, p. ej.
  /// subtotales por sucursal.
  final Set<int> boldRows;
}
