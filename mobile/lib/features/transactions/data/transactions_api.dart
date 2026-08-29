import 'package:dio/dio.dart';
import 'package:planit_mobile/core/errors/app_exception.dart';
import 'package:planit_mobile/core/network/api_client.dart';
import 'package:planit_mobile/features/transactions/data/transactions_remote_data_source.dart';
import 'package:planit_mobile/features/transactions/domain/outbox_operation.dart';
import 'package:planit_mobile/features/transactions/domain/transaction.dart';

final class TransactionsApi implements TransactionsRemoteDataSource {
  const TransactionsApi(this._client);

  final ApiClient _client;

  @override
  Future<List<LedgerTransaction>> fetchTransactions({
    required String ownerId,
    required String accessToken,
  }) async {
    try {
      final response = await _client.raw.get<Map<String, Object?>>(
        _client.url('/transactions'),
        queryParameters: const <String, Object?>{'limit': 200},
        options: Options(headers: _authorization(accessToken)),
      );
      final items = response.data?['items'];
      if (items is! List) {
        throw const AppException(
          code: 'INVALID_SERVER_RESPONSE',
          message: 'The server returned an invalid transaction list.',
        );
      }
      return items
          .map(
            (item) => LedgerTransaction.fromJson(
              Map<String, Object?>.from(item as Map),
              ownerId: ownerId,
            ),
          )
          .toList(growable: false);
    } on DioException catch (error) {
      throw AppException.fromDio(error);
    }
  }

  @override
  Future<RemoteOperationResult> execute({
    required String accessToken,
    required PendingOperation operation,
  }) async {
    try {
      final headers = <String, String>{
        ..._authorization(accessToken),
        'Idempotency-Key': operation.id,
      };
      late final Response<Map<String, Object?>> response;
      switch (operation.type) {
        case OutboxOperationType.createDraft:
          response = await _client.raw.post<Map<String, Object?>>(
            _client.url('/transactions'),
            data: operation.payload,
            options: Options(headers: headers),
          );
        case OutboxOperationType.updateDraft:
          response = await _client.raw.patch<Map<String, Object?>>(
            _client.url('/transactions/${operation.entityId}'),
            data: operation.payload,
            options: Options(headers: headers),
          );
        case OutboxOperationType.post:
          response = await _client.raw.post<Map<String, Object?>>(
            _client.url('/transactions/${operation.entityId}/post'),
            data: operation.payload,
            options: Options(headers: headers),
          );
        case OutboxOperationType.reverse:
          response = await _client.raw.post<Map<String, Object?>>(
            _client.url('/transactions/${operation.entityId}/reverse'),
            data: operation.payload,
            options: Options(headers: headers),
          );
        case OutboxOperationType.transferCommit:
          response = await _client.raw.post<Map<String, Object?>>(
            _client.url('/transfers/commit'),
            data: operation.payload,
            options: Options(headers: headers),
          );
        case OutboxOperationType.reconciliationCommit:
          final payload = Map<String, Object?>.from(operation.payload);
          final accountId = payload.remove('_account_id');
          if (accountId is! String || accountId.isEmpty) {
            throw const AppException(
              code: 'INVALID_LOCAL_OPERATION',
              message: 'A balance reconciliation is missing its account.',
            );
          }
          response = await _client.raw.post<Map<String, Object?>>(
            _client.url(
              '/accounts/${Uri.encodeComponent(accountId)}/reconciliations/commit',
            ),
            data: payload,
            options: Options(headers: headers),
          );
        case OutboxOperationType.reallocationCommit:
          response = await _client.raw.post<Map<String, Object?>>(
            _client.url('/reallocations/commit'),
            data: operation.payload,
            options: Options(headers: headers),
          );
        case OutboxOperationType.debtCreate:
          response = await _client.raw.post<Map<String, Object?>>(
            _client.url('/debts'),
            data: operation.payload,
            options: Options(headers: headers),
          );
        case OutboxOperationType.debtPayment:
          final payload = Map<String, Object?>.from(operation.payload);
          final debtId = payload.remove('_debt_id');
          if (debtId is! String || debtId.isEmpty) throw _invalidLocalOperation;
          response = await _client.raw.post<Map<String, Object?>>(
            _client.url('/debts/${Uri.encodeComponent(debtId)}/payments'),
            data: payload,
            options: Options(headers: headers),
          );
        case OutboxOperationType.shareCreate:
          final payload = Map<String, Object?>.from(operation.payload);
          final transactionId = payload.remove('_transaction_id');
          if (transactionId is! String || transactionId.isEmpty) {
            throw _invalidLocalOperation;
          }
          response = await _client.raw.post<Map<String, Object?>>(
            _client.url(
              '/transactions/${Uri.encodeComponent(transactionId)}/shares',
            ),
            data: payload,
            options: Options(headers: headers),
          );
        case OutboxOperationType.refundCreate:
          final payload = Map<String, Object?>.from(operation.payload);
          final transactionId = payload.remove('_transaction_id');
          if (transactionId is! String || transactionId.isEmpty) {
            throw _invalidLocalOperation;
          }
          response = await _client.raw.post<Map<String, Object?>>(
            _client.url(
              '/transactions/${Uri.encodeComponent(transactionId)}/refund',
            ),
            data: payload,
            options: Options(headers: headers),
          );
      }
      final data = response.data;
      if (data == null) {
        throw _invalidServerResponse;
      }
      return _parseOperationResponse(operation, data);
    } on DioException catch (error) {
      throw AppException.fromDio(error);
    }
  }

  static RemoteOperationResult _parseOperationResponse(
    PendingOperation operation,
    Map<String, Object?> data,
  ) {
    try {
      final transactions = switch (operation.type) {
        OutboxOperationType.reverse => <LedgerTransaction>[
          _parseNamedTransaction(data, 'original', operation.ownerId),
          _parseNamedTransaction(data, 'reversal', operation.ownerId),
        ],
        OutboxOperationType.transferCommit => _parseTransferTransactions(
          data,
          operation.ownerId,
        ),
        OutboxOperationType.reconciliationCommit => <LedgerTransaction>[
          _parseNamedTransaction(
            data,
            'adjustment_transaction',
            operation.ownerId,
          ),
        ],
        OutboxOperationType.reallocationCommit =>
          _parseReallocationTransactions(data, operation.ownerId),
        OutboxOperationType.debtCreate => _parseDebtCreateTransactions(
          data,
          operation.ownerId,
        ),
        OutboxOperationType.debtPayment => _parseDebtPaymentTransactions(
          data,
          operation.ownerId,
          operation.id,
        ),
        OutboxOperationType.shareCreate => const <LedgerTransaction>[],
        OutboxOperationType.refundCreate => <LedgerTransaction>[
          _parseNamedTransaction(data, 'refund_transaction', operation.ownerId),
        ],
        _ => <LedgerTransaction>[
          LedgerTransaction.fromJson(data, ownerId: operation.ownerId),
        ],
      };
      return RemoteOperationResult(transactions: transactions);
    } on AppException {
      rethrow;
    } on Object {
      throw _invalidServerResponse;
    }
  }

  static List<LedgerTransaction> _parseTransferTransactions(
    Map<String, Object?> transfer,
    String ownerId,
  ) {
    final transactions = <LedgerTransaction>[
      _parseNamedTransaction(transfer, 'source_transaction', ownerId),
      _parseNamedTransaction(transfer, 'destination_transaction', ownerId),
    ];
    final fee = transfer['fee_transaction'];
    if (fee != null) {
      transactions.add(_parseTransaction(fee, ownerId));
    }
    return transactions;
  }

  static List<LedgerTransaction> _parseReallocationTransactions(
    Map<String, Object?> data,
    String ownerId,
  ) {
    final rawTransfers = data['transfers'];
    if (rawTransfers is! List) {
      throw _invalidServerResponse;
    }
    final transactions = <LedgerTransaction>[];
    for (final rawTransfer in rawTransfers) {
      final transfer = _asMap(rawTransfer);
      transactions.addAll(_parseTransferTransactions(transfer, ownerId));
    }
    if (transactions.isEmpty) {
      throw _invalidServerResponse;
    }
    return transactions;
  }

  static List<LedgerTransaction> _parseDebtCreateTransactions(
    Map<String, Object?> data,
    String ownerId,
  ) {
    final origin = data['origin_transaction'];
    return origin == null
        ? const <LedgerTransaction>[]
        : <LedgerTransaction>[_parseTransaction(origin, ownerId)];
  }

  static List<LedgerTransaction> _parseDebtPaymentTransactions(
    Map<String, Object?> data,
    String ownerId,
    String operationId,
  ) {
    final raw = data['payments'];
    if (raw is! List) throw _invalidServerResponse;
    for (final value in raw) {
      final payment = _asMap(value);
      if (payment['client_operation_id'] == operationId) {
        return <LedgerTransaction>[
          _parseNamedTransaction(payment, 'transaction', ownerId),
        ];
      }
    }
    throw _invalidServerResponse;
  }

  static LedgerTransaction _parseNamedTransaction(
    Map<String, Object?> data,
    String key,
    String ownerId,
  ) {
    return _parseTransaction(data[key], ownerId);
  }

  static LedgerTransaction _parseTransaction(Object? value, String ownerId) {
    return LedgerTransaction.fromJson(_asMap(value), ownerId: ownerId);
  }

  static Map<String, Object?> _asMap(Object? value) {
    if (value is! Map) {
      throw _invalidServerResponse;
    }
    return Map<String, Object?>.from(value);
  }

  static Map<String, String> _authorization(String accessToken) {
    return <String, String>{'Authorization': 'Bearer $accessToken'};
  }

  static const AppException _invalidServerResponse = AppException(
    code: 'INVALID_SERVER_RESPONSE',
    message: 'The server returned an invalid financial operation response.',
  );
  static const AppException _invalidLocalOperation = AppException(
    code: 'INVALID_LOCAL_OPERATION',
    message: 'This queued operation is incomplete.',
  );
}
