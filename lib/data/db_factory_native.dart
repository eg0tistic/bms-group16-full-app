import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'database_helper.dart';

/// Desktop platforms need the FFI SQLite implementation; Android and iOS
/// keep the default sqflite factory.
///
/// On desktop the FFI factory resolves its default database folder relative
/// to the process working directory, which changes with how the exe is
/// launched. Pin the database to the per-app data directory instead so the
/// same data is found no matter where the app starts from.
Future<void> configureDatabaseFactory() async {
  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    final dir = await getApplicationSupportDirectory();
    DatabaseHelper.databasePathOverride = p.join(dir.path, 'bms.db');
  }
}
