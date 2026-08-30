import 'package:dio/dio.dart';
import 'package:planit_mobile/core/errors/app_exception.dart';
import 'package:planit_mobile/core/network/api_client.dart';

final class PlanningApi {
  const PlanningApi(this._client);
  final ApiClient _client;

  Future<Map<String, Object?>> fetch(String token) async {
    try {
      final responses =
          await Future.wait(<Future<Response<Map<String, Object?>>>>[
            _client.raw.get(
              _client.url('/recurring/rules'),
              options: Options(headers: _auth(token)),
            ),
            _client.raw.get(
              _client.url('/recurring/summary'),
              options: Options(headers: _auth(token)),
            ),
            _client.raw.get(
              _client.url('/goals'),
              options: Options(headers: _auth(token)),
            ),
          ]);
      final rules = responses[0].data?['items'];
      final totals = responses[1].data?['totals'];
      final goals = responses[2].data?['items'];
      if (rules is! List || totals is! List || goals is! List) {
        throw const AppException(
          code: 'INVALID_SERVER_RESPONSE',
          message: 'The server returned invalid planning data.',
        );
      }
      return <String, Object?>{
        'rules': rules,
        'totals': totals,
        'goals': goals,
      };
    } on DioException catch (error) {
      throw AppException.fromDio(error);
    }
  }

  Future<void> processDue(String token, String operationId) => _write(
    token,
    operationId,
    '/recurring/process-due',
    const <String, Object?>{},
  );

  Future<void> createRule(
    String token,
    String operationId,
    Map<String, Object?> payload,
  ) => _write(token, operationId, '/recurring/rules', payload);

  Future<void> updateRule(
    String token,
    String operationId,
    String id,
    Map<String, Object?> payload,
  ) => _write(token, operationId, '/recurring/rules/$id', payload, patch: true);

  Future<void> createGoal(
    String token,
    String operationId,
    Map<String, Object?> payload,
  ) => _write(token, operationId, '/goals', payload);

  Future<void> updateGoal(
    String token,
    String operationId,
    String id,
    Map<String, Object?> payload,
  ) => _write(token, operationId, '/goals/$id', payload, patch: true);

  Future<void> allocate(
    String token,
    String operationId,
    String id,
    Map<String, Object?> payload,
  ) => _write(token, operationId, '/goals/$id/allocations', payload);

  Future<void> _write(
    String token,
    String operationId,
    String path,
    Map<String, Object?> payload, {
    bool patch = false,
  }) async {
    try {
      final options = Options(
        headers: <String, String>{
          ..._auth(token),
          'Idempotency-Key': operationId,
        },
      );
      if (patch) {
        await _client.raw.patch(
          _client.url(path),
          data: payload,
          options: options,
        );
      } else {
        await _client.raw.post(
          _client.url(path),
          data: payload,
          options: options,
        );
      }
    } on DioException catch (error) {
      throw AppException.fromDio(error);
    }
  }

  static Map<String, String> _auth(String token) => <String, String>{
    'Authorization': 'Bearer $token',
  };
}
