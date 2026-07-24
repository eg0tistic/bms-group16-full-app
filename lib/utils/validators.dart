/// Input validation and normalization helpers.
class SudanPhone {
  /// Normalizes a Sudanese phone number to local `09XXXXXXXX` form.
  ///
  /// Accepts inputs with spaces/dashes and `+249`, `249`, or leading `0`
  /// prefixes. Returns `null` when the number is not a valid 10-digit Sudanese
  /// mobile number (09 + 8 digits).
  static String? normalize(String input) {
    var digits = input.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.startsWith('249')) digits = digits.substring(3);
    if (digits.startsWith('0')) digits = digits.substring(1);
    // Local subscriber part should be 9 digits beginning with 9 (mobile).
    if (digits.length == 9 && digits.startsWith('9')) return '0$digits';
    return null;
  }

  /// True when [input] is empty or a valid Sudanese mobile number.
  static bool isValidOrEmpty(String input) =>
      input.trim().isEmpty || normalize(input) != null;

  /// Converts to the international `2499XXXXXXXX` form used by wa.me links.
  /// Falls back to the raw digits when the number is not a Sudanese mobile,
  /// so foreign numbers still open a chat.
  static String toInternational(String input) {
    final local = normalize(input);
    if (local != null) return '249${local.substring(1)}';
    var digits = input.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.startsWith('0')) digits = digits.substring(1);
    return digits.startsWith('249') ? digits : '249$digits';
  }
}
