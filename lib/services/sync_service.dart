import 'dart:async';
import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:http/http.dart' as http;

import '../data/database_helper.dart';
import '../utils/constants.dart';
import '../utils/formatters.dart';

enum SyncResultCode {
  notConfigured,
  noInternet,
  upToDate,
  success,
  partial,
  failed,
}

class SyncResult {
  final bool success;
  final String message;
  final SyncResultCode code;
  final int pushedCount;
  final int failedCount;

  const SyncResult({
    required this.success,
    required this.message,
    required this.code,
    this.pushedCount = 0,
    this.failedCount = 0,
  });
}

class SyncService {
  static const _supportedTables = {
    'customers',
    'products',
    'invoices',
    'invoice_items',
    'payments',
    'utility_payments',
  };

  static Future<SyncResult> sync() async {
    final db = DatabaseHelper.instance;

    final url = await db.getSetting(AppConstants.supabaseUrlKey);
    final key = await db.getSetting(AppConstants.supabaseAnonKey);

    if (url == null ||
        url.trim().isEmpty ||
        key == null ||
        key.trim().isEmpty) {
      return const SyncResult(
        success: false,
        message: 'Cloud sync is not configured.',
        code: SyncResultCode.notConfigured,
      );
    }

    final results = await Connectivity().checkConnectivity();
    final hasConnection = results.any((r) => r != ConnectivityResult.none);
    if (!hasConnection) {
      return const SyncResult(
        success: false,
        message: 'No internet connection.',
        code: SyncResultCode.noInternet,
      );
    }

    final baseUrl = url.trim().replaceAll(RegExp(r'/+$'), '');
    final headers = {
      'apikey': key.trim(),
      'Authorization': 'Bearer ${key.trim()}',
      'Content-Type': 'application/json',
      'Prefer': 'resolution=merge-duplicates',
    };

    final pending = await db.getPendingSyncItems();
    if (pending.isEmpty) {
      await db.setSetting(AppConstants.lastSyncedKey, Fmt.now());
      return const SyncResult(
        success: true,
        message: 'Everything is up to date.',
        code: SyncResultCode.upToDate,
      );
    }

    int pushed = 0;
    int failed = 0;

    for (final item in pending) {
      final tableName = item['table_name'] as String;
      final queueId = item['id'] as int;

      if (!_supportedTables.contains(tableName)) {
        failed++;
        continue;
      }

      final raw = jsonDecode(item['payload'] as String) as Map<String, dynamic>;
      final payload = Map<String, dynamic>.from(raw)
        ..remove('remote_id')
        ..remove('is_synced');

      try {
        final response = await http
            .post(
              Uri.parse('$baseUrl/rest/v1/$tableName'),
              headers: headers,
              body: jsonEncode(payload),
            )
            .timeout(const Duration(seconds: 15));

        if (response.statusCode >= 200 && response.statusCode < 300) {
          await db.markSynced(queueId);
          pushed++;
        } else {
          failed++;
        }
      } on TimeoutException {
        failed++;
      } catch (_) {
        failed++;
      }
    }

    if (pushed > 0 && failed == 0) {
      await db.setSetting(AppConstants.lastSyncedKey, Fmt.now());
    }

    if (failed == 0) {
      return SyncResult(
        success: true,
        message: 'Sync complete. $pushed record(s) pushed.',
        code: SyncResultCode.success,
        pushedCount: pushed,
      );
    }
    if (pushed == 0) {
      return SyncResult(
        success: false,
        message: 'Sync failed. $failed record(s) could not be pushed.',
        code: SyncResultCode.failed,
        failedCount: failed,
      );
    }
    return SyncResult(
      success: true,
      message: 'Partial sync. Pushed $pushed, failed $failed.',
      code: SyncResultCode.partial,
      pushedCount: pushed,
      failedCount: failed,
    );
  }
}
