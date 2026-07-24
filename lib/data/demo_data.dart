import 'package:flutter/foundation.dart';

import '../models/customer.dart';
import '../models/payment.dart';
import '../models/product.dart';
import '../utils/formatters.dart';
import 'database_helper.dart';

class DemoData {
  static Future<void> seed() async {
    final db = DatabaseHelper.instance;

    final existing = await db.getAllUsers();
    if (existing.isNotEmpty) {
      // Only refresh the demo payment date during development. In release
      // builds we never rewrite payment dates, so real merchant revenue
      // history is never altered.
      if (kDebugMode) await _keepPaymentCurrent();
      return;
    }

    final now = Fmt.now();

    // ─── Settings ────────────────────────────────────────────────────
    await db.setSetting('language', 'ar');
    await db.setSetting('store_name', 'نظام الفوترة');
    await db.setSetting('vat_enabled', '1');
    await db.setSetting('last_synced_at', '');

    // ─── Users ────────────────────────────────────────────────────────
    await db.createUser(
      email: 'admin@bms.sd',
      password: 'admin123',
      role: 'admin',
      fullName: 'مدير النظام',
    );

    await db.createUser(
      email: 'cashier@bms.sd',
      password: 'cashier123',
      role: 'cashier',
      fullName: 'أمين الصندوق',
    );

    // ─── Customers ────────────────────────────────────────────────────
    final c1Id = await db.insertCustomer(
      Customer(
        name: 'محمد أحمد عبدالله',
        phone: '0912345678',
        address: 'الخرطوم، حي الرياض',
        createdAt: now,
      ),
    );

    await db.insertCustomer(
      Customer(
        name: 'فاطمة عمر محمود',
        phone: '0923456789',
        address: 'أم درمان، السوق',
        createdAt: now,
      ),
    );

    await db.insertCustomer(
      Customer(
        name: 'أحمد سعد الدين',
        phone: '0934567890',
        address: 'بحري، الكدرو',
        createdAt: now,
      ),
    );

    // ─── Products ─────────────────────────────────────────────────────
    final p1Id = await db.insertProduct(
      Product(
        name: 'شاي أحمر',
        category: 'مشروبات',
        price: 2500.0,
        unit: 'كيلو',
        createdAt: now,
      ),
    );

    final p2Id = await db.insertProduct(
      Product(
        name: 'سكر',
        category: 'مواد غذائية',
        price: 1800.0,
        unit: 'كيلو',
        createdAt: now,
      ),
    );

    await db.insertProduct(
      Product(
        name: 'زيت طعام',
        category: 'مواد غذائية',
        price: 4500.0,
        unit: 'لتر',
        createdAt: now,
      ),
    );

    await db.insertProduct(
      Product(
        name: 'بن',
        category: 'مشروبات',
        price: 3200.0,
        unit: 'كيلو',
        createdAt: now,
      ),
    );

    await db.insertProduct(
      Product(
        name: 'ورق A4',
        category: 'مستلزمات مكتبية',
        price: 2800.0,
        unit: 'رزمة',
        createdAt: now,
      ),
    );

    // ─── Invoice INV-0001 ─────────────────────────────────────────────
    // شاي أحمر × 2 = 5000, سكر × 3 = 5400 → total 10400, tax 17% = 1768
    const double item1Sub = 2 * 2500.0; // 5000
    const double item2Sub = 3 * 1800.0; // 5400
    const double totalAmount = item1Sub + item2Sub; // 10400
    const double taxAmount = totalAmount * 0.17; // 1768

    // Number is allocated atomically by the DB layer (yields INV-0001 on a
    // fresh database); we no longer hard-code it here.
    final invoiceId = await db.insertInvoiceWithItemsAndBalance(
      {
        'customer_id': c1Id,
        'created_by': 1,
        'total_amount': totalAmount,
        'tax_amount': taxAmount,
        'notes': 'فاتورة تجريبية',
        'status': 'Confirmed',
        'is_synced': 0,
        'created_at': now,
        'updated_at': now,
      },
      [
        {
          'product_id': p1Id,
          'description': 'شاي أحمر',
          'quantity': 2.0,
          'unit_price': 2500.0,
          'subtotal': item1Sub,
          'created_at': now,
        },
        {
          'product_id': p2Id,
          'description': 'سكر',
          'quantity': 3.0,
          'unit_price': 1800.0,
          'subtotal': item2Sub,
          'created_at': now,
        },
      ],
      null, // balance is set explicitly below after the partial payment
      0,
    );

    // ─── Payment ──────────────────────────────────────────────────────
    await db.insertPayment(
      Payment(
        invoiceId: invoiceId,
        amountPaid: 5000.0,
        paymentDate: now,
        method: 'Cash',
        notes: 'دفعة جزئية',
        createdAt: now,
      ),
    );

    // Outstanding balance = grand total - paid = 12168 - 5000 = 7168
    final outstanding = totalAmount + taxAmount - 5000.0;
    await db.updateCustomerBalance(c1Id, outstanding);

    if (kDebugMode) debugPrint('[BMS] Database seeded successfully');
  }

  // Keeps the demo payment dated today so "today's revenue" always shows on the dashboard.
  // Only touches payments linked to the seeded INV-0001 invoice.
  static Future<void> _keepPaymentCurrent() async {
    final rawDb = await DatabaseHelper.instance.database;
    await rawDb.rawUpdate(
      'UPDATE payments SET payment_date = ? '
      "WHERE invoice_id = (SELECT id FROM invoices WHERE invoice_number = 'INV-0001')",
      [Fmt.now()],
    );
  }
}
