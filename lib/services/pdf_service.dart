import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/customer.dart';
import '../models/invoice.dart';
import '../models/payment.dart';
import '../models/utility_payment.dart';
import '../utils/app_strings.dart';
import '../utils/formatters.dart';

class PdfService {
  static const _primary = PdfColors.blue800;
  static const _primaryLight = PdfColors.blue100;
  static const _grey = PdfColors.grey700;
  static const _greyLight = PdfColors.grey100;
  static const _white = PdfColors.white;
  static const _black = PdfColors.black;

  // Cairo is bundled as an asset so PDFs render Arabic offline.
  static pw.Font? _baseFont;
  static pw.Font? _boldFont;

  // Arabic runs need explicit RTL direction on LTR (English) pages,
  // otherwise letters render disconnected and reversed.
  static final _arabic = RegExp(r'[؀-ۿ]');
  static pw.TextDirection? _dirFor(String text) =>
      _arabic.hasMatch(text) ? pw.TextDirection.rtl : null;

  static Future<void> _loadFonts() async {
    if (_baseFont != null && _boldFont != null) return;
    _baseFont = pw.Font.ttf(
      await rootBundle.load('assets/fonts/Cairo-Regular.ttf'),
    );
    _boldFont = pw.Font.ttf(
      await rootBundle.load('assets/fonts/Cairo-Bold.ttf'),
    );
  }

  static Future<Uint8List> generate({
    required Invoice invoice,
    required List<InvoiceItem> items,
    required List<Payment> payments,
    required double totalPaid,
    required String storeName,
    String storeAddress = '',
    String storePhone = '',
    String taxId = '',
    String commercialRegistration = '',
    Customer? customer,
    String lang = 'ar',
  }) async {
    await _loadFonts();
    final pdf = pw.Document();
    final remaining = invoice.grandTotal - totalPaid;
    final generatedAt = Fmt.dateTime(Fmt.now());
    final isAr = lang == 'ar';
    final currency = invoice.currency;
    String s(String key) => AppStrings.get(key, lang);
    // Letter-spacing breaks Arabic cursive joining, so only apply it in English.
    final labelSpacing = isAr ? 0.0 : 1.5;

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        textDirection: isAr ? pw.TextDirection.rtl : pw.TextDirection.ltr,
        theme: pw.ThemeData.withFont(
          base: _baseFont,
          bold: _boldFont,
          italic: _baseFont,
          boldItalic: _boldFont,
        ),
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            _header(
              storeName,
              invoice,
              s,
              labelSpacing,
              storeAddress: storeAddress,
              storePhone: storePhone,
              taxId: taxId,
              commercialRegistration: commercialRegistration,
            ),
            pw.Container(
              height: 2,
              color: _primary,
              margin: const pw.EdgeInsets.only(top: 8, bottom: 14),
            ),
            _customerSection(customer, invoice, s, labelSpacing),
            pw.SizedBox(height: 16),
            _itemsTable(items, s, currency),
            pw.SizedBox(height: 14),
            _totals(invoice, totalPaid, remaining, s, currency),
            if (payments.isNotEmpty) ...[
              pw.SizedBox(height: 14),
              _paymentHistory(payments, s, currency, labelSpacing),
            ],
            if (invoice.notes?.isNotEmpty == true) ...[
              pw.SizedBox(height: 14),
              _notes(invoice.notes!, s, labelSpacing),
            ],
            pw.Spacer(),
            pw.Container(height: 0.5, color: _grey),
            pw.SizedBox(height: 6),
            _footer(generatedAt, s),
          ],
        ),
      ),
    );

    return pdf.save();
  }

  /// A compact receipt for a utility bill (electricity/water/telecom) the
  /// shop paid on a customer's behalf. No Sudanese provider exposes a public
  /// API, so this documents the real, manual transaction rather than a live
  /// provider confirmation.
  static Future<Uint8List> generateUtilityReceipt({
    required UtilityPayment payment,
    required String storeName,
    String lang = 'ar',
  }) async {
    await _loadFonts();
    final pdf = pw.Document();
    final isAr = lang == 'ar';
    String s(String key) => AppStrings.get(key, lang);
    final labelSpacing = isAr ? 0.0 : 1.5;
    final typeKey = switch (payment.utilityType) {
      'Electricity' => 'utility_electricity',
      'Water' => 'utility_water',
      _ => 'utility_telecom',
    };
    final receiptNo = 'UTIL-${(payment.id ?? 0).toString().padLeft(6, '0')}';

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a5,
        margin: const pw.EdgeInsets.all(32),
        textDirection: isAr ? pw.TextDirection.rtl : pw.TextDirection.ltr,
        theme: pw.ThemeData.withFont(
          base: _baseFont,
          bold: _boldFont,
          italic: _baseFont,
          boldItalic: _boldFont,
        ),
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      storeName,
                      textDirection: _dirFor(storeName),
                      style: pw.TextStyle(
                        fontSize: 17,
                        fontWeight: pw.FontWeight.bold,
                        color: _primary,
                      ),
                    ),
                    pw.SizedBox(height: 3),
                    pw.Text(
                      s('utility_receipt_title'),
                      style: pw.TextStyle(
                        fontSize: 10,
                        color: _grey,
                        letterSpacing: labelSpacing,
                      ),
                    ),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text(
                      receiptNo,
                      style: pw.TextStyle(
                        fontSize: 13,
                        fontWeight: pw.FontWeight.bold,
                        color: _black,
                      ),
                    ),
                    pw.SizedBox(height: 3),
                    pw.Text(
                      '${s('pdf_date')}: ${Fmt.date(payment.createdAt)}',
                      style: const pw.TextStyle(fontSize: 9, color: _grey),
                    ),
                  ],
                ),
              ],
            ),
            pw.Container(
              height: 2,
              color: _primary,
              margin: const pw.EdgeInsets.only(top: 8, bottom: 14),
            ),
            if (payment.payerName?.isNotEmpty == true) ...[
              pw.Container(
                padding: const pw.EdgeInsets.all(10),
                decoration: const pw.BoxDecoration(
                  color: _greyLight,
                  borderRadius: pw.BorderRadius.all(pw.Radius.circular(5)),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      s('pdf_bill_to'),
                      style: pw.TextStyle(
                        fontSize: 8,
                        fontWeight: pw.FontWeight.bold,
                        color: _grey,
                        letterSpacing: labelSpacing,
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      payment.payerName!,
                      textDirection: _dirFor(payment.payerName!),
                      style: pw.TextStyle(
                        fontSize: 12,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    if (payment.payerPhone?.isNotEmpty == true) ...[
                      pw.SizedBox(height: 2),
                      _labelValue(s('pdf_phone'), payment.payerPhone!),
                    ],
                  ],
                ),
              ),
              pw.SizedBox(height: 14),
            ],
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
              columnWidths: const {
                0: pw.FlexColumnWidth(2),
                1: pw.FlexColumnWidth(3),
              },
              children: [
                _receiptRow(s('utility_bills_title'), s(typeKey)),
                _receiptRow(s('service_provider'), payment.provider),
                _receiptRow(s('account_number'), payment.accountNumber),
                _receiptRow(
                  s('payment_method'),
                  AppStrings.methodLabel(payment.paymentMethod, lang),
                ),
                if (payment.reference?.isNotEmpty == true)
                  _receiptRow(s('pdf_reference'), payment.reference!),
              ],
            ),
            pw.SizedBox(height: 14),
            pw.Align(
              alignment: pw.AlignmentDirectional.centerEnd,
              child: pw.SizedBox(
                width: 220,
                child: pw.Column(
                  children: [
                    _totalRow(
                      s('utility_bill_amount'),
                      Fmt.currency(payment.billAmount),
                    ),
                    if (payment.serviceFee > 0)
                      _totalRow(
                        s('utility_service_fee'),
                        Fmt.currency(payment.serviceFee),
                      ),
                    pw.Container(
                      height: 0.5,
                      color: _primary,
                      margin: const pw.EdgeInsets.symmetric(vertical: 4),
                    ),
                    _totalRow(
                      s('utility_total_collected'),
                      Fmt.currency(payment.totalCollected),
                      bold: true,
                    ),
                  ],
                ),
              ),
            ),
            if (payment.notes?.isNotEmpty == true) ...[
              pw.SizedBox(height: 14),
              _notes(payment.notes!, s, labelSpacing),
            ],
            pw.Spacer(),
            pw.Container(height: 0.5, color: _grey),
            pw.SizedBox(height: 6),
            _footer(Fmt.dateTime(Fmt.now()), s),
          ],
        ),
      ),
    );

    return pdf.save();
  }

  static pw.TableRow _receiptRow(String label, String value) {
    return pw.TableRow(
      children: [
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: pw.Text(
            label,
            style: pw.TextStyle(
              fontSize: 9,
              color: _grey,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
        ),
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: pw.Text(
            value,
            textDirection: _dirFor(value),
            style: const pw.TextStyle(fontSize: 10),
          ),
        ),
      ],
    );
  }

  // ── Header ────────────────────────────────────────────────────────────────

  static pw.Widget _header(
    String storeName,
    Invoice invoice,
    String Function(String) s,
    double labelSpacing, {
    required String storeAddress,
    required String storePhone,
    required String taxId,
    required String commercialRegistration,
  }) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              storeName,
              textDirection: _dirFor(storeName),
              style: pw.TextStyle(
                fontSize: 20,
                fontWeight: pw.FontWeight.bold,
                color: _primary,
              ),
            ),
            pw.SizedBox(height: 3),
            pw.Text(
              invoice.taxAmount > 0 ? s('pdf_tax_invoice') : s('pdf_invoice'),
              style: pw.TextStyle(
                fontSize: 11,
                color: _grey,
                letterSpacing: labelSpacing,
              ),
            ),
            if (storeAddress.isNotEmpty) ...[
              pw.SizedBox(height: 2),
              _labelValue(s('pdf_address'), storeAddress),
            ],
            if (storePhone.isNotEmpty) ...[
              pw.SizedBox(height: 2),
              _labelValue(s('pdf_phone'), storePhone),
            ],
            if (taxId.isNotEmpty) ...[
              pw.SizedBox(height: 2),
              _labelValue(s('pdf_tax_id'), taxId),
            ],
            if (commercialRegistration.isNotEmpty) ...[
              pw.SizedBox(height: 2),
              _labelValue(
                s('pdf_commercial_registration'),
                commercialRegistration,
              ),
            ],
          ],
        ),
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            pw.Text(
              invoice.invoiceNumber,
              style: pw.TextStyle(
                fontSize: 16,
                fontWeight: pw.FontWeight.bold,
                color: _black,
              ),
            ),
            pw.SizedBox(height: 3),
            pw.Text(
              '${s('pdf_date')}: ${Fmt.date(invoice.createdAt)}',
              style: const pw.TextStyle(fontSize: 10, color: _grey),
            ),
            pw.SizedBox(height: 5),
            _statusBadge(invoice.status, s),
          ],
        ),
      ],
    );
  }

  static pw.Widget _statusBadge(String status, String Function(String) s) {
    final color = switch (status) {
      'Confirmed' => PdfColors.blue800,
      'Paid' => PdfColors.green800,
      'Voided' => PdfColors.red800,
      'Closed' => PdfColors.blueGrey800,
      _ => PdfColors.grey700,
    };
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: pw.BoxDecoration(
        color: color,
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(3)),
      ),
      child: pw.Text(
        s('status_${status.toLowerCase()}'),
        style: pw.TextStyle(
          color: _white,
          fontSize: 9,
          fontWeight: pw.FontWeight.bold,
        ),
      ),
    );
  }

  // ── Customer ──────────────────────────────────────────────────────────────

  static pw.Widget _customerSection(
    Customer? customer,
    Invoice invoice,
    String Function(String) s,
    double labelSpacing,
  ) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: const pw.BoxDecoration(
        color: _greyLight,
        borderRadius: pw.BorderRadius.all(pw.Radius.circular(5)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            s('pdf_bill_to'),
            style: pw.TextStyle(
              fontSize: 9,
              fontWeight: pw.FontWeight.bold,
              color: _grey,
              letterSpacing: labelSpacing,
            ),
          ),
          pw.SizedBox(height: 5),
          pw.Text(
            invoice.customerName ?? 'N/A',
            textDirection: _dirFor(invoice.customerName ?? ''),
            style: pw.TextStyle(
              fontSize: 13,
              fontWeight: pw.FontWeight.bold,
              color: _black,
            ),
          ),
          if (customer?.phone.isNotEmpty == true) ...[
            pw.SizedBox(height: 2),
            _labelValue(s('pdf_phone'), customer!.phone),
          ],
          if (customer?.address.isNotEmpty == true) ...[
            pw.SizedBox(height: 2),
            _labelValue(s('pdf_address'), customer!.address),
          ],
        ],
      ),
    );
  }

  // ── Items table ───────────────────────────────────────────────────────────

  static pw.Widget _itemsTable(
    List<InvoiceItem> items,
    String Function(String) s,
    String currency,
  ) {
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
      columnWidths: const {
        0: pw.FlexColumnWidth(3.5),
        1: pw.FlexColumnWidth(1),
        2: pw.FlexColumnWidth(2),
        3: pw.FlexColumnWidth(2),
      },
      children: [
        _tableHeaderRow([
          s('pdf_description'),
          s('pdf_qty'),
          s('pdf_unit_price'),
          s('pdf_total'),
        ]),
        for (int i = 0; i < items.length; i++)
          pw.TableRow(
            decoration: pw.BoxDecoration(color: i.isEven ? _white : _greyLight),
            children: [
              _cell(items[i].description),
              _cell(_qtyStr(items[i].quantity), align: pw.TextAlign.center),
              _cell(Fmt.currency(items[i].unitPrice, currency)),
              _cell(Fmt.currency(items[i].subtotal, currency)),
            ],
          ),
      ],
    );
  }

  static pw.TableRow _tableHeaderRow(List<String> labels) {
    return pw.TableRow(
      decoration: const pw.BoxDecoration(color: _primary),
      children: labels
          .map(
            (l) => pw.Padding(
              padding: const pw.EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 6,
              ),
              child: pw.Text(
                l,
                style: pw.TextStyle(
                  color: _white,
                  fontWeight: pw.FontWeight.bold,
                  fontSize: 10,
                ),
              ),
            ),
          )
          .toList(),
    );
  }

  static pw.Widget _cell(String text, {pw.TextAlign? align}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      child: pw.Text(
        text,
        style: const pw.TextStyle(fontSize: 10),
        textAlign: align,
        textDirection: _dirFor(text),
      ),
    );
  }

  // Renders "label: value" so an Arabic value stays readable on an
  // English page (and vice versa) instead of being reversed by bidi.
  static pw.Widget _labelValue(String label, String value) {
    return pw.Row(
      mainAxisSize: pw.MainAxisSize.min,
      children: [
        pw.Text(
          '$label: ',
          style: const pw.TextStyle(fontSize: 10, color: _grey),
        ),
        pw.Text(
          value,
          textDirection: _dirFor(value),
          style: const pw.TextStyle(fontSize: 10, color: _grey),
        ),
      ],
    );
  }

  // ── Totals ────────────────────────────────────────────────────────────────

  static pw.Widget _totals(
    Invoice invoice,
    double totalPaid,
    double remaining,
    String Function(String) s,
    String currency,
  ) {
    return pw.Align(
      alignment: pw.AlignmentDirectional.centerEnd,
      child: pw.SizedBox(
        width: 220,
        child: pw.Column(
          children: [
            _totalRow(
              s('pdf_subtotal'),
              Fmt.currency(invoice.totalAmount, currency),
            ),
            if (invoice.taxAmount > 0)
              _totalRow(
                '${s('pdf_vat')} (${(invoice.taxRate * 100).toStringAsFixed(invoice.taxRate * 100 % 1 == 0 ? 0 : 2)}%)',
                Fmt.currency(invoice.taxAmount, currency),
              ),
            pw.Container(
              height: 0.5,
              color: _primary,
              margin: const pw.EdgeInsets.symmetric(vertical: 4),
            ),
            _totalRow(
              s('pdf_grand_total'),
              Fmt.currency(invoice.grandTotal, currency),
              bold: true,
            ),
            _totalRow(
              s('pdf_paid'),
              Fmt.currency(totalPaid, currency),
              color: PdfColors.green800,
            ),
            if (remaining > 0.01)
              _totalRow(
                s('pdf_remaining'),
                Fmt.currency(remaining, currency),
                color: PdfColors.red700,
              ),
          ],
        ),
      ),
    );
  }

  static pw.Widget _totalRow(
    String label,
    String value, {
    bool bold = false,
    PdfColor? color,
  }) {
    final style = pw.TextStyle(
      fontSize: bold ? 12 : 10,
      fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
      color: color ?? _black,
    );
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: style),
          pw.Text(value, style: style),
        ],
      ),
    );
  }

  // ── Payment history ───────────────────────────────────────────────────────

  static pw.Widget _paymentHistory(
    List<Payment> payments,
    String Function(String) s,
    String currency,
    double labelSpacing,
  ) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          s('pdf_payment_history'),
          style: pw.TextStyle(
            fontSize: 9,
            fontWeight: pw.FontWeight.bold,
            color: _grey,
            letterSpacing: labelSpacing,
          ),
        ),
        pw.SizedBox(height: 6),
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
          columnWidths: const {
            0: pw.FlexColumnWidth(2),
            1: pw.FlexColumnWidth(2),
            2: pw.FlexColumnWidth(2.5),
            3: pw.FlexColumnWidth(2),
          },
          children: [
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: _primaryLight),
              children:
                  [
                        s('pdf_method'),
                        s('pdf_date'),
                        s('pdf_reference'),
                        s('pdf_amount'),
                      ]
                      .map(
                        (l) => pw.Padding(
                          padding: const pw.EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 5,
                          ),
                          child: pw.Text(
                            l,
                            style: pw.TextStyle(
                              color: _primary,
                              fontWeight: pw.FontWeight.bold,
                              fontSize: 9,
                            ),
                          ),
                        ),
                      )
                      .toList(),
            ),
            for (final p in payments)
              pw.TableRow(
                children: [
                  _cell(p.method),
                  _cell(Fmt.date(p.paymentDate)),
                  _cell(p.notes ?? '—'),
                  _cell(Fmt.currency(p.amountPaid, currency)),
                ],
              ),
          ],
        ),
      ],
    );
  }

  // ── Notes ─────────────────────────────────────────────────────────────────

  static pw.Widget _notes(
    String notes,
    String Function(String) s,
    double labelSpacing,
  ) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300, width: 0.5),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            s('pdf_notes'),
            style: pw.TextStyle(
              fontSize: 8,
              fontWeight: pw.FontWeight.bold,
              color: _grey,
              letterSpacing: labelSpacing,
            ),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            notes,
            textDirection: _dirFor(notes),
            style: const pw.TextStyle(fontSize: 10),
          ),
        ],
      ),
    );
  }

  // ── Footer ────────────────────────────────────────────────────────────────

  static pw.Widget _footer(String generatedAt, String Function(String) s) {
    return pw.Column(
      children: [
        pw.Text(
          s('pdf_thanks'),
          style: pw.TextStyle(
            fontSize: 10,
            color: _primary,
            fontStyle: pw.FontStyle.italic,
          ),
          textAlign: pw.TextAlign.center,
        ),
        pw.SizedBox(height: 3),
        pw.Text(
          '${s('pdf_generated_at')}: $generatedAt',
          style: const pw.TextStyle(fontSize: 8, color: _grey),
          textAlign: pw.TextAlign.center,
        ),
      ],
    );
  }

  // ── Helper ────────────────────────────────────────────────────────────────

  static String _qtyStr(double qty) {
    return qty == qty.truncateToDouble()
        ? qty.toInt().toString()
        : qty.toStringAsFixed(2);
  }
}
