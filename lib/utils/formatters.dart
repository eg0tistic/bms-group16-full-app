import 'package:intl/intl.dart';

class Fmt {
  /// Formats [amount] with a thousands separator and a currency code.
  /// Defaults to SDG so existing single-currency call sites are unchanged.
  static String currency(double amount, [String code = 'SDG']) {
    return '${NumberFormat('#,##0.##').format(amount)} $code';
  }

  static String date(String? isoString) {
    if (isoString == null || isoString.isEmpty) return '';
    final dt = DateTime.tryParse(isoString);
    if (dt == null) return isoString;
    return DateFormat('dd/MM/yyyy').format(dt);
  }

  static String dateTime(String? isoString) {
    if (isoString == null || isoString.isEmpty) return '';
    final dt = DateTime.tryParse(isoString);
    if (dt == null) return isoString;
    return DateFormat('dd/MM/yyyy HH:mm').format(dt);
  }

  static String now() => DateTime.now().toIso8601String();

  static String today() => DateTime.now().toIso8601String().split('T')[0];

  static String currentMonth() {
    final n = DateTime.now();
    return '${n.year}-${n.month.toString().padLeft(2, '0')}';
  }
}
