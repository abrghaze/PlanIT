import 'package:dio/dio.dart';
import 'package:planit_mobile/core/errors/app_exception.dart';
import 'package:planit_mobile/core/network/api_client.dart';
import 'package:planit_mobile/features/financial_operations/data/financial_operations_remote_data_source.dart';
import 'package:planit_mobile/features/financial_operations/domain/financial_operation.dart';

final class FinancialOperationsApi
    implements FinancialOperationsRemoteDataSource {
  const FinancialOperationsApi(this._client);

  final ApiClient _client;

  @override
  Future<TransferPreview> previewTransfer({
    required String accessToken,
    required TransferPreviewRequest request,
  }) async {
    final data = await _postPreview(
      path: '/transfers/preview',
      accessToken: accessToken,
      payload: request.toJson(),
    );
    return _parse(
      data,
      TransferPreview.fromJson,
      'The server returned an invalid transfer preview.',
    );
  }

  @override
  Future<ReconciliationPreview> previewReconciliation({
    required String accessToken,
    required ReconciliationPreviewRequest request,
  }) async {
    final data = await _postPreview(
      path: '/accounts/${request.accountId}/reconciliations/preview',
      accessToken: accessToken,
      payload: request.toJson(),
    );
    return _parse(
      data,
      ReconciliationPreview.fromJson,
      'The server returned an invalid reconciliation preview.',
    );
  }

  @override
  Future<ReallocationPreview> previewReallocation({
    required String accessToken,
    required ReallocationPreviewRequest request,
  }) async {
    final data = await _postPreview(
      path: '/reallocations/preview',
      accessToken: accessToken,
      payload: request.toJson(),
    );
    return _parse(
      data,
      ReallocationPreview.fromJson,
      'The server returned an invalid reallocation preview.',
    );
  }

  Future<Map<String, Object?>> _postPreview({
    required String path,
    required String accessToken,
    required Map<String, Object?> payload,
  }) async {
    try {
      final response = await _client.raw.post<Map<String, Object?>>(
        _client.url(path),
        data: payload,
        options: Options(
          headers: <String, String>{'Authorization': 'Bearer $accessToken'},
        ),
      );
      final data = response.data;
      if (data == null) {
        throw const AppException(
          code: 'INVALID_SERVER_RESPONSE',
          message: 'The server returned an incomplete financial preview.',
        );
      }
      return data;
    } on DioException catch (error) {
      throw AppException.fromDio(error);
    }
  }

  static T _parse<T>(
    Map<String, Object?> data,
    T Function(Map<String, Object?> json) parser,
    String errorMessage,
  ) {
    try {
      return parser(data);
    } on Object catch (error) {
      throw AppException(
        code: 'INVALID_SERVER_RESPONSE',
        message: errorMessage,
        details: <String, Object?>{'parse_error': error.toString()},
      );
    }
  }
}
