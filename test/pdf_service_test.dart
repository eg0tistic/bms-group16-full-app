import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:group16_bms/models/customer.dart';
import 'package:group16_bms/models/invoice.dart';
import 'package:group16_bms/models/payment.dart';
import 'package:group16_bms/models/utility_payment.dart';
import 'package:group16_bms/services/pdf_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const invoice = Invoice(
    id: 1,
    invoiceNumber: 'INV-0001',
    customerId: 1,
    customerName: 'محمد أحمد عبدالله',
    createdBy: 1,
    totalAmount: 12500,
    taxAmount: 2125,
    currency: 'SDG',
    notes: 'الدفع عند الاستلام',
    status: 'Confirmed',
    createdAt: '2026-07-01 10:00:00',
  );

  const items = [
    InvoiceItem(
      invoiceId: 1,
      description: 'شاي الغزالتين ٥٠٠ جرام',
      quantity: 3,
      unitPrice: 2500,
      subtotal: 7500,
    ),
    InvoiceItem(
      invoiceId: 1,
      description: 'سكر كيلو',
      quantity: 5,
      unitPrice: 1000,
      subtotal: 5000,
    ),
  ];

  const payments = [
    Payment(
      invoiceId: 1,
      amountPaid: 5000,
      paymentDate: '2026-07-01 12:00:00',
      method: 'Bankak',
    ),
  ];

  const customer = Customer(
    id: 1,
    name: 'محمد أحمد عبدالله',
    phone: '0912345678',
    address: 'الخرطوم - السوق العربي',
    balance: 9625,
  );

  test('generates an Arabic invoice PDF with bundled font', () async {
    final bytes = await PdfService.generate(
      invoice: invoice,
      items: items,
      payments: payments,
      totalPaid: 5000,
      storeName: 'متجر النيل',
      customer: customer,
      lang: 'ar',
    );
    expect(bytes.length, greaterThan(5000));
    final file = File('${Directory.systemTemp.path}/bms_invoice_ar_smoke.pdf');
    await file.writeAsBytes(bytes);
  });

  test('generates an English invoice PDF', () async {
    final bytes = await PdfService.generate(
      invoice: invoice,
      items: items,
      payments: payments,
      totalPaid: 5000,
      storeName: 'Nile Store',
      customer: customer,
      lang: 'en',
    );
    expect(bytes.length, greaterThan(5000));
    final file = File('${Directory.systemTemp.path}/bms_invoice_en_smoke.pdf');
    await file.writeAsBytes(bytes);
  });

  const utilityPayment = UtilityPayment(
    id: 7,
    utilityType: 'Electricity',
    provider: 'SEDC',
    accountNumber: '445566',
    payerName: 'أحمد محمد علي',
    payerPhone: '0912345678',
    billAmount: 850,
    serviceFee: 20,
    paymentMethod: 'Bankak',
    reference: 'BK-99213',
    notes: 'دفعة شهر يوليو',
    createdBy: 1,
    createdAt: '2026-07-01 10:00:00',
  );

  test('generates an Arabic utility bill receipt with bundled font', () async {
    final bytes = await PdfService.generateUtilityReceipt(
      payment: utilityPayment,
      storeName: 'متجر النيل',
      lang: 'ar',
    );
    expect(bytes.length, greaterThan(2000));
    final file = File(
      '${Directory.systemTemp.path}/bms_utility_receipt_ar_smoke.pdf',
    );
    await file.writeAsBytes(bytes);
  });

  test('generates an English utility bill receipt', () async {
    final bytes = await PdfService.generateUtilityReceipt(
      payment: utilityPayment,
      storeName: 'Nile Store',
      lang: 'en',
    );
    expect(bytes.length, greaterThan(2000));
    final file = File(
      '${Directory.systemTemp.path}/bms_utility_receipt_en_smoke.pdf',
    );
    await file.writeAsBytes(bytes);
  });
}
