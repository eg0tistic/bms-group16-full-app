import 'package:flutter_test/flutter_test.dart';
import 'package:group16_bms/utils/validators.dart';

void main() {
  group('SudanPhone.normalize', () {
    test('normalizes local 09 format', () {
      expect(SudanPhone.normalize('0912345678'), '0912345678');
    });

    test('strips +249 country code', () {
      expect(SudanPhone.normalize('+249912345678'), '0912345678');
    });

    test('strips 249 country code without plus', () {
      expect(SudanPhone.normalize('249912345678'), '0912345678');
    });

    test('ignores spaces and dashes', () {
      expect(SudanPhone.normalize('091-234 5678'), '0912345678');
    });

    test('rejects too-short numbers', () {
      expect(SudanPhone.normalize('0912345'), isNull);
    });

    test('rejects non-mobile (not starting with 9)', () {
      expect(SudanPhone.normalize('0812345678'), isNull);
    });
  });

  group('SudanPhone.toInternational', () {
    test('converts local 09 form to 249 form for wa.me', () {
      expect(SudanPhone.toInternational('0912345678'), '249912345678');
    });

    test('keeps +249 numbers in 249 form', () {
      expect(SudanPhone.toInternational('+249 912 345 678'), '249912345678');
    });

    test('falls back to raw digits for non-Sudanese numbers', () {
      expect(SudanPhone.toInternational('249123'), '249123');
    });
  });

  group('SudanPhone.isValidOrEmpty', () {
    test('empty is allowed', () {
      expect(SudanPhone.isValidOrEmpty(''), isTrue);
      expect(SudanPhone.isValidOrEmpty('   '), isTrue);
    });

    test('valid number is allowed', () {
      expect(SudanPhone.isValidOrEmpty('0912345678'), isTrue);
    });

    test('invalid number is rejected', () {
      expect(SudanPhone.isValidOrEmpty('123'), isFalse);
    });
  });
}
