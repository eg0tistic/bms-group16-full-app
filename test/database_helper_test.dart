import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:group16_bms/data/database_helper.dart';
import 'package:group16_bms/data/demo_data.dart';
import 'package:group16_bms/models/customer.dart';
import 'package:group16_bms/models/payment.dart';
import 'package:group16_bms/models/utility_payment.dart';
import 'package:group16_bms/utils/formatters.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    // Fresh in-memory database for every test.
    DatabaseHelper.databasePathOverride = inMemoryDatabasePath;
    await DatabaseHelper.resetForTests();
  });

  tearDown(() async {
    await DatabaseHelper.resetForTests();
    DatabaseHelper.databasePathOverride = null;
  });

  Future<int> seedUserAndCustomer(DatabaseHelper db) async {
    final now = Fmt.now();
    await db.insertUser({
      'email': 'a@b.sd',
      'password_hash': DatabaseHelper.hashPassword('x'),
      'role': 'admin',
      'full_name': 'Tester',
      'is_active': 1,
      'created_at': now,
      'updated_at': now,
    });
    return db.insertCustomer(Customer(name: 'Test Customer', createdAt: now));
  }

  Map<String, dynamic> invoiceMap(int customerId) {
    final now = Fmt.now();
    return {
      'invoice_number': 'PLACEHOLDER', // overwritten atomically on insert
      'customer_id': customerId,
      'created_by': 1,
      'total_amount': 100.0,
      'tax_amount': 0.0,
      'status': 'Draft',
      'is_synced': 0,
      'created_at': now,
      'updated_at': now,
    };
  }

  final item = {
    'product_id': null,
    'description': 'Item',
    'quantity': 1.0,
    'unit_price': 100.0,
    'subtotal': 100.0,
    'created_at': Fmt.now(),
  };

  test('password hashes are salted PBKDF2 and reject wrong passwords', () {
    final first = DatabaseHelper.createPasswordHash('correct horse');
    final second = DatabaseHelper.createPasswordHash('correct horse');
    expect(first, startsWith(r'pbkdf2-sha256$'));
    expect(first, isNot(second));
    expect(DatabaseHelper.verifyPassword('correct horse', first), isTrue);
    expect(DatabaseHelper.verifyPassword('wrong', first), isFalse);
  });

  test('demo data seeds valid admin and cashier accounts', () async {
    await DemoData.seed();
    expect(
      await DatabaseHelper.instance.authenticateUser(
        'admin@bms.sd',
        'admin123',
      ),
      isNotNull,
    );
    expect(
      await DatabaseHelper.instance.authenticateUser(
        'cashier@bms.sd',
        'cashier123',
      ),
      isNotNull,
    );
  });

  test('user administration protects the final active administrator', () async {
    final db = DatabaseHelper.instance;
    final adminId = await db.createUser(
      email: 'owner@example.sd',
      password: 'safe-password',
      role: 'admin',
      fullName: 'Business Owner',
    );
    expect(
      () => db.updateUserProfile(
        id: adminId,
        email: 'owner@example.sd',
        fullName: 'Business Owner',
        role: 'cashier',
        isActive: true,
        actorUserId: adminId,
      ),
      throwsA(isA<StateError>()),
    );
    expect((await db.getUserById(adminId))!.role, 'admin');
  });

  test('invoice numbers are sequential and unique', () async {
    final db = DatabaseHelper.instance;
    final customerId = await seedUserAndCustomer(db);

    final id1 = await db.insertInvoiceWithItemsAndBalance(
      invoiceMap(customerId),
      [item],
      null,
      0,
    );
    final id2 = await db.insertInvoiceWithItemsAndBalance(
      invoiceMap(customerId),
      [item],
      null,
      0,
    );
    final id3 = await db.insertInvoiceWithItemsAndBalance(
      invoiceMap(customerId),
      [item],
      null,
      0,
    );

    final n1 = (await db.getInvoiceById(id1))!.invoiceNumber;
    final n2 = (await db.getInvoiceById(id2))!.invoiceNumber;
    final n3 = (await db.getInvoiceById(id3))!.invoiceNumber;

    expect(n1, 'INV-0001');
    expect(n2, 'INV-0002');
    expect(n3, 'INV-0003');
    expect({n1, n2, n3}.length, 3); // all distinct
  });

  test('concurrent inserts never produce a duplicate number', () async {
    final db = DatabaseHelper.instance;
    final customerId = await seedUserAndCustomer(db);

    final ids = await Future.wait([
      for (var i = 0; i < 10; i++)
        db.insertInvoiceWithItemsAndBalance(
          invoiceMap(customerId),
          [item],
          null,
          0,
        ),
    ]);

    final numbers = <String>{};
    for (final id in ids) {
      numbers.add((await db.getInvoiceById(id))!.invoiceNumber);
    }
    expect(numbers.length, 10); // 10 inserts → 10 unique numbers
  });

  test('foreign keys are enforced (invalid customer rejected)', () async {
    final db = DatabaseHelper.instance;
    await seedUserAndCustomer(db); // creates customer id 1

    // customer_id 999 does not exist → FK violation should throw.
    expect(
      () =>
          db.insertInvoiceWithItemsAndBalance(invoiceMap(999), [item], null, 0),
      throwsA(isA<DatabaseException>()),
    );
  });

  test('payment settles invoice and reduces customer balance', () async {
    final db = DatabaseHelper.instance;
    final customerId = await seedUserAndCustomer(db);

    final invId = await db.insertInvoiceWithItemsAndBalance(
      {...invoiceMap(customerId), 'status': 'Confirmed'},
      [item],
      customerId,
      100.0,
    );

    await db.insertPaymentAndSettle(
      Payment(
        invoiceId: invId,
        amountPaid: 100.0,
        paymentDate: Fmt.now(),
        method: 'Cash',
        createdAt: Fmt.now(),
      ),
      customerId,
      invId,
      100.0,
    );

    final invoice = await db.getInvoiceById(invId);
    final customer = await db.getCustomerById(customerId);
    expect(invoice!.status, 'Paid');
    expect(customer!.balance, 0.0);
  });

  test('USD invoice never touches the SDG customer balance', () async {
    final db = DatabaseHelper.instance;
    final customerId = await seedUserAndCustomer(db);

    final usdMap = {...invoiceMap(customerId), 'currency': 'USD'};
    // A balance delta is requested but must be ignored for non-SDG invoices.
    final invId = await db.insertInvoiceWithItemsAndBalance(
      usdMap,
      [item],
      customerId,
      100.0,
    );
    expect((await db.getCustomerById(customerId))!.balance, 0.0);

    // Confirming must also skip the SDG ledger.
    await db.confirmInvoiceWithBalance(invId, customerId, 100.0);
    expect((await db.getCustomerById(customerId))!.balance, 0.0);

    // Payment still settles the invoice itself; ledger stays untouched.
    await db.insertPaymentAndSettle(
      Payment(
        invoiceId: invId,
        amountPaid: 100.0,
        paymentDate: Fmt.now(),
        method: 'Cash',
        createdAt: Fmt.now(),
      ),
      customerId,
      invId,
      100.0,
    );
    expect((await db.getInvoiceById(invId))!.status, 'Paid');
    expect((await db.getCustomerById(customerId))!.balance, 0.0);
  });

  test('voiding a confirmed invoice reverses the customer balance', () async {
    final db = DatabaseHelper.instance;
    final customerId = await seedUserAndCustomer(db);

    final invId = await db.insertInvoiceWithItemsAndBalance(
      invoiceMap(customerId),
      [item],
      null,
      0,
    );
    await db.confirmInvoiceWithBalance(invId, customerId, 100.0);
    expect((await db.getCustomerById(customerId))!.balance, 100.0);

    await db.voidInvoiceWithBalance(invId, customerId, 100.0, true);
    expect((await db.getInvoiceById(invId))!.status, 'Voided');
    expect((await db.getCustomerById(customerId))!.balance, 0.0);
  });

  test('partial payment keeps invoice unsettled until fully paid', () async {
    final db = DatabaseHelper.instance;
    final customerId = await seedUserAndCustomer(db);

    final invId = await db.insertInvoiceWithItemsAndBalance(
      {...invoiceMap(customerId), 'status': 'Confirmed'},
      [item],
      customerId,
      100.0,
    );

    Payment pay(double amount) => Payment(
      invoiceId: invId,
      amountPaid: amount,
      paymentDate: Fmt.now(),
      method: 'Cash',
      createdAt: Fmt.now(),
    );

    await db.insertPaymentAndSettle(pay(40.0), customerId, invId, 100.0);
    expect((await db.getInvoiceById(invId))!.status, isNot('Paid'));
    expect((await db.getCustomerById(customerId))!.balance, 60.0);

    await db.insertPaymentAndSettle(pay(60.0), customerId, invId, 100.0);
    expect((await db.getInvoiceById(invId))!.status, 'Paid');
    expect((await db.getCustomerById(customerId))!.balance, 0.0);
  });

  test(
    'database rejects overpayment even when UI validation is bypassed',
    () async {
      final db = DatabaseHelper.instance;
      final customerId = await seedUserAndCustomer(db);
      final invId = await db.insertInvoiceWithItemsAndBalance(
        {...invoiceMap(customerId), 'status': 'Confirmed'},
        [item],
        customerId,
        100,
      );
      Payment payment(double amount) => Payment(
        invoiceId: invId,
        amountPaid: amount,
        paymentDate: Fmt.now(),
        method: 'Cash',
        createdAt: Fmt.now(),
      );
      await db.insertPaymentAndSettle(payment(60), customerId, invId, 100);
      expect(
        () => db.insertPaymentAndSettle(payment(50), customerId, invId, 100),
        throwsA(isA<StateError>()),
      );
      expect(await db.getTotalPaidForInvoice(invId), 60);
      expect((await db.getCustomerById(customerId))!.balance, 40);
    },
  );

  test('payment reversal restores balance and removes revenue', () async {
    final db = DatabaseHelper.instance;
    final customerId = await seedUserAndCustomer(db);
    final invId = await db.insertInvoiceWithItemsAndBalance(
      {...invoiceMap(customerId), 'status': 'Confirmed'},
      [item],
      customerId,
      100,
    );
    await db.insertPaymentAndSettle(
      Payment(
        invoiceId: invId,
        amountPaid: 100,
        paymentDate: Fmt.now(),
        method: 'Cash',
        createdAt: Fmt.now(),
      ),
      customerId,
      invId,
      100,
    );
    final raw = await db.database;
    final paymentId =
        (await raw.rawQuery('SELECT id FROM payments WHERE invoice_id=?', [
              invId,
            ])).first['id']
            as int;
    await db.reversePayment(
      paymentId: paymentId,
      actorUserId: 1,
      reason: 'Entered twice',
    );
    expect((await db.getInvoiceById(invId))!.status, 'Confirmed');
    expect((await db.getCustomerById(customerId))!.balance, 100);
    expect(await db.getTotalPaidForInvoice(invId), 0);
    expect((await db.getReportSummary())['total_revenue'], 0);
    expect((await db.getAuditLogs()).first['action'], 'REVERSE_PAYMENT');
  });

  test('reports keep SDG and USD revenue separate', () async {
    final db = DatabaseHelper.instance;
    final customerId = await seedUserAndCustomer(db);
    for (final currency in ['SDG', 'USD']) {
      final invId = await db.insertInvoiceWithItemsAndBalance(
        {
          ...invoiceMap(customerId),
          'status': 'Confirmed',
          'currency': currency,
        },
        [item],
        currency == 'SDG' ? customerId : null,
        currency == 'SDG' ? 100 : 0,
      );
      await db.insertPaymentAndSettle(
        Payment(
          invoiceId: invId,
          amountPaid: 10,
          paymentDate: Fmt.now(),
          method: 'Cash',
          createdAt: Fmt.now(),
        ),
        customerId,
        invId,
        100,
      );
    }
    expect((await db.getReportSummary(currency: 'SDG'))['total_revenue'], 10);
    expect((await db.getReportSummary(currency: 'USD'))['total_revenue'], 10);
  });

  test(
    'utility payment is recorded and its service fee counted in reports',
    () async {
      final db = DatabaseHelper.instance;
      await seedUserAndCustomer(db); // creates user id 1

      await db.insertUtilityPayment(
        UtilityPayment(
          utilityType: 'Electricity',
          provider: 'SEDC',
          accountNumber: '12345',
          payerName: 'أحمد',
          billAmount: 850.0,
          serviceFee: 20.0,
          paymentMethod: 'Cash',
          createdBy: 1,
          createdAt: Fmt.now(),
        ),
      );
      await db.insertUtilityPayment(
        UtilityPayment(
          utilityType: 'Water',
          provider: 'State Water Corp',
          accountNumber: '67890',
          billAmount: 300.0,
          createdBy: 1,
          createdAt: Fmt.now(),
        ),
      );

      final history = await db.getUtilityPayments();
      expect(history, hasLength(2));
      final electricity = history.firstWhere(
        (p) => p.utilityType == 'Electricity',
      );
      final water = history.firstWhere((p) => p.utilityType == 'Water');
      expect(electricity.totalCollected, 870.0); // 850 bill + 20 fee
      expect(water.totalCollected, 300.0);
      expect(water.serviceFee, 0.0);

      expect(await db.getUtilityServiceFeeTotal(), 20.0);
    },
  );
}
