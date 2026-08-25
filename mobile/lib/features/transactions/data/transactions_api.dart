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
      final response = switch (operation.type) {
        OutboxOperationType.createDraft =>
          await _client.raw.post<Map<String, Object?>>(
            _client.url('/transactions'),
            data: operation.payload,
            options: Options(headers: headers),
          ),
        OutboxOperationType.updateDraft =>
          await _client.raw.patch<Map<String, Object?>>(
            _client.url('/transactions/${operation.entityId}'),
            data: operation.payload,
            options: Options(headers: headers),
          ),
        OutboxOperationType.post =>
          await _client.raw.post<Map<String, Object?>>(
            _client.url('/transactions/${operation.entityId}/post'),
            data: operation.payload,
            options: Options(headers: headers),
          ),
        OutboxOperationType.reverse =>
          await _client.raw.post<Map<String, Object?>>(
            _client.url('/transactions/${operation.entityId}/reverse'),
            data: operation.payload,
            options: Options(headers: headers),
          ),
      };
      final data = response.data;
      if (data == null) {
        throw const AppException(
          code: 'INVALID_SERVER_RESPONSE',
          message: 'The server returned an incomplete transaction response.',
        );
      }
      if (operation.type == OutboxOperationType.reverse) {
        final original = data['original'];
        final reversal = data['reversal'];
        if (original is! Map || reversal is! Map) {
          throw const AppException(
            code: 'INVALID_SERVER_RESPONSE',
            message: 'The server returned an invalid reversal response.',
          );
        }
        return RemoteOperationResult(
          primary: LedgerTransaction.fromJson(
            Map<String, Object?>.from(original),
            ownerId: operation.ownerId,
          ),
          secondary: LedgerTransaction.fromJson(
            Map<String, Object?>.from(reversal),
            ownerId: operation.ownerId,
          ),
        );
      }
      return RemoteOperationResult(
        primary: LedgerTransaction.fromJson(data, ownerId: operation.ownerId),
      );
    } on DioException catch (error) {
      throw AppException.fromDio(error);
    }
  }

  static Map<String, String> _authorization(String accessToken) {
    return <String, String>{'Authorization': 'Bearer $accessToken'};
  }
}
