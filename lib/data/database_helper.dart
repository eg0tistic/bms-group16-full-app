import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../models/app_user.dart';
import '../models/cash_drawer_session.dart';
import '../models/customer.dart';
import '../models/invoice.dart';
import '../models/payment.dart';
import '../models/product.dart';
import '../models/utility_payment.dart';
import '../utils/formatters.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._();
  static Database? _db;

  // When set, the database opens here instead of sqflite's default location.
  // Tests point it at an in-memory database (with [resetForTests]); on desktop
  // startup it is pinned to the per-app data directory so the database does
  // not move with the process working directory.
  static String? databasePathOverride;

  DatabaseHelper._();

  static Future<void> resetForTests() async {
    await _db?.close();
    _db = null;
  }

  // ─── Password ─────────────────────────────────────────────────────

  /// Legacy SHA-256 helper retained only so existing installations can sign in
  /// once and be upgraded transparently to the salted PBKDF2 format.
  static String hashPassword(String password) {
    final bytes = utf8.encode(password);
    return sha256.convert(bytes).toString();
  }

  static const int _passwordIterations = 120000;

  static String createPasswordHash(String password) {
    final salt = List<int>.generate(16, (_) => Random.secure().nextInt(256));
    final derived = _pbkdf2(utf8.encode(password), salt, _passwordIterations);
    return 'pbkdf2-sha256\$$_passwordIterations\$${base64UrlEncode(salt)}\$${base64UrlEncode(derived)}';
  }

  static bool verifyPassword(String password, String stored) {
    if (!stored.startsWith('pbkdf2-sha256\$')) {
      return _constantTimeEquals(
        utf8.encode(hashPassword(password)),
        utf8.encode(stored),
      );
    }
    final parts = stored.split('\$');
    if (parts.length != 4) return false;
    final iterations = int.tryParse(parts[1]);
    if (iterations == null || iterations < 10000 || iterations > 1000000) {
      return false;
    }
    try {
      final salt = base64Url.decode(base64Url.normalize(parts[2]));
      final expected = base64Url.decode(base64Url.normalize(parts[3]));
      final actual = _pbkdf2(
        utf8.encode(password),
        salt,
        iterations,
        length: expected.length,
      );
      return _constantTimeEquals(actual, expected);
    } on FormatException {
      return false;
    }
  }

  static List<int> _pbkdf2(
    List<int> password,
    List<int> salt,
    int iterations, {
    int length = 32,
  }) {
    final hmac = Hmac(sha256, password);
    final output = <int>[];
    for (var block = 1; output.length < length; block++) {
      final blockBytes = [
        ...salt,
        (block >> 24) & 0xff,
        (block >> 16) & 0xff,
        (block >> 8) & 0xff,
        block & 0xff,
      ];
      var u = hmac.convert(blockBytes).bytes;
      final t = List<int>.from(u);
      for (var i = 1; i < iterations; i++) {
        u = hmac.convert(u).bytes;
        for (var j = 0; j < t.length; j++) {
          t[j] ^= u[j];
        }
      }
      output.addAll(t);
    }
    return output.sublist(0, length);
  }

  static bool _constantTimeEquals(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    var diff = 0;
    for (var i = 0; i < a.length; i++) {
      diff |= a[i] ^ b[i];
    }
    return diff == 0;
  }

  // ─── Init ─────────────────────────────────────────────────────────

  Future<Database> get database async {
    _db ??= await _initDb();
    return _db!;
  }

  Future<Database> _initDb() async {
    final path =
        databasePathOverride ?? join(await getDatabasesPath(), 'bms.db');
    return openDatabase(
      path,
      version: 5,
      onConfigure: _onConfigure,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onConfigure(Database db) async {
    await db.execute('PRAGMA foreign_keys = ON');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await _createIndexes(db);
    }
    if (oldVersion < 3) {
      // Phase 3: multi-currency, credit/بالآجل due dates, cash drawer.
      await db.execute(
        "ALTER TABLE invoices ADD COLUMN currency TEXT NOT NULL DEFAULT 'SDG'",
      );
      await db.execute('ALTER TABLE invoices ADD COLUMN due_date TEXT');
      await db.execute(
        'ALTER TABLE customers ADD COLUMN credit_limit REAL NOT NULL DEFAULT 0',
      );
      await db.execute(_cashDrawerTableSql);
    }
    if (oldVersion < 4) {
      // Utility bill payments: a real local ledger of bills the shop paid on
      // a customer's behalf (no Sudanese utility exposes a public API).
      await db.execute(_utilityPaymentsTableSql);
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_utility_payments_created ON utility_payments(created_at)',
      );
    }
    if (oldVersion < 5) {
      await db.execute(
        'ALTER TABLE invoices ADD COLUMN tax_rate REAL NOT NULL DEFAULT 0',
      );
      await db.execute('ALTER TABLE payments ADD COLUMN reversed_at TEXT');
      await db.execute('ALTER TABLE payments ADD COLUMN reversed_by INTEGER');
      await db.execute('ALTER TABLE payments ADD COLUMN reversal_reason TEXT');
      await db.execute(_auditLogsTableSql);
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_audit_logs_created ON audit_logs(created_at)',
      );
    }
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''CREATE TABLE users (
      id            INTEGER PRIMARY KEY AUTOINCREMENT,
      email         TEXT UNIQUE NOT NULL,
      password_hash TEXT NOT NULL,
      role          TEXT NOT NULL,
      full_name     TEXT,
      is_active     INTEGER DEFAULT 1,
      is_synced     INTEGER DEFAULT 0,
      remote_id     TEXT,
      created_at    TEXT,
      updated_at    TEXT
    )''');

    await db.execute('''CREATE TABLE customers (
      id           INTEGER PRIMARY KEY AUTOINCREMENT,
      name         TEXT NOT NULL,
      phone        TEXT,
      address      TEXT,
      balance      REAL DEFAULT 0,
      credit_limit REAL NOT NULL DEFAULT 0,
      is_active    INTEGER DEFAULT 1,
      is_synced    INTEGER DEFAULT 0,
      remote_id    TEXT,
      created_at   TEXT,
      updated_at   TEXT
    )''');

    await db.execute('''CREATE TABLE products (
      id          INTEGER PRIMARY KEY AUTOINCREMENT,
      name        TEXT NOT NULL,
      category    TEXT,
      price       REAL NOT NULL,
      unit        TEXT,
      is_active   INTEGER DEFAULT 1,
      is_synced   INTEGER DEFAULT 0,
      remote_id   TEXT,
      created_at  TEXT,
      updated_at  TEXT
    )''');

    await db.execute('''CREATE TABLE invoices (
      id             INTEGER PRIMARY KEY AUTOINCREMENT,
      invoice_number TEXT UNIQUE NOT NULL,
      customer_id    INTEGER NOT NULL,
      created_by     INTEGER NOT NULL,
      total_amount   REAL DEFAULT 0,
      tax_amount     REAL DEFAULT 0,
      tax_rate       REAL NOT NULL DEFAULT 0,
      currency       TEXT NOT NULL DEFAULT 'SDG',
      due_date       TEXT,
      notes          TEXT,
      status         TEXT DEFAULT 'Draft',
      is_synced      INTEGER DEFAULT 0,
      remote_id      TEXT,
      created_at     TEXT,
      updated_at     TEXT,
      FOREIGN KEY (customer_id) REFERENCES customers(id),
      FOREIGN KEY (created_by)  REFERENCES users(id)
    )''');

    await db.execute('''CREATE TABLE invoice_items (
      id          INTEGER PRIMARY KEY AUTOINCREMENT,
      invoice_id  INTEGER NOT NULL,
      product_id  INTEGER,
      description TEXT NOT NULL,
      quantity    REAL NOT NULL,
      unit_price  REAL NOT NULL,
      subtotal    REAL NOT NULL,
      created_at  TEXT,
      FOREIGN KEY (invoice_id) REFERENCES invoices(id)
    )''');

    await db.execute('''CREATE TABLE payments (
      id           INTEGER PRIMARY KEY AUTOINCREMENT,
      invoice_id   INTEGER NOT NULL,
      amount_paid  REAL NOT NULL,
      payment_date TEXT NOT NULL,
      method       TEXT DEFAULT 'Cash',
      notes        TEXT,
      is_synced    INTEGER DEFAULT 0,
      remote_id    TEXT,
      created_at   TEXT,
      reversed_at TEXT,
      reversed_by INTEGER,
      reversal_reason TEXT,
      FOREIGN KEY (invoice_id) REFERENCES invoices(id)
    )''');

    await db.execute('''CREATE TABLE settings (
      id          INTEGER PRIMARY KEY AUTOINCREMENT,
      key         TEXT UNIQUE NOT NULL,
      value       TEXT,
      updated_at  TEXT
    )''');

    await db.execute('''CREATE TABLE sync_queue (
      id          INTEGER PRIMARY KEY AUTOINCREMENT,
      table_name  TEXT NOT NULL,
      record_id   INTEGER NOT NULL,
      operation   TEXT NOT NULL,
      payload     TEXT NOT NULL,
      synced_at   TEXT,
      created_at  TEXT
    )''');

    await db.execute(_cashDrawerTableSql);
    await db.execute(_utilityPaymentsTableSql);
    await db.execute(_auditLogsTableSql);

    await _createIndexes(db);
  }

  // Shared by onCreate (fresh installs) and onUpgrade (v2 → v3) so the two
  // paths can never drift.
  static const _cashDrawerTableSql = '''CREATE TABLE cash_drawer_sessions (
      id              INTEGER PRIMARY KEY AUTOINCREMENT,
      opened_by       INTEGER NOT NULL,
      opening_balance REAL NOT NULL DEFAULT 0,
      expected_cash   REAL DEFAULT 0,
      closing_balance REAL,
      variance        REAL,
      status          TEXT NOT NULL DEFAULT 'Open',
      opened_at       TEXT NOT NULL,
      closed_at       TEXT,
      notes           TEXT,
      is_synced       INTEGER DEFAULT 0,
      remote_id       TEXT,
      created_at      TEXT,
      FOREIGN KEY (opened_by) REFERENCES users(id)
    )''';

  // Shared by onCreate (fresh installs) and onUpgrade (v3 → v4) so the two
  // paths can never drift. A real local ledger of utility bills (electricity,
  // water, telecom) the shop paid to the provider on a customer's behalf —
  // no Sudanese utility exposes a public API, so this is the paper trail for
  // that manual, in-person payment, not a live provider connection.
  static const _utilityPaymentsTableSql = '''CREATE TABLE utility_payments (
      id             INTEGER PRIMARY KEY AUTOINCREMENT,
      utility_type   TEXT NOT NULL,
      provider       TEXT NOT NULL,
      account_number TEXT NOT NULL,
      payer_name     TEXT,
      payer_phone    TEXT,
      bill_amount    REAL NOT NULL,
      service_fee    REAL NOT NULL DEFAULT 0,
      payment_method TEXT NOT NULL DEFAULT 'Cash',
      reference      TEXT,
      notes          TEXT,
      created_by     INTEGER NOT NULL,
      is_synced      INTEGER DEFAULT 0,
      remote_id      TEXT,
      created_at     TEXT,
      FOREIGN KEY (created_by) REFERENCES users(id)
    )''';

  static const _auditLogsTableSql = '''CREATE TABLE audit_logs (
      id          INTEGER PRIMARY KEY AUTOINCREMENT,
      user_id     INTEGER,
      action      TEXT NOT NULL,
      entity_type TEXT NOT NULL,
      entity_id   INTEGER,
      details     TEXT,
      created_at  TEXT NOT NULL,
      FOREIGN KEY (user_id) REFERENCES users(id)
    )''';

  // Indexes for the columns we filter and sort on most. Created on fresh
  // installs and applied to existing databases via onUpgrade.
  Future<void> _createIndexes(Database db) async {
    const statements = [
      'CREATE INDEX IF NOT EXISTS idx_customers_active_name ON customers(is_active, name)',
      'CREATE INDEX IF NOT EXISTS idx_products_active_name ON products(is_active, name)',
      'CREATE INDEX IF NOT EXISTS idx_invoices_status_created ON invoices(status, created_at)',
      'CREATE INDEX IF NOT EXISTS idx_invoices_customer ON invoices(customer_id)',
      'CREATE INDEX IF NOT EXISTS idx_invoice_items_invoice ON invoice_items(invoice_id)',
      'CREATE INDEX IF NOT EXISTS idx_payments_invoice ON payments(invoice_id)',
      'CREATE INDEX IF NOT EXISTS idx_payments_date ON payments(payment_date)',
      'CREATE INDEX IF NOT EXISTS idx_sync_queue_pending ON sync_queue(synced_at, created_at)',
      'CREATE INDEX IF NOT EXISTS idx_utility_payments_created ON utility_payments(created_at)',
      'CREATE INDEX IF NOT EXISTS idx_audit_logs_created ON audit_logs(created_at)',
    ];
    for (final sql in statements) {
      await db.execute(sql);
    }
  }

  // ─── Users ────────────────────────────────────────────────────────

  Future<int> insertUser(Map<String, dynamic> user) async {
    final db = await database;
    return db.insert('users', user);
  }

  Future<AppUser?> authenticateUser(String email, String password) async {
    final db = await database;
    final rows = await db.query(
      'users',
      where: 'LOWER(email) = LOWER(?) AND is_active = 1',
      whereArgs: [email.trim()],
    );
    if (rows.isEmpty) return null;
    final row = rows.first;
    final stored = row['password_hash'] as String;
    if (!verifyPassword(password, stored)) return null;

    // Upgrade legacy unsalted SHA-256 credentials after a successful login.
    if (!stored.startsWith('pbkdf2-sha256\$')) {
      await db.update(
        'users',
        {
          'password_hash': createPasswordHash(password),
          'updated_at': Fmt.now(),
        },
        where: 'id = ?',
        whereArgs: [row['id']],
      );
    }
    return AppUser.fromMap(row);
  }

  Future<AppUser?> getUserById(int id) async {
    final db = await database;
    final rows = await db.query('users', where: 'id = ?', whereArgs: [id]);
    return rows.isEmpty ? null : AppUser.fromMap(rows.first);
  }

  Future<List<AppUser>> getAllUsers({bool activeOnly = true}) async {
    final db = await database;
    final rows = await db.query(
      'users',
      where: activeOnly ? 'is_active = 1' : null,
      orderBy: 'full_name',
    );
    return rows.map(AppUser.fromMap).toList();
  }

  Future<int> createUser({
    required String email,
    required String password,
    required String role,
    required String fullName,
    int? actorUserId,
  }) async {
    if (email.trim().isEmpty || !email.contains('@')) {
      throw ArgumentError('A valid email address is required.');
    }
    if (fullName.trim().isEmpty) {
      throw ArgumentError('The user name is required.');
    }
    if (!{'admin', 'cashier'}.contains(role)) {
      throw ArgumentError.value(role, 'role');
    }
    if (password.length < 8) {
      throw ArgumentError('Password must contain at least 8 characters.');
    }
    final db = await database;
    late int id;
    await db.transaction((txn) async {
      final now = Fmt.now();
      id = await txn.insert('users', {
        'email': email.trim().toLowerCase(),
        'password_hash': createPasswordHash(password),
        'role': role,
        'full_name': fullName.trim(),
        'is_active': 1,
        'created_at': now,
        'updated_at': now,
      });
      await _writeAudit(txn, actorUserId, 'CREATE', 'user', id, {
        'email': email.trim().toLowerCase(),
        'role': role,
      });
    });
    return id;
  }

  Future<void> updateUserProfile({
    required int id,
    required String email,
    required String fullName,
    required String role,
    required bool isActive,
    int? actorUserId,
  }) async {
    if (!{'admin', 'cashier'}.contains(role)) {
      throw ArgumentError.value(role, 'role');
    }
    final db = await database;
    await db.transaction((txn) async {
      if (!isActive || role != 'admin') {
        final adminCount =
            Sqflite.firstIntValue(
              await txn.rawQuery(
                "SELECT COUNT(*) FROM users WHERE role='admin' AND is_active=1 AND id<>?",
                [id],
              ),
            ) ??
            0;
        final current = await txn.query(
          'users',
          columns: ['role', 'is_active'],
          where: 'id=?',
          whereArgs: [id],
        );
        final changingLastAdmin =
            current.isNotEmpty &&
            current.first['role'] == 'admin' &&
            current.first['is_active'] == 1 &&
            adminCount == 0;
        if (changingLastAdmin) {
          throw StateError('At least one active administrator is required.');
        }
      }
      await txn.update(
        'users',
        {
          'email': email.trim().toLowerCase(),
          'full_name': fullName.trim(),
          'role': role,
          'is_active': isActive ? 1 : 0,
          'updated_at': Fmt.now(),
        },
        where: 'id=?',
        whereArgs: [id],
      );
      await _writeAudit(txn, actorUserId, 'UPDATE', 'user', id, {
        'role': role,
        'is_active': isActive,
      });
    });
  }

  Future<bool> changePassword({
    required int userId,
    required String currentPassword,
    required String newPassword,
    int? actorUserId,
    bool requireCurrentPassword = true,
  }) async {
    if (newPassword.length < 8) return false;
    final db = await database;
    final rows = await db.query(
      'users',
      columns: ['password_hash'],
      where: 'id=?',
      whereArgs: [userId],
    );
    if (rows.isEmpty) return false;
    if (requireCurrentPassword &&
        !verifyPassword(
          currentPassword,
          rows.first['password_hash'] as String,
        )) {
      return false;
    }
    await db.transaction((txn) async {
      await txn.update(
        'users',
        {
          'password_hash': createPasswordHash(newPassword),
          'updated_at': Fmt.now(),
        },
        where: 'id=?',
        whereArgs: [userId],
      );
      await _writeAudit(
        txn,
        actorUserId ?? userId,
        'PASSWORD_CHANGE',
        'user',
        userId,
        null,
      );
    });
    return true;
  }

  Future<void> deactivateUser(int id) async {
    final db = await database;
    await db.update(
      'users',
      {'is_active': 0, 'updated_at': Fmt.now()},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ─── Customers ────────────────────────────────────────────────────

  Future<int> insertCustomer(Customer customer) async {
    final db = await database;
    final id = await db.insert('customers', customer.toMap());
    await _enqueue('customers', id, 'INSERT', {...customer.toMap(), 'id': id});
    return id;
  }

  Future<void> updateCustomer(Customer customer) async {
    final db = await database;
    final map = {...customer.toMap(), 'is_synced': 0};
    await db.update(
      'customers',
      map,
      where: 'id = ?',
      whereArgs: [customer.id],
    );
    await _enqueue('customers', customer.id!, 'UPDATE', map);
  }

  Future<void> deactivateCustomer(int id) async {
    final db = await database;
    final now = Fmt.now();
    await db.update(
      'customers',
      {'is_active': 0, 'is_synced': 0, 'updated_at': now},
      where: 'id = ?',
      whereArgs: [id],
    );
    await _enqueue('customers', id, 'UPDATE', {
      'id': id,
      'is_active': 0,
      'is_synced': 0,
      'updated_at': now,
    });
  }

  Future<void> updateCustomerBalance(int customerId, double newBalance) async {
    final db = await database;
    final now = Fmt.now();
    await db.update(
      'customers',
      {'balance': newBalance, 'is_synced': 0, 'updated_at': now},
      where: 'id = ?',
      whereArgs: [customerId],
    );
    await _enqueue('customers', customerId, 'UPDATE', {
      'id': customerId,
      'balance': newBalance,
      'is_synced': 0,
      'updated_at': now,
    });
  }

  Future<Customer?> getCustomerById(int id) async {
    final db = await database;
    final rows = await db.query('customers', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return null;
    return Customer.fromMap(rows.first);
  }

  Future<List<Customer>> getActiveCustomers() async {
    final db = await database;
    final rows = await db.query(
      'customers',
      where: 'is_active = 1',
      orderBy: 'name',
    );
    return rows.map(Customer.fromMap).toList();
  }

  Future<List<Customer>> getAllCustomers({bool activeOnly = true}) async {
    final db = await database;
    final rows = await db.query(
      'customers',
      where: activeOnly ? 'is_active = 1' : null,
      orderBy: 'name',
    );
    return rows.map(Customer.fromMap).toList();
  }

  Future<List<Map<String, dynamic>>> getCustomerStatement(
    int customerId, {
    String currency = 'SDG',
  }) async {
    final db = await database;
    return db.rawQuery(
      '''
      SELECT i.id, i.invoice_number, i.status, i.created_at, i.due_date,
        i.total_amount + i.tax_amount AS total,
        COALESCE(SUM(CASE WHEN p.reversed_at IS NULL THEN p.amount_paid ELSE 0 END), 0) AS paid,
        MAX(0, i.total_amount + i.tax_amount -
          COALESCE(SUM(CASE WHEN p.reversed_at IS NULL THEN p.amount_paid ELSE 0 END), 0)) AS remaining
      FROM invoices i LEFT JOIN payments p ON p.invoice_id=i.id
      WHERE i.customer_id=? AND i.currency=?
      GROUP BY i.id
      ORDER BY i.created_at DESC
    ''',
      [customerId, currency],
    );
  }

  // ─── Products ─────────────────────────────────────────────────────

  Future<int> insertProduct(Product product) async {
    final db = await database;
    final id = await db.insert('products', product.toMap());
    await _enqueue('products', id, 'INSERT', {...product.toMap(), 'id': id});
    return id;
  }

  Future<void> updateProduct(Product product) async {
    final db = await database;
    final map = {...product.toMap(), 'is_synced': 0};
    await db.update('products', map, where: 'id = ?', whereArgs: [product.id]);
    await _enqueue('products', product.id!, 'UPDATE', map);
  }

  Future<void> deactivateProduct(int id) async {
    final db = await database;
    final now = Fmt.now();
    await db.update(
      'products',
      {'is_active': 0, 'is_synced': 0, 'updated_at': now},
      where: 'id = ?',
      whereArgs: [id],
    );
    await _enqueue('products', id, 'UPDATE', {
      'id': id,
      'is_active': 0,
      'is_synced': 0,
      'updated_at': now,
    });
  }

  Future<List<Product>> getActiveProducts() async {
    final db = await database;
    final rows = await db.query(
      'products',
      where: 'is_active = 1',
      orderBy: 'name',
    );
    return rows.map(Product.fromMap).toList();
  }

  Future<List<Product>> getAllProducts({bool activeOnly = true}) async {
    final db = await database;
    final rows = await db.query(
      'products',
      where: activeOnly ? 'is_active = 1' : null,
      orderBy: 'name',
    );
    return rows.map(Product.fromMap).toList();
  }

  // ─── Invoices ─────────────────────────────────────────────────────

  static const _invoiceSeqKey = 'invoice_seq';

  String _formatInvoiceNumber(int seq) =>
      'INV-${seq.toString().padLeft(4, '0')}';

  // Current invoice sequence value. Falls back to the highest existing INV-####
  // so numbering survives an upgrade where the counter was never written.
  Future<int> _currentInvoiceSeq(DatabaseExecutor db) async {
    final rows = await db.query(
      'settings',
      where: 'key = ?',
      whereArgs: [_invoiceSeqKey],
    );
    if (rows.isNotEmpty) {
      return int.tryParse(rows.first['value'] as String? ?? '') ?? 0;
    }
    final maxRow = await db.rawQuery(
      "SELECT COALESCE(MAX(CAST(substr(invoice_number, 5) AS INTEGER)), 0) AS m "
      "FROM invoices WHERE invoice_number LIKE 'INV-%'",
    );
    return (maxRow.first['m'] as int?) ?? 0;
  }

  // Preview only — does not consume a number.
  Future<String> nextInvoiceNumber() async {
    final db = await database;
    return _formatInvoiceNumber(await _currentInvoiceSeq(db) + 1);
  }

  // Atomically consumes and returns the next number. Must run inside a txn so
  // two concurrent inserts can never receive the same value.
  Future<String> _allocateInvoiceNumber(Transaction txn) async {
    final next = (await _currentInvoiceSeq(txn)) + 1;
    await txn.insert('settings', {
      'key': _invoiceSeqKey,
      'value': next.toString(),
      'updated_at': Fmt.now(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    return _formatInvoiceNumber(next);
  }

  Future<void> updateInvoiceStatus(int id, String status) async {
    final db = await database;
    final now = Fmt.now();
    await db.update(
      'invoices',
      {'status': status, 'is_synced': 0, 'updated_at': now},
      where: 'id = ?',
      whereArgs: [id],
    );
    await _enqueue('invoices', id, 'UPDATE', {
      'id': id,
      'status': status,
      'is_synced': 0,
      'updated_at': now,
    });
  }

  // The customer running balance (receivables) is an SDG ledger. Invoices in
  // any other currency settle at the invoice level only and never touch it,
  // so amounts in different currencies are never added together.
  Future<bool> _invoiceAffectsBalance(
    DatabaseExecutor db,
    int invoiceId,
  ) async {
    final rows = await db.query(
      'invoices',
      columns: ['currency'],
      where: 'id = ?',
      whereArgs: [invoiceId],
    );
    if (rows.isEmpty) return true;
    return ((rows.first['currency'] as String?) ?? 'SDG') == 'SDG';
  }

  Future<void> confirmInvoiceWithBalance(
    int invoiceId,
    int customerId,
    double delta, {
    int? actorUserId,
  }) async {
    final db = await database;
    final now = Fmt.now();
    await db.transaction((txn) async {
      final current = await txn.query(
        'invoices',
        columns: ['status'],
        where: 'id = ?',
        whereArgs: [invoiceId],
      );
      if (current.isEmpty || current.first['status'] != 'Draft') {
        throw StateError('Only draft invoices can be confirmed.');
      }
      await txn.update(
        'invoices',
        {'status': 'Confirmed', 'is_synced': 0, 'updated_at': now},
        where: 'id = ?',
        whereArgs: [invoiceId],
      );
      if (await _invoiceAffectsBalance(txn, invoiceId)) {
        await _recalculateCustomerBalance(txn, customerId, now);
        await _enqueueWithExecutor(txn, 'customers', customerId, 'UPDATE', {
          'id': customerId,
          'is_synced': 0,
          'updated_at': now,
        });
      }
      await _enqueueWithExecutor(txn, 'invoices', invoiceId, 'UPDATE', {
        'id': invoiceId,
        'status': 'Confirmed',
        'is_synced': 0,
        'updated_at': now,
      });
      await _writeAudit(
        txn,
        actorUserId,
        'CONFIRM',
        'invoice',
        invoiceId,
        null,
      );
    });
  }

  Future<void> voidInvoiceWithBalance(
    int invoiceId,
    int customerId,
    double delta,
    bool wasConfirmed, {
    int? actorUserId,
  }) async {
    final db = await database;
    final now = Fmt.now();
    await db.transaction((txn) async {
      final paymentCount =
          Sqflite.firstIntValue(
            await txn.rawQuery(
              'SELECT COUNT(*) FROM payments WHERE invoice_id=? AND reversed_at IS NULL',
              [invoiceId],
            ),
          ) ??
          0;
      if (paymentCount > 0) {
        throw StateError('Invoices with payments cannot be voided.');
      }
      await txn.update(
        'invoices',
        {'status': 'Voided', 'is_synced': 0, 'updated_at': now},
        where: 'id = ?',
        whereArgs: [invoiceId],
      );
      if (wasConfirmed && await _invoiceAffectsBalance(txn, invoiceId)) {
        await _recalculateCustomerBalance(txn, customerId, now);
        await _enqueueWithExecutor(txn, 'customers', customerId, 'UPDATE', {
          'id': customerId,
          'is_synced': 0,
          'updated_at': now,
        });
      }
      await _enqueueWithExecutor(txn, 'invoices', invoiceId, 'UPDATE', {
        'id': invoiceId,
        'status': 'Voided',
        'is_synced': 0,
        'updated_at': now,
      });
      await _writeAudit(txn, actorUserId, 'VOID', 'invoice', invoiceId, null);
    });
  }

  Future<void> insertPaymentAndSettle(
    Payment payment,
    int customerId,
    int invoiceId,
    double grandTotal, {
    int? actorUserId,
  }) async {
    final db = await database;
    final now = Fmt.now();
    int paymentId = 0;
    await db.transaction((txn) async {
      final invoiceRows = await txn.query(
        'invoices',
        columns: ['status', 'total_amount', 'tax_amount'],
        where: 'id = ?',
        whereArgs: [invoiceId],
      );
      if (invoiceRows.isEmpty || invoiceRows.first['status'] != 'Confirmed') {
        throw StateError(
          'Payments can only be recorded on confirmed invoices.',
        );
      }
      if (payment.amountPaid <= 0) {
        throw ArgumentError.value(payment.amountPaid, 'amountPaid');
      }
      final paidRows = await txn.rawQuery(
        'SELECT COALESCE(SUM(amount_paid),0) AS total FROM payments '
        'WHERE invoice_id=? AND reversed_at IS NULL',
        [invoiceId],
      );
      final alreadyPaid = (paidRows.first['total'] as num?)?.toDouble() ?? 0;
      final storedTotal =
          (invoiceRows.first['total_amount'] as num).toDouble() +
          (invoiceRows.first['tax_amount'] as num).toDouble();
      if (payment.amountPaid > storedTotal - alreadyPaid + 0.01) {
        throw StateError('Payment exceeds the remaining invoice balance.');
      }
      paymentId = await txn.insert('payments', payment.toMap());
      await _enqueueWithExecutor(txn, 'payments', paymentId, 'INSERT', {
        ...payment.toMap(),
        'id': paymentId,
      });
      if (await _invoiceAffectsBalance(txn, invoiceId)) {
        await _recalculateCustomerBalance(txn, customerId, now);
        await _enqueueWithExecutor(txn, 'customers', customerId, 'UPDATE', {
          'id': customerId,
          'is_synced': 0,
          'updated_at': now,
        });
      }
      final result = await txn.rawQuery(
        'SELECT COALESCE(SUM(amount_paid), 0) AS total FROM payments '
        'WHERE invoice_id = ? AND reversed_at IS NULL',
        [invoiceId],
      );
      final totalPaid = (result.first['total'] as num?)?.toDouble() ?? 0;
      // 0.01 tolerance absorbs floating-point drift when summing payments;
      // it is below the smallest amount a cashier can enter.
      if (totalPaid >= storedTotal - 0.01) {
        await txn.update(
          'invoices',
          {'status': 'Paid', 'is_synced': 0, 'updated_at': now},
          where: 'id = ?',
          whereArgs: [invoiceId],
        );
        await _enqueueWithExecutor(txn, 'invoices', invoiceId, 'UPDATE', {
          'id': invoiceId,
          'status': 'Paid',
          'is_synced': 0,
          'updated_at': now,
        });
      }
      await _writeAudit(txn, actorUserId, 'PAYMENT', 'invoice', invoiceId, {
        'payment_id': paymentId,
        'amount': payment.amountPaid,
      });
    });
  }

  Future<int> insertInvoiceWithItemsAndBalance(
    Map<String, dynamic> invoiceMap,
    List<Map<String, dynamic>> itemMaps,
    int? customerId,
    double balanceDelta,
  ) async {
    final db = await database;
    final now = Fmt.now();
    int invoiceId = 0;
    var savedMap = Map<String, dynamic>.from(invoiceMap);
    final itemIds = <int>[];
    await db.transaction((txn) async {
      // Number is assigned here, inside the transaction, so it can never
      // collide with a deleted invoice or a concurrent insert.
      savedMap['invoice_number'] = await _allocateInvoiceNumber(txn);
      invoiceId = await txn.insert('invoices', savedMap);
      for (final item in itemMaps) {
        final itemId = await txn.insert('invoice_items', {
          ...item,
          'invoice_id': invoiceId,
        });
        itemIds.add(itemId);
      }
      final isSdg = ((savedMap['currency'] as String?) ?? 'SDG') == 'SDG';
      if (customerId != null && balanceDelta != 0 && isSdg) {
        await _recalculateCustomerBalance(txn, customerId, now);
      }
      await _writeAudit(
        txn,
        savedMap['created_by'] as int?,
        'CREATE',
        'invoice',
        invoiceId,
        {'status': savedMap['status']},
      );
      await _enqueueWithExecutor(txn, 'invoices', invoiceId, 'INSERT', {
        ...savedMap,
        'id': invoiceId,
      });
      for (int i = 0; i < itemMaps.length; i++) {
        await _enqueueWithExecutor(txn, 'invoice_items', itemIds[i], 'INSERT', {
          ...itemMaps[i],
          'invoice_id': invoiceId,
          'id': itemIds[i],
        });
      }
      if (customerId != null && balanceDelta != 0) {
        await _enqueueWithExecutor(txn, 'customers', customerId, 'UPDATE', {
          'id': customerId,
          'is_synced': 0,
          'updated_at': now,
        });
      }
    });
    return invoiceId;
  }

  Future<Invoice?> getInvoiceById(int id) async {
    final db = await database;
    final rows = await db.rawQuery(
      '''
      SELECT i.*, c.name AS customer_name
      FROM invoices i
      LEFT JOIN customers c ON i.customer_id = c.id
      WHERE i.id = ?
    ''',
      [id],
    );
    if (rows.isEmpty) return null;
    return Invoice.fromMap(rows.first);
  }

  Future<List<Invoice>> getAllInvoices() async {
    final db = await database;
    final rows = await db.rawQuery('''
      SELECT i.*, c.name AS customer_name
      FROM invoices i
      LEFT JOIN customers c ON i.customer_id = c.id
      ORDER BY i.created_at DESC
    ''');
    return rows.map(Invoice.fromMap).toList();
  }

  Future<List<Invoice>> getInvoicesByStatus(String status) async {
    final db = await database;
    final rows = await db.rawQuery(
      '''
      SELECT i.*, c.name AS customer_name
      FROM invoices i
      LEFT JOIN customers c ON i.customer_id = c.id
      WHERE i.status = ?
      ORDER BY i.created_at DESC
    ''',
      [status],
    );
    return rows.map(Invoice.fromMap).toList();
  }

  Future<List<Invoice>> getUnpaidInvoices() async {
    final db = await database;
    final rows = await db.rawQuery('''
      SELECT i.*, c.name AS customer_name
      FROM invoices i
      LEFT JOIN customers c ON i.customer_id = c.id
      WHERE i.status IN ('Draft', 'Confirmed')
      ORDER BY i.created_at DESC
    ''');
    return rows.map(Invoice.fromMap).toList();
  }

  // ─── Invoice Items ─────────────────────────────────────────────────

  Future<List<InvoiceItem>> getItemsForInvoice(int invoiceId) async {
    final db = await database;
    final rows = await db.query(
      'invoice_items',
      where: 'invoice_id = ?',
      whereArgs: [invoiceId],
    );
    return rows.map(InvoiceItem.fromMap).toList();
  }

  // ─── Payments ─────────────────────────────────────────────────────

  Future<int> insertPayment(Payment payment) async {
    final db = await database;
    final id = await db.insert('payments', payment.toMap());
    await _enqueue('payments', id, 'INSERT', {...payment.toMap(), 'id': id});
    return id;
  }

  Future<List<Payment>> getPaymentsForInvoice(int invoiceId) async {
    final db = await database;
    final rows = await db.query(
      'payments',
      where: 'invoice_id = ? AND reversed_at IS NULL',
      whereArgs: [invoiceId],
      orderBy: 'created_at ASC',
    );
    return rows.map(Payment.fromMap).toList();
  }

  Future<double> getTotalPaidForInvoice(int invoiceId) async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT COALESCE(SUM(amount_paid), 0) AS total FROM payments '
      'WHERE invoice_id = ? AND reversed_at IS NULL',
      [invoiceId],
    );
    return (result.first['total'] as num?)?.toDouble() ?? 0;
  }

  Future<void> reversePayment({
    required int paymentId,
    required int actorUserId,
    required String reason,
  }) async {
    if (reason.trim().length < 3) {
      throw ArgumentError('A reversal reason is required.');
    }
    final db = await database;
    await db.transaction((txn) async {
      final rows = await txn.rawQuery(
        '''
        SELECT p.*, i.customer_id, i.currency, i.status AS invoice_status
        FROM payments p JOIN invoices i ON i.id=p.invoice_id
        WHERE p.id=?
      ''',
        [paymentId],
      );
      if (rows.isEmpty || rows.first['reversed_at'] != null) {
        throw StateError('Payment is missing or already reversed.');
      }
      final row = rows.first;
      final now = Fmt.now();
      await txn.update(
        'payments',
        {
          'reversed_at': now,
          'reversed_by': actorUserId,
          'reversal_reason': reason.trim(),
          'is_synced': 0,
        },
        where: 'id=?',
        whereArgs: [paymentId],
      );
      await _enqueueWithExecutor(txn, 'payments', paymentId, 'UPDATE', {
        'id': paymentId,
        'reversed_at': now,
        'reversed_by': actorUserId,
        'reversal_reason': reason.trim(),
      });
      if (row['invoice_status'] == 'Paid') {
        await txn.update(
          'invoices',
          {'status': 'Confirmed', 'is_synced': 0, 'updated_at': now},
          where: 'id=?',
          whereArgs: [row['invoice_id']],
        );
        await _enqueueWithExecutor(
          txn,
          'invoices',
          row['invoice_id'] as int,
          'UPDATE',
          {'id': row['invoice_id'], 'status': 'Confirmed', 'updated_at': now},
        );
      }
      if ((row['currency'] as String? ?? 'SDG') == 'SDG') {
        await _recalculateCustomerBalance(txn, row['customer_id'] as int, now);
        await _enqueueWithExecutor(
          txn,
          'customers',
          row['customer_id'] as int,
          'UPDATE',
          {'id': row['customer_id'], 'updated_at': now},
        );
      }
      await _writeAudit(
        txn,
        actorUserId,
        'REVERSE_PAYMENT',
        'payment',
        paymentId,
        {'reason': reason.trim(), 'invoice_id': row['invoice_id']},
      );
    });
  }

  Future<void> _recalculateCustomerBalance(
    DatabaseExecutor db,
    int customerId,
    String now,
  ) async {
    final rows = await db.rawQuery(
      '''
      SELECT COALESCE(SUM(
        MAX(0, i.total_amount + i.tax_amount - COALESCE((
          SELECT SUM(p.amount_paid) FROM payments p
          WHERE p.invoice_id=i.id AND p.reversed_at IS NULL
        ), 0))
      ), 0) AS balance
      FROM invoices i
      WHERE i.customer_id=? AND i.currency='SDG'
        AND i.status IN ('Confirmed','Paid')
    ''',
      [customerId],
    );
    final balance = (rows.first['balance'] as num?)?.toDouble() ?? 0;
    await db.update(
      'customers',
      {'balance': balance, 'is_synced': 0, 'updated_at': now},
      where: 'id=?',
      whereArgs: [customerId],
    );
  }

  // ─── Cash Drawer ──────────────────────────────────────────────────

  /// The currently open drawer session, or null if none is open.
  Future<CashDrawerSession?> getOpenCashDrawer() async {
    final db = await database;
    final rows = await db.query(
      'cash_drawer_sessions',
      where: "status = 'Open'",
      orderBy: 'opened_at DESC',
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return CashDrawerSession.fromMap(rows.first);
  }

  Future<int> openCashDrawer(int openedBy, double openingBalance) async {
    final db = await database;
    return db.insert('cash_drawer_sessions', {
      'opened_by': openedBy,
      'opening_balance': openingBalance,
      'status': 'Open',
      'opened_at': Fmt.now(),
      'created_at': Fmt.now(),
    });
  }

  /// Total cash payments recorded since [openedAtIso] — the cash that should
  /// have entered the drawer during the session.
  Future<double> cashCollectedSince(String openedAtIso) async {
    final db = await database;
    final result = await db.rawQuery(
      "SELECT COALESCE(SUM(amount_paid), 0) AS total FROM payments "
      "WHERE method = 'Cash' AND reversed_at IS NULL AND created_at >= ?",
      [openedAtIso],
    );
    return (result.first['total'] as num?)?.toDouble() ?? 0;
  }

  /// Closes [session] with the physically counted [closingActual], recording
  /// the expected total and the variance (counted − expected). Runs in a
  /// transaction so a payment recorded mid-close cannot skew the numbers.
  Future<void> closeCashDrawer(
    CashDrawerSession session,
    double closingActual, {
    String? notes,
  }) async {
    final db = await database;
    await db.transaction((txn) async {
      final result = await txn.rawQuery(
        "SELECT COALESCE(SUM(amount_paid), 0) AS total FROM payments "
        "WHERE method = 'Cash' AND reversed_at IS NULL AND created_at >= ?",
        [session.openedAt],
      );
      final collected = (result.first['total'] as num?)?.toDouble() ?? 0;
      final expected = session.openingBalance + collected;
      await txn.update(
        'cash_drawer_sessions',
        {
          'expected_cash': expected,
          'closing_balance': closingActual,
          'variance': closingActual - expected,
          'status': 'Closed',
          'closed_at': Fmt.now(),
          'notes': notes,
        },
        where: 'id = ?',
        whereArgs: [session.id],
      );
    });
  }

  Future<List<CashDrawerSession>> getRecentCashDrawers({int limit = 10}) async {
    final db = await database;
    final rows = await db.query(
      'cash_drawer_sessions',
      orderBy: 'opened_at DESC',
      limit: limit,
    );
    return rows.map(CashDrawerSession.fromMap).toList();
  }

  // ─── Utility Payments ─────────────────────────────────────────────
  // A manual ledger of utility bills the shop paid on a customer's behalf.
  // No Sudanese electricity, water, or telecom provider exposes a public API
  // (confirmed via research), so there is nothing to "check live" — this
  // records the real-world workflow: the shop pays the provider through its
  // own channel and logs the transaction here.

  Future<int> insertUtilityPayment(UtilityPayment payment) async {
    final db = await database;
    final map = payment.toMap();
    final id = await db.insert('utility_payments', map);
    await _enqueue('utility_payments', id, 'INSERT', {...map, 'id': id});
    return id;
  }

  Future<List<UtilityPayment>> getUtilityPayments({int limit = 100}) async {
    final db = await database;
    final rows = await db.query(
      'utility_payments',
      orderBy: 'created_at DESC',
      limit: limit,
    );
    return rows.map(UtilityPayment.fromMap).toList();
  }

  /// Total service fees earned across all recorded utility payments — the
  /// shop's real income from this feature (the bill amount itself is a
  /// pass-through to the provider, not revenue).
  Future<double> getUtilityServiceFeeTotal() async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT COALESCE(SUM(service_fee), 0) AS t FROM utility_payments',
    );
    return (result.first['t'] as num?)?.toDouble() ?? 0;
  }

  // ─── Settings ─────────────────────────────────────────────────────

  Future<String?> getSetting(String key) async {
    final db = await database;
    final rows = await db.query('settings', where: 'key = ?', whereArgs: [key]);
    if (rows.isEmpty) return null;
    return rows.first['value'] as String?;
  }

  Future<void> setSetting(String key, String value) async {
    final db = await database;
    await db.insert('settings', {
      'key': key,
      'value': value,
      'updated_at': Fmt.now(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  // ─── Dashboard Metrics ────────────────────────────────────────────

  Future<Map<String, dynamic>> getMetrics({String currency = 'SDG'}) async {
    final db = await database;
    final today = Fmt.today();

    final customersCount =
        Sqflite.firstIntValue(
          await db.rawQuery(
            'SELECT COUNT(*) FROM customers WHERE is_active = 1',
          ),
        ) ??
        0;

    final invoicesCount =
        Sqflite.firstIntValue(
          await db.rawQuery('SELECT COUNT(*) FROM invoices'),
        ) ??
        0;

    final unpaidCount =
        Sqflite.firstIntValue(
          await db.rawQuery(
            "SELECT COUNT(*) FROM invoices WHERE currency=? AND status IN ('Draft','Confirmed')",
            [currency],
          ),
        ) ??
        0;

    final todayResult = await db.rawQuery(
      '''
      SELECT COALESCE(SUM(p.amount_paid), 0) AS total
      FROM payments p JOIN invoices i ON i.id=p.invoice_id
      WHERE p.reversed_at IS NULL AND i.currency=? AND p.payment_date LIKE ?
    ''',
      [currency, '$today%'],
    );
    final todayRevenue = (todayResult.first['total'] as num?)?.toDouble() ?? 0;

    final receivablesResult = await db.rawQuery(
      '''SELECT COALESCE(SUM(
        MAX(0, i.total_amount+i.tax_amount-COALESCE((
          SELECT SUM(p.amount_paid) FROM payments p
          WHERE p.invoice_id=i.id AND p.reversed_at IS NULL
        ),0))),0) AS total
        FROM invoices i JOIN customers c ON c.id=i.customer_id
        WHERE c.is_active=1 AND i.currency=? AND i.status IN ('Confirmed','Paid')''',
      [currency],
    );
    final totalReceivables =
        (receivablesResult.first['total'] as num?)?.toDouble() ?? 0;

    return {
      'customers_count': customersCount,
      'invoices_count': invoicesCount,
      'unpaid_count': unpaidCount,
      'today_revenue': todayRevenue,
      'total_receivables': totalReceivables,
    };
  }

  // ─── Reports ──────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getDailyRevenueLast7Days({
    String currency = 'SDG',
  }) async {
    final db = await database;
    return db.rawQuery(
      '''
      SELECT substr(p.payment_date, 1, 10) AS day, SUM(p.amount_paid) AS total
      FROM payments p JOIN invoices i ON i.id=p.invoice_id
      WHERE p.reversed_at IS NULL AND i.currency=?
        AND p.payment_date >= date('now', '-7 days')
      GROUP BY day
      ORDER BY day ASC
    ''',
      [currency],
    );
  }

  Future<List<Map<String, dynamic>>> getMonthlyRevenue(
    String yearMonth, {
    String currency = 'SDG',
  }) async {
    final db = await database;
    return db.rawQuery(
      '''
      SELECT substr(p.payment_date, 1, 10) AS day, SUM(p.amount_paid) AS total
      FROM payments p JOIN invoices i ON i.id=p.invoice_id
      WHERE p.reversed_at IS NULL AND i.currency=? AND p.payment_date LIKE ?
      GROUP BY day
      ORDER BY day ASC
    ''',
      [currency, '$yearMonth%'],
    );
  }

  Future<List<Map<String, dynamic>>> getRevenueByMethod({
    String currency = 'SDG',
  }) async {
    final db = await database;
    return db.rawQuery(
      '''
      SELECT p.method, SUM(p.amount_paid) AS total, COUNT(*) AS count
      FROM payments p JOIN invoices i ON i.id=p.invoice_id
      WHERE p.reversed_at IS NULL AND i.currency=?
      GROUP BY p.method
      ORDER BY total DESC
    ''',
      [currency],
    );
  }

  Future<List<Map<String, dynamic>>> getTopProducts({
    int limit = 10,
    String currency = 'SDG',
  }) async {
    final db = await database;
    return db.rawQuery(
      '''
      SELECT ii.description, SUM(ii.quantity) AS total_qty, SUM(ii.subtotal) AS total_revenue
      FROM invoice_items ii
      JOIN invoices i ON ii.invoice_id = i.id
      WHERE i.status IN ('Confirmed', 'Paid', 'Closed') AND i.currency=?
      GROUP BY ii.description
      ORDER BY total_qty DESC
      LIMIT ?
    ''',
      [currency, limit],
    );
  }

  Future<Map<String, dynamic>> getReportSummary({
    String currency = 'SDG',
  }) async {
    final db = await database;
    final today = Fmt.today();
    final now = DateTime.now();
    final weekStart = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(Duration(days: now.weekday - 1));
    final weekStartStr =
        '${weekStart.year}-${weekStart.month.toString().padLeft(2, '0')}-${weekStart.day.toString().padLeft(2, '0')}';
    final monthStr = Fmt.currentMonth();

    final results = await Future.wait([
      db.rawQuery(
        '''SELECT COALESCE(SUM(p.amount_paid),0) AS t
          FROM payments p JOIN invoices i ON i.id=p.invoice_id
          WHERE p.reversed_at IS NULL AND i.currency=?''',
        [currency],
      ),
      db.rawQuery(
        '''SELECT COALESCE(SUM(p.amount_paid),0) AS t
          FROM payments p JOIN invoices i ON i.id=p.invoice_id
          WHERE p.reversed_at IS NULL AND i.currency=? AND p.payment_date LIKE ?''',
        [currency, '$today%'],
      ),
      db.rawQuery(
        '''SELECT COALESCE(SUM(p.amount_paid),0) AS t
          FROM payments p JOIN invoices i ON i.id=p.invoice_id
          WHERE p.reversed_at IS NULL AND i.currency=? AND p.payment_date >= ?''',
        [currency, weekStartStr],
      ),
      db.rawQuery(
        '''SELECT COALESCE(SUM(p.amount_paid),0) AS t
          FROM payments p JOIN invoices i ON i.id=p.invoice_id
          WHERE p.reversed_at IS NULL AND i.currency=? AND p.payment_date LIKE ?''',
        [currency, '$monthStr%'],
      ),
      db.rawQuery(
        '''SELECT COALESCE(SUM(
          MAX(0, i.total_amount+i.tax_amount-COALESCE((
            SELECT SUM(p.amount_paid) FROM payments p
            WHERE p.invoice_id=i.id AND p.reversed_at IS NULL
          ),0))),0) AS t
          FROM invoices i WHERE i.currency=? AND i.status IN ('Confirmed','Paid')''',
        [currency],
      ),
      db.rawQuery(
        'SELECT status, COUNT(*) AS cnt FROM invoices GROUP BY status',
      ),
      db.rawQuery('SELECT COUNT(*) AS c FROM customers WHERE is_active=1'),
      db.rawQuery('SELECT COUNT(*) AS c FROM products WHERE is_active=1'),
      db.rawQuery('SELECT COUNT(*) AS c FROM invoices'),
      db.rawQuery(
        'SELECT COALESCE(SUM(service_fee),0) AS t FROM utility_payments',
      ),
    ]);

    num t(int i) => results[i].first['t'] as num? ?? 0;
    final statusRows = results[5];
    final Map<String, int> statusCounts = {
      for (final row in statusRows) row['status'] as String: row['cnt'] as int,
    };

    return {
      'total_revenue': t(0).toDouble(),
      'today_revenue': t(1).toDouble(),
      'week_revenue': t(2).toDouble(),
      'month_revenue': t(3).toDouble(),
      'unpaid_receivables': t(4).toDouble(),
      'status_counts': statusCounts,
      'customers_count': results[6].first['c'] as int? ?? 0,
      'products_count': results[7].first['c'] as int? ?? 0,
      'invoices_count': results[8].first['c'] as int? ?? 0,
      'utility_service_revenue':
          (results[9].first['t'] as num?)?.toDouble() ?? 0,
    };
  }

  Future<List<Map<String, dynamic>>> getTopCustomersByBalance({
    int limit = 5,
    String currency = 'SDG',
  }) async {
    final db = await database;
    return db.rawQuery(
      '''
      SELECT c.name, c.phone, SUM(
        MAX(0, i.total_amount+i.tax_amount-COALESCE((
          SELECT SUM(p.amount_paid) FROM payments p
          WHERE p.invoice_id=i.id AND p.reversed_at IS NULL
        ),0))) AS balance
      FROM customers c JOIN invoices i ON i.customer_id=c.id
      WHERE c.is_active=1 AND i.currency=? AND i.status IN ('Confirmed','Paid')
      GROUP BY c.id, c.name, c.phone
      HAVING balance > 0
      ORDER BY balance DESC
      LIMIT ?
    ''',
      [currency, limit],
    );
  }

  Future<List<Map<String, dynamic>>> getAgingReport({
    String currency = 'SDG',
  }) async {
    final db = await database;
    return db.rawQuery(
      '''
      SELECT c.id, c.name, c.phone,
        SUM(MAX(0, i.total_amount+i.tax_amount-COALESCE((
          SELECT SUM(p.amount_paid) FROM payments p
          WHERE p.invoice_id=i.id AND p.reversed_at IS NULL
        ),0))) AS balance,
        CAST((julianday('now') - julianday(
          COALESCE(MIN(i.due_date), MIN(i.created_at), 'now')
        )) AS INTEGER) AS days_overdue
      FROM customers c JOIN invoices i ON i.customer_id=c.id
      WHERE c.is_active=1 AND i.currency=? AND i.status IN ('Confirmed','Paid')
      GROUP BY c.id, c.name, c.phone
      HAVING balance > 0
      ORDER BY days_overdue DESC
    ''',
      [currency],
    );
  }

  // ─── Sync Queue ───────────────────────────────────────────────────

  Future<void> _enqueue(
    String tableName,
    int recordId,
    String operation,
    Map<String, dynamic> payload,
  ) async {
    final db = await database;
    await _enqueueWithExecutor(db, tableName, recordId, operation, payload);
  }

  Future<void> _enqueueWithExecutor(
    DatabaseExecutor db,
    String tableName,
    int recordId,
    String operation,
    Map<String, dynamic> payload,
  ) async {
    await db.insert('sync_queue', {
      'table_name': tableName,
      'record_id': recordId,
      'operation': operation,
      'payload': jsonEncode(payload),
      'synced_at': null,
      'created_at': Fmt.now(),
    });
  }

  Future<List<Map<String, dynamic>>> getPendingSyncItems() async {
    final db = await database;
    return db.query(
      'sync_queue',
      where: 'synced_at IS NULL',
      orderBy: 'created_at ASC',
    );
  }

  Future<void> markSynced(int queueId) async {
    final db = await database;
    await db.update(
      'sync_queue',
      {'synced_at': Fmt.now()},
      where: 'id = ?',
      whereArgs: [queueId],
    );
  }

  Future<int> getPendingSyncCount() async {
    final db = await database;
    return Sqflite.firstIntValue(
          await db.rawQuery(
            'SELECT COUNT(*) FROM sync_queue WHERE synced_at IS NULL',
          ),
        ) ??
        0;
  }

  Future<void> _writeAudit(
    DatabaseExecutor db,
    int? userId,
    String action,
    String entityType,
    int? entityId,
    Map<String, dynamic>? details,
  ) async {
    await db.insert('audit_logs', {
      'user_id': userId,
      'action': action,
      'entity_type': entityType,
      'entity_id': entityId,
      'details': details == null ? null : jsonEncode(details),
      'created_at': Fmt.now(),
    });
  }

  Future<List<Map<String, dynamic>>> getAuditLogs({int limit = 200}) async {
    final db = await database;
    return db.rawQuery(
      '''
      SELECT a.*, u.full_name AS user_name, u.email AS user_email
      FROM audit_logs a LEFT JOIN users u ON u.id=a.user_id
      ORDER BY a.created_at DESC LIMIT ?
    ''',
      [limit],
    );
  }

  Future<void> rebuildAllCustomerBalances({int? actorUserId}) async {
    final db = await database;
    await db.transaction((txn) async {
      final customers = await txn.query('customers', columns: ['id']);
      final now = Fmt.now();
      for (final row in customers) {
        await _recalculateCustomerBalance(txn, row['id'] as int, now);
      }
      await _writeAudit(
        txn,
        actorUserId,
        'REBUILD_BALANCES',
        'customer',
        null,
        {'count': customers.length},
      );
    });
  }

  Future<Map<String, dynamic>> createBackupSnapshot() async {
    final db = await database;
    final settings = await db.query('settings');
    final safeSettings = settings
        .where((row) => row['key'] != 'supabase_anon_key')
        .toList(growable: false);
    return {
      'format': 'group16_bms_backup',
      'version': 1,
      'exported_at': Fmt.now(),
      'data': {
        'customers': await db.query('customers'),
        'products': await db.query('products'),
        'invoices': await db.query('invoices'),
        'invoice_items': await db.query('invoice_items'),
        'payments': await db.query('payments'),
        'cash_drawer_sessions': await db.query('cash_drawer_sessions'),
        'utility_payments': await db.query('utility_payments'),
        'settings': safeSettings,
        'audit_logs': await db.query('audit_logs'),
      },
    };
  }
}
