import 'package:flutter_test/flutter_test.dart';
import 'package:planit_mobile/features/transactions/domain/transaction.dart';

void main() {
  test('itemized purchase contract preserves exact decimal strings', () {
    final item = PurchaseItem.fromJson(<String, Object?>{
      'id': 'item-1',
      'product_id': 'milk-1l',
      'description': 'Milk 1 L',
      'quantity': '2.000000',
      'unit_price': '10.0000',
      'discount': '1.0000',
      'line_total': '19.0000',
      'position': 0,
    });
    expect(item.toJson()['quantity'], '2.000000');
    expect(item.toCacheJson()['line_total'], '19.0000');
  });

  test('transaction kinds use explicit backend mappings', () {
    const expected = <TransactionType, String>{
      TransactionType.expense: 'EXPENSE',
      TransactionType.income: 'INCOME',
      TransactionType.transferOut: 'TRANSFER_OUT',
      TransactionType.transferIn: 'TRANSFER_IN',
      TransactionType.transferFee: 'TRANSFER_FEE',
      TransactionType.refund: 'REFUND',
      TransactionType.loanPrincipalOut: 'LOAN_PRINCIPAL_OUT',
      TransactionType.loanPrincipalIn: 'LOAN_PRINCIPAL_IN',
      TransactionType.debtRepaymentIn: 'DEBT_REPAYMENT_IN',
      TransactionType.debtRepaymentOut: 'DEBT_REPAYMENT_OUT',
      TransactionType.reconciliationAdjustment: 'RECONCILIATION_ADJUSTMENT',
      TransactionType.reversal: 'REVERSAL',
      TransactionType.unknown: 'UNKNOWN',
    };

    for (final entry in expected.entries) {
      expect(entry.key.apiValue, entry.value);
      if (entry.key != TransactionType.unknown) {
        expect(TransactionTypeContract.fromApi(entry.value), entry.key);
      }
    }
    expect(
      TransactionTypeContract.fromApi('FUTURE_SERVER_KIND'),
      TransactionType.unknown,
    );
  });

  test('classification helpers keep internal movements neutral', () {
    expect(TransactionType.expense.isSpending, isTrue);
    expect(TransactionType.transferFee.isSpending, isTrue);
    expect(TransactionType.transferOut.isSpending, isFalse);
    expect(TransactionType.transferIn.isSpending, isFalse);
    expect(TransactionType.income.isIncome, isTrue);
    expect(TransactionType.refund.isIncome, isFalse);
    expect(TransactionType.transferOut.isTransfer, isTrue);
    expect(TransactionType.transferIn.isTransfer, isTrue);
    expect(TransactionType.transferFee.isTransfer, isTrue);
    expect(TransactionType.expense.supportsGenericReversal, isTrue);
    expect(TransactionType.income.supportsGenericReversal, isTrue);
    expect(TransactionType.transferOut.supportsGenericReversal, isFalse);
  });

  test('unknown effects and statuses fail instead of being misclassified', () {
    expect(
      () => TransactionEffectContract.fromApi('SIDEWAYS'),
      throwsFormatException,
    );
    expect(
      () => TransactionStatusContract.fromApi('PENDING'),
      throwsFormatException,
    );
  });
}
