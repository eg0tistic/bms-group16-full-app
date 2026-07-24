import 'dart:convert';

import 'package:share_plus/share_plus.dart';

import '../data/database_helper.dart';

class BackupService {
  static Future<void> exportBusinessData() async {
    final snapshot = await DatabaseHelper.instance.createBackupSnapshot();
    final timestamp = DateTime.now()
        .toIso8601String()
        .replaceAll(':', '-')
        .replaceAll('.', '-');
    final bytes = utf8.encode(
      const JsonEncoder.withIndent(' ').convert(snapshot),
    );
    await Share.shareXFiles([
      XFile.fromData(
        bytes,
        mimeType: 'application/json',
        name: 'bms_backup_$timestamp.json',
      ),
    ], subject: 'BMS business data backup');
  }
}
