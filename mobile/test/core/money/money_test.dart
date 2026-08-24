import 'package:flutter_test/flutter_test.dart';
import 'package:planit_mobile/core/money/money.dart';

void main() {
  group('Money', () {
    test('parses and serializes four-decimal API values', () {
      expect(Money.parse('12.5', 'mad').toApiString(), '12.5000');
    });

    test('adds without binary floating point', () {
      final result = Money.parse('0.1', 'MAD') + Money.parse('0.2', 'MAD');
      expect(result.toApiString(), '0.3000');
    });

    test('rejects excess precision', () {
      expect(() => Money.parse('1.00001', 'MAD'), throwsFormatException);
    });

    test('rejects values outside the database range', () {
      expect(
        () => Money.parse('1000000000000000', 'MAD'),
        throwsFormatException,
      );
    });

    test('rejects arithmetic outside the database range', () {
      final maximum = Money.parse('999999999999999.9999', 'MAD');

      expect(() => maximum + Money.parse('0.0001', 'MAD'), throwsRangeError);
    });

    test('rejects cross-currency arithmetic', () {
      expect(
        () => Money.parse('1', 'MAD') + Money.parse('1', 'EUR'),
        throwsStateError,
      );
    });
  });
}
