import 'package:dio/dio.dart';
import 'package:planit_mobile/core/errors/app_exception.dart';
import 'package:planit_mobile/core/network/api_client.dart';
import 'package:planit_mobile/features/analytics/domain/analytics_dashboard.dart';

final class AnalyticsApi {
  const AnalyticsApi(this._client);
  final ApiClient _client;

  Future<Map<String, Object?>> fetch({
    required String accessToken,
    required AnalyticsFilter filter,
  }) async {
    try {
      final response = await _client.raw.get<Map<String, Object?>>(
        _client.url('/analytics/dashboard'),
        queryParameters: filter.queryParameters,
        options: Options(
          headers: <String, String>{'Authorization': 'Bearer $accessToken'},
        ),
      );
      if (response.data == null) {
        throw const AppException(
          code: 'INVALID_SERVER_RESPONSE',
          message: 'The analytics response was empty.',
        );
      }
      return response.data!;
    } on DioException catch (error) {
      throw AppException.fromDio(error);
    }
  }

  Future<void> addExchangeRate({
    required String accessToken,
    required String id,
    required String baseCurrency,
    required String quoteCurrency,
    required String rate,
    required DateTime effectiveAt,
  }) async {
    try {
      await _client.raw.post<Map<String, Object?>>(
        _client.url('/analytics/exchange-rates'),
        data: <String, Object?>{
          'id': id,
          'base_currency': baseCurrency,
          'quote_currency': quoteCurrency,
          'rate': rate,
          'effective_at': effectiveAt.toUtc().toIso8601String(),
          'source': 'manual',
        },
        options: Options(
          headers: <String, String>{
            'Authorization': 'Bearer $accessToken',
            'Idempotency-Key': id,
          },
        ),
      );
    } on DioException catch (error) {
      throw AppException.fromDio(error);
    }
  }
}
