import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planit_mobile/core/network/api_client.dart';
import 'package:planit_mobile/features/transactions/data/transactions_api.dart';
import 'package:planit_mobile/features/transactions/domain/outbox_operation.dart';
import 'package:planit_mobile/features/transactions/domain/transaction.dart';

void main() {
  test(
    'generic and reversal responses retain their canonical row counts',
    () async {
      final adapter = _RecordingAdapter(<Map<String, Object?>>[
        _transactionJson(
          id: 'draft-transaction',
          type: 'EXPENSE',
          effect: 'OUTFLOW',
          accountId: 'account-a',
        ),
        <String, Object?>{
          'original': _transactionJson(
            id: 'original-transaction',
            type: 'INCOME',
            effect: 'INFLOW',
            accountId: 'account-a',
          ),
          'reversal': _transactionJson(
            id: 'reversal-transaction',
            type: 'REVERSAL',
            effect: 'OUTFLOW',
            accountId: 'account-a',
          ),
        },
      ]);
      final api = _api(adapter);

      final generic = await api.execute(
        accessToken: 'access-token',
        operation: _operation(
          type: OutboxOperationType.createDraft,
          entityId: 'draft-transaction',
          payload: const <String, Object?>{'version': 1},
        ),
      );
      final reversal = await api.execute(
        accessToken: 'access-token',
        operation: _operation(
          type: OutboxOperationType.reverse,
          entityId: 'original-transaction',
          payload: const <String, Object?>{'version': 1},
        ),
      );

      expect(generic.transactions, hasLength(1));
      expect(reversal.transactions, hasLength(2));
      expect(reversal.transactions.last.type, TransactionType.reversal);
    },
  );

  test(
    'transfer commit returns source, destination, and optional fee',
    () async {
      final adapter = _RecordingAdapter(<Map<String, Object?>>[
        <String, Object?>{
          'source_transaction': _transactionJson(
            id: 'source-transaction',
            type: 'TRANSFER_OUT',
            effect: 'OUTFLOW',
            accountId: 'account-a',
          ),
          'destination_transaction': _transactionJson(
            id: 'destination-transaction',
            type: 'TRANSFER_IN',
            effect: 'INFLOW',
            accountId: 'account-b',
          ),
          'fee_transaction': _transactionJson(
            id: 'fee-transaction',
            type: 'TRANSFER_FEE',
            effect: 'OUTFLOW',
            accountId: 'account-a',
          ),
        },
      ]);
      final api = _api(adapter);
      final operation = _operation(
        type: OutboxOperationType.transferCommit,
        entityId: 'transfer-1',
        payload: const <String, Object?>{
          'id': 'transfer-1',
          'client_operation_id': 'operation-1',
        },
      );

      final result = await api.execute(
        accessToken: 'access-token',
        operation: operation,
      );

      expect(result.transactions.map((value) => value.type), <TransactionType>[
        TransactionType.transferOut,
        TransactionType.transferIn,
        TransactionType.transferFee,
      ]);
      final request = adapter.requests.single;
      expect(Uri.parse(request.path).path, '/api/v1/transfers/commit');
      expect(request.headers['Idempotency-Key'], operation.id);
    },
  );

  test(
    'reconciliation routes by local account id without sending it',
    () async {
      final adapter = _RecordingAdapter(<Map<String, Object?>>[
        <String, Object?>{
          'adjustment_transaction': _transactionJson(
            id: 'adjustment-transaction',
            type: 'RECONCILIATION_ADJUSTMENT',
            effect: 'OUTFLOW',
            accountId: 'account-a',
          ),
        },
      ]);
      final api = _api(adapter);

      final result = await api.execute(
        accessToken: 'access-token',
        operation: _operation(
          type: OutboxOperationType.reconciliationCommit,
          entityId: 'reconciliation-1',
          payload: const <String, Object?>{
            'id': 'reconciliation-1',
            'client_operation_id': 'operation-1',
            '_account_id': 'account-a',
            'source_fingerprint': 'fingerprint',
          },
        ),
      );

      expect(
        result.transactions.single.type,
        TransactionType.reconciliationAdjustment,
      );
      final request = adapter.requests.single;
      expect(
        Uri.parse(request.path).path,
        '/api/v1/accounts/account-a/reconciliations/commit',
      );
      expect(_requestPayload(request), isNot(contains('_account_id')));
      expect(_requestPayload(request)['id'], 'reconciliation-1');
    },
  );

  test('reallocation flattens all nested transfer movements', () async {
    final adapter = _RecordingAdapter(<Map<String, Object?>>[
      <String, Object?>{
        'transfers': <Map<String, Object?>>[
          <String, Object?>{
            'source_transaction': _transactionJson(
              id: 'source-1',
              type: 'TRANSFER_OUT',
              effect: 'OUTFLOW',
              accountId: 'account-a',
            ),
            'destination_transaction': _transactionJson(
              id: 'destination-1',
              type: 'TRANSFER_IN',
              effect: 'INFLOW',
              accountId: 'account-b',
            ),
            'fee_transaction': null,
          },
          <String, Object?>{
            'source_transaction': _transactionJson(
              id: 'source-2',
              type: 'TRANSFER_OUT',
              effect: 'OUTFLOW',
              accountId: 'account-c',
            ),
            'destination_transaction': _transactionJson(
              id: 'destination-2',
              type: 'TRANSFER_IN',
              effect: 'INFLOW',
              accountId: 'account-b',
            ),
            'fee_transaction': null,
          },
        ],
      },
    ]);
    final api = _api(adapter);

    final result = await api.execute(
      accessToken: 'access-token',
      operation: _operation(
        type: OutboxOperationType.reallocationCommit,
        entityId: 'reallocation-1',
        payload: const <String, Object?>{
          'id': 'reallocation-1',
          'client_operation_id': 'operation-1',
        },
      ),
    );

    expect(result.transactions.map((value) => value.id), <String>[
      'source-1',
      'destination-1',
      'source-2',
      'destination-2',
    ]);
    expect(
      Uri.parse(adapter.requests.single.path).path,
      '/api/v1/reallocations/commit',
    );
  });

  test('existing debt can acknowledge without a ledger movement', () async {
    final adapter = _RecordingAdapter(<Map<String, Object?>>[
      _debtJson(originTransaction: null),
    ]);
    final api = _api(adapter);

    final result = await api.execute(
      accessToken: 'access-token',
      operation: _operation(
        type: OutboxOperationType.debtCreate,
        entityId: 'debt-1',
        payload: const <String, Object?>{
          'id': 'debt-1',
          'client_operation_id': 'operation-1',
        },
      ),
    );

    expect(result.transactions, isEmpty);
    expect(Uri.parse(adapter.requests.single.path).path, '/api/v1/debts');
  });

  test('lend-now debt returns its canonical cash movement', () async {
    final adapter = _RecordingAdapter(<Map<String, Object?>>[
      _debtJson(
        originTransaction: _transactionJson(
          id: 'loan-out',
          type: 'LOAN_PRINCIPAL_OUT',
          effect: 'OUTFLOW',
          accountId: 'account-a',
        ),
      ),
    ]);
    final api = _api(adapter);

    final result = await api.execute(
      accessToken: 'access-token',
      operation: _operation(
        type: OutboxOperationType.debtCreate,
        entityId: 'debt-1',
        payload: const <String, Object?>{
          'id': 'debt-1',
          'client_operation_id': 'operation-1',
        },
      ),
    );

    expect(result.transactions.single.type, TransactionType.loanPrincipalOut);
  });

  test('debt repayment routes by debt id and removes local metadata', () async {
    final adapter = _RecordingAdapter(<Map<String, Object?>>[
      _debtJson(
        payments: <Object?>[
          <String, Object?>{
            'id': 'payment-1',
            'client_operation_id': 'operation-1',
            'transaction': _transactionJson(
              id: 'repayment-in',
              type: 'DEBT_REPAYMENT_IN',
              effect: 'INFLOW',
              accountId: 'account-a',
            ),
          },
        ],
      ),
    ]);
    final api = _api(adapter);

    final result = await api.execute(
      accessToken: 'access-token',
      operation: _operation(
        type: OutboxOperationType.debtPayment,
        entityId: 'payment-1',
        payload: const <String, Object?>{
          'id': 'payment-1',
          '_debt_id': 'debt-1',
          'client_operation_id': 'operation-1',
        },
      ),
    );

    expect(result.transactions.single.type, TransactionType.debtRepaymentIn);
    final request = adapter.requests.single;
    expect(Uri.parse(request.path).path, '/api/v1/debts/debt-1/payments');
    expect(_requestPayload(request), isNot(contains('_debt_id')));
  });

  test('share acknowledgment has no ledger movement', () async {
    final adapter = _RecordingAdapter(<Map<String, Object?>>[
      <String, Object?>{'id': 'share-1'},
    ]);
    final api = _api(adapter);

    final result = await api.execute(
      accessToken: 'access-token',
      operation: _operation(
        type: OutboxOperationType.shareCreate,
        entityId: 'share-1',
        payload: const <String, Object?>{
          'id': 'share-1',
          '_transaction_id': 'expense-1',
        },
      ),
    );

    expect(result.transactions, isEmpty);
    final request = adapter.requests.single;
    expect(
      Uri.parse(request.path).path,
      '/api/v1/transactions/expense-1/shares',
    );
    expect(_requestPayload(request), isNot(contains('_transaction_id')));
  });

  test('refund returns its linked canonical inflow', () async {
    final adapter = _RecordingAdapter(<Map<String, Object?>>[
      <String, Object?>{
        'refund_transaction': _transactionJson(
          id: 'refund-1',
          type: 'REFUND',
          effect: 'INFLOW',
          accountId: 'account-a',
        ),
      },
    ]);
    final api = _api(adapter);

    final result = await api.execute(
      accessToken: 'access-token',
      operation: _operation(
        type: OutboxOperationType.refundCreate,
        entityId: 'refund-1',
        payload: const <String, Object?>{
          'id': 'refund-1',
          '_transaction_id': 'expense-1',
        },
      ),
    );

    expect(result.transactions.single.type, TransactionType.refund);
    expect(
      Uri.parse(adapter.requests.single.path).path,
      '/api/v1/transactions/expense-1/refund',
    );
  });
}

TransactionsApi _api(_RecordingAdapter adapter) {
  final dio = Dio(BaseOptions(baseUrl: 'http://localhost/api/v1'));
  dio.httpClientAdapter = adapter;
  return TransactionsApi(ApiClient(dio: dio));
}

PendingOperation _operation({
  required OutboxOperationType type,
  required String entityId,
  required Map<String, Object?> payload,
}) {
  final now = DateTime.utc(2026, 8, 25, 12);
  return PendingOperation(
    id: 'operation-1',
    ownerId: 'owner-a',
    entityId: entityId,
    type: type,
    state: OutboxOperationState.pending,
    payload: payload,
    attemptCount: 0,
    nextAttemptAt: now,
    lastError: null,
    createdAt: now,
  );
}

Map<String, Object?> _transactionJson({
  required String id,
  required String type,
  required String effect,
  required String accountId,
}) {
  const timestamp = '2026-08-25T12:00:00Z';
  return <String, Object?>{
    'id': id,
    'account_id': accountId,
    'type': type,
    'effect': effect,
    'amount': const <String, Object?>{'amount': '40.0000', 'currency': 'MAD'},
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

Map<String, Object?> _debtJson({
  Object? originTransaction = _absent,
  List<Object?> payments = const <Object?>[],
}) {
  return <String, Object?>{
    'id': 'debt-1',
    'payments': payments,
    if (!identical(originTransaction, _absent))
      'origin_transaction': originTransaction,
  };
}

const Object _absent = Object();

Map<String, Object?> _requestPayload(RequestOptions request) {
  final data = request.data;
  if (data is Map) {
    return Map<String, Object?>.from(data);
  }
  if (data is String) {
    return Map<String, Object?>.from(jsonDecode(data) as Map);
  }
  throw StateError('Expected a JSON request body.');
}

final class _RecordingAdapter implements HttpClientAdapter {
  _RecordingAdapter(List<Map<String, Object?>> responses)
    : _responses = List<Map<String, Object?>>.of(responses);

  final List<Map<String, Object?>> _responses;
  final List<RequestOptions> requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    if (_responses.isEmpty) {
      throw StateError('No fake response was queued.');
    }
    return ResponseBody.fromString(
      jsonEncode(_responses.removeAt(0)),
      201,
      headers: <String, List<String>>{
        Headers.contentTypeHeader: <String>[Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
