import 'package:flutter_test/flutter_test.dart';
import 'package:planit_mobile/core/money/exact_decimal.dart';
import 'package:planit_mobile/features/transactions/domain/purchase_item_math.dart';

void main() {
  group('ExactDecimal', () {
    test('normalizes locale input without binary floating point', () {
      final value = ExactDecimal.parse('0,1', scale: 6, maximumDigits: 19);

      expect(value.toFixedString(), '0.100000');
    });

    test('enforces the complete NUMERIC precision after scaling', () {
      expect(
        () => ExactDecimal.parse('10000000000000', scale: 6, maximumDigits: 19),
        throwsFormatException,
      );
    });
  });

  group('PurchaseItemAmounts', () {
    test('rounds exact midpoint values to the nearest even unit', () {
      final down = PurchaseItemAmounts.parse(
        quantity: '0.000001',
        unitPrice: '50',
        discount: '0',
      );
      final up = PurchaseItemAmounts.parse(
        quantity: '0.000003',
        unitPrice: '50',
        discount: '0',
      );

      expect(down.lineTotal, '0.0000');
      expect(up.lineTotal, '0.0002');
    });

    test('subtracts the discount before applying half-even rounding', () {
      final result = PurchaseItemAmounts.parse(
        quantity: '0.000003',
        unitPrice: '50',
        discount: '0.0001',
      );

      expect(result.lineTotal, '0.0000');
    });

    test('multiplies common decimal fractions exactly', () {
      final result = PurchaseItemAmounts.parse(
        quantity: '0.1',
        unitPrice: '0.1',
        discount: '0',
      );

      expect(result.quantity, '0.100000');
      expect(result.unitPrice, '0.1000');
      expect(result.lineTotal, '0.0100');
    });

    test('rejects a discount greater than the rounded gross total', () {
      expect(
        () => PurchaseItemAmounts.parse(
          quantity: '1',
          unitPrice: '2',
          discount: '2.0001',
        ),
        throwsFormatException,
      );
    });
  });
}
