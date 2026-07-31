import 'dart:typed_data';

import '../../../shared/models/sale.dart';
import '../../../shared/models/store.dart';

abstract class PdfRepository {
  Future<Uint8List> generateTicketPdf({
    required String businessName,
    required Store store,
    required Sale sale,
  });
}
