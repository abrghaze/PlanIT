import 'package:flutter_test/flutter_test.dart';
import 'package:planit_mobile/features/debts/domain/debt.dart';
import 'package:planit_mobile/features/transactions/domain/outbox_operation.dart';

void main() {
  test('debt response parses money, repayment, and direction contracts', () {
    final debt = Debt.fromJson(<String, Object?>{
      'id': 'debt-1',
      'person_id': 'person-1',
      'direction': 'RECEIVABLE',
      'origin_type': 'LEND_NOW',
      'original_amount': _money('100.0000'),
      'paid_amount': _money('40.0000'),
      'remaining_amount': _money('60.0000'),
      'status': 'PARTIALLY_PAID',
      'overdue': false,
      'due_date': '2026-09-15',
      'note': 'Lunch loan',
      'version': 2,
      'payments': <Object?>[
        <String, Object?>{
          'id': 'payment-1',
          'amount': _money('40.0000'),
          'paid_at': '2026-08-29T12:00:00Z',
          'transaction': _transactionJson(),
        },
      ],
    }, ownerId: 'owner-1');

    expect(debt.direction, DebtDirection.receivable);
    expect(debt.origin, DebtOrigin.lendNow);
    expect(debt.remainingAmount.toApiString(), '60.0000');
    expect(debt.acceptsPayment, isTrue);
    expect(debt.payments.single.transaction.ownerId, 'owner-1');
  });

  test('unknown debt direction is rejected', () {
    expect(
      () => Debt.fromJson(<String, Object?>{
        'id': 'debt-1',
        'person_id': 'person-1',
        'direction': 'SIDEWAYS',
        'origin_type': 'EXISTING',
        'original_amount': _money('10.0000'),
        'paid_amount': _money('0.0000'),
        'remaining_amount': _money('10.0000'),
        'status': 'OPEN',
        'overdue': false,
        'due_date': null,
        'note': null,
        'version': 1,
        'payments': const <Object?>[],
      }, ownerId: 'owner-1'),
      throwsFormatException,
    );
  });

  test('Milestone 4 operation names round-trip through durable storage', () {
    for (final type in <OutboxOperationType>[
      OutboxOperationType.debtCreate,
      OutboxOperationType.debtPayment,
      OutboxOperationType.shareCreate,
      OutboxOperationType.refundCreate,
    ]) {
      expect(OutboxOperationTypeContract.fromStorage(type.storageValue), type);
      expect(type.isSpecializedFinancialCommit, isTrue);
    }
  });
}

Map<String, Object?> _money(String amount) => <String, Object?>{
  'amount': amount,
  'currency': 'MAD',
};

Map<String, Object?> _transactionJson() {
  const timestamp = '2026-08-29T12:00:00Z';
  return <String, Object?>{
    'id': 'repayment-transaction',
    'account_id': 'account-1',
    'type': 'DEBT_REPAYMENT_IN',
    'effect': 'INFLOW',
    'amount': _money('40.0000'),
    'occurred_at': timestamp,
    'status': 'POSTED',
    'category_id': null,
    'counterparty': null,
    'note': null,
    'tag_ids': const <String>[],
    'parent_transaction_id': null,
    'reversal_of_id': null,
    'client_operation_id': 'operation-1',
    'version': 1,
    'created_at': timestamp,
    'updated_at': timestamp,
  };
}
