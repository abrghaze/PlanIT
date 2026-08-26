import 'package:flutter_test/flutter_test.dart';
import 'package:planit_mobile/core/money/money.dart';
import 'package:planit_mobile/features/financial_operations/domain/financial_operation.dart';

void main() {
  test('cross-currency transfer preserves explicit decimal strings', () {
    final request = TransferPreviewRequest(
      sourceAccountId: 'eur-account',
      destinationAccountId: 'mad-account',
      sourceAmount: Money.parse('10', 'EUR'),
      destinationAmount: Money.parse('107.25', 'MAD'),
      fxRate: '10.725000000000',
      fee: null,
      occurredAt: DateTime.utc(2026, 8, 25, 12),
    );

    expect(request.toJson(), <String, Object?>{
      'source_account_id': 'eur-account',
      'destination_account_id': 'mad-account',
      'source_amount': <String, Object?>{
        'amount': '10.0000',
        'currency': 'EUR',
      },
      'destination_amount': <String, Object?>{
        'amount': '107.2500',
        'currency': 'MAD',
      },
      'fx_rate': '10.725000000000',
      'occurred_at': '2026-08-25T12:00:00.000Z',
    });
  });

  test('reallocation serializes selected targets and parses residual line', () {
    final request = ReallocationPreviewRequest(
      accountIds: const <String>['first', 'second', 'balancing'],
      fixedTotal: Money.parse('300', 'MAD'),
      balancingAccountId: 'balancing',
      requestedBalances: <String, Money>{
        'first': Money.parse('130', 'MAD'),
        'second': Money.parse('90', 'MAD'),
      },
      occurredAt: DateTime.utc(2026, 8, 25, 12),
    );
    final json = request.toJson();

    expect(json['account_ids'], <String>['first', 'second', 'balancing']);
    expect(json['requested_balances'], hasLength(2));

    final preview = ReallocationPreview.fromJson(<String, Object?>{
      'fixed_total': <String, Object?>{'amount': '300.0000', 'currency': 'MAD'},
      'balancing_account_id': 'balancing',
      'source_fingerprint': List<String>.filled(64, 'a').join(),
      'lines': <Object?>[
        <String, Object?>{
          'account_id': 'balancing',
          'before_balance': <String, Object?>{
            'amount': '100.0000',
            'currency': 'MAD',
          },
          'requested_balance': <String, Object?>{
            'amount': '80.0000',
            'currency': 'MAD',
          },
          'delta': <String, Object?>{'amount': '-20.0000', 'currency': 'MAD'},
        },
      ],
    });

    expect(preview.lines.single.requestedBalance.toApiString(), '80.0000');
    expect(preview.lines.single.delta.toApiString(), '-20.0000');
  });

  test('invalid preview fingerprint is rejected', () {
    expect(
      () => ReconciliationPreview.fromJson(<String, Object?>{
        'account_id': 'account',
        'calculated_balance': <String, Object?>{
          'amount': '10.0000',
          'currency': 'MAD',
        },
        'actual_balance': <String, Object?>{
          'amount': '9.0000',
          'currency': 'MAD',
        },
        'delta': <String, Object?>{'amount': '-1.0000', 'currency': 'MAD'},
        'effective_at': '2026-08-25T12:00:00Z',
        'source_fingerprint': 'not-a-fingerprint',
      }),
      throwsFormatException,
    );
  });
}
