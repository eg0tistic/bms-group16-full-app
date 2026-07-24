import 'package:flutter/foundation.dart';

/// Logs an error during development so real failures stay diagnosable, while
/// the UI shows a friendly localized message. No-op in release builds.
void logError(String where, Object error, [StackTrace? stackTrace]) {
  if (kDebugMode) {
    debugPrint('[BMS] $where failed: $error');
    if (stackTrace != null) debugPrint(stackTrace.toString());
  }
}
