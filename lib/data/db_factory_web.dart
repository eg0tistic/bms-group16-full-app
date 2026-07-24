import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';

/// Web uses the WebAssembly SQLite implementation, persisted in IndexedDB.
Future<void> configureDatabaseFactory() async {
  databaseFactory = databaseFactoryFfiWeb;
}
