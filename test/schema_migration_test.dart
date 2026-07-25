import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:group16_bms/data/database_helper.dart';

/// Guards against schema drift between the two ways the current database can
/// exist: a fresh install (onCreate, the path a new phone takes) and an
/// upgraded v2 database run through every subsequent onUpgrade step
/// (the path an existing install takes as the app version climbs).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  tearDown(() async {
    await DatabaseHelper.resetForTests();
    DatabaseHelper.databasePathOverride = null;
  });

  // Frozen replica of the historical v2 schema before currency, due_date,
  // and credit_limit were added in v3. Do not edit.
  Future<void> createV2Schema(Database db) async {
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
    const indexes = [
      'CREATE INDEX IF NOT EXISTS idx_customers_active_name ON customers(is_active, name)',
      'CREATE INDEX IF NOT EXISTS idx_products_active_name ON products(is_active, name)',
      'CREATE INDEX IF NOT EXISTS idx_invoices_status_created ON invoices(status, created_at)',
      'CREATE INDEX IF NOT EXISTS idx_invoices_customer ON invoices(customer_id)',
      'CREATE INDEX IF NOT EXISTS idx_invoice_items_invoice ON invoice_items(invoice_id)',
      'CREATE INDEX IF NOT EXISTS idx_payments_invoice ON payments(invoice_id)',
      'CREATE INDEX IF NOT EXISTS idx_payments_date ON payments(payment_date)',
      'CREATE INDEX IF NOT EXISTS idx_sync_queue_pending ON sync_queue(synced_at, created_at)',
    ];
    for (final sql in indexes) {
      await db.execute(sql);
    }
  }

  /// Column definitions per table (order-independent) plus index names.
  Future<Map<String, Set<String>>> describeSchema(Database db) async {
    final tables = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type = 'table' "
      "AND name NOT LIKE 'sqlite_%' AND name != 'android_metadata'",
    );
    final schema = <String, Set<String>>{};
    for (final row in tables) {
      final table = row['name'] as String;
      final cols = await db.rawQuery('PRAGMA table_info($table)');
      schema[table] = {
        for (final c in cols)
          '${c['name']}|${c['type']}|${c['notnull']}|${c['dflt_value']}',
      };
      final indexes = await db.rawQuery('PRAGMA index_list($table)');
      schema[table]!.addAll({
        for (final i in indexes)
          if (!(i['name'] as String).startsWith('sqlite_'))
            'index:${i['name']}',
      });
    }
    return schema;
  }

  test(
    'v2→latest upgrade produces the same schema as a fresh install',
    () async {
      // 1. Build a real v2 database file, as an old install would have it.
      final dir = await Directory.systemTemp.createTemp('bms_migration_test');
      final v2Path = p.join(dir.path, 'bms_v2.db');
      final v2Db = await openDatabase(
        v2Path,
        version: 2,
        onCreate: (db, _) => createV2Schema(db),
      );
      await v2Db.close();

      // 2. Open it through the app's DatabaseHelper → runs every onUpgrade
      // step from v2 up to the current version in one pass.
      DatabaseHelper.databasePathOverride = v2Path;
      await DatabaseHelper.resetForTests();
      final upgraded = await DatabaseHelper.instance.database;
      final upgradedSchema = await describeSchema(upgraded);

      // 3. Fresh install in memory → runs onCreate.
      await DatabaseHelper.resetForTests();
      DatabaseHelper.databasePathOverride = inMemoryDatabasePath;
      final fresh = await DatabaseHelper.instance.database;
      final freshSchema = await describeSchema(fresh);

      // 4. Same tables, same columns, same defaults, same indexes.
      expect(upgradedSchema.keys.toSet(), freshSchema.keys.toSet());
      for (final table in freshSchema.keys) {
        expect(
          upgradedSchema[table],
          freshSchema[table],
          reason: 'schema drift in table $table',
        );
      }

      await DatabaseHelper.resetForTests();
      await dir.delete(recursive: true);
    },
  );
}
