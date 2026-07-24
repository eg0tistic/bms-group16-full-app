import 'dart:typed_data';

import 'package:printing/printing.dart';

class ShareService {
  static Future<void> shareInvoicePdf(
    Uint8List bytes,
    String invoiceNumber,
  ) async {
    await Printing.sharePdf(
      bytes: bytes,
      filename: 'invoice_$invoiceNumber.pdf',
    );
  }
}
