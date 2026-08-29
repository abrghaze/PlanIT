import 'package:dio/dio.dart';
import 'package:planit_mobile/core/errors/app_exception.dart';
import 'package:planit_mobile/core/network/api_client.dart';
import 'package:planit_mobile/features/debts/domain/debt.dart';

final class DebtsApi {
  const DebtsApi(this._client);
  final ApiClient _client;

  Future<List<Person>> fetchPeople({required String accessToken}) async {
    final data = await _get('/people', accessToken);
    return _items(data, Person.fromJson, 'people');
  }

  Future<List<Debt>> fetchDebts({
    required String ownerId,
    required String accessToken,
  }) async {
    final data = await _get('/debts', accessToken);
    return _items(
      data,
      (json) => Debt.fromJson(json, ownerId: ownerId),
      'debts',
    );
  }

  Future<Person> createPerson({
    required String accessToken,
    required String operationId,
    required String personId,
    required String name,
    String? contact,
  }) async {
    try {
      final response = await _client.raw.post<Map<String, Object?>>(
        _client.url('/people'),
        data: <String, Object?>{
          'id': personId,
          'name': name,
          'contact': ?contact,
        },
        options: Options(
          headers: <String, String>{
            ..._auth(accessToken),
            'Idempotency-Key': operationId,
          },
        ),
      );
      final data = response.data;
      if (data == null) throw _invalid('person');
      return Person.fromJson(data);
    } on DioException catch (error) {
      throw AppException.fromDio(error);
    }
  }

  Future<Map<String, Object?>> _get(String path, String token) async {
    try {
      final response = await _client.raw.get<Map<String, Object?>>(
        _client.url(path),
        options: Options(headers: _auth(token)),
      );
      if (response.data == null) throw _invalid('list');
      return response.data!;
    } on DioException catch (error) {
      throw AppException.fromDio(error);
    }
  }

  static List<T> _items<T>(
    Map<String, Object?> data,
    T Function(Map<String, Object?>) parser,
    String label,
  ) {
    final raw = data['items'];
    if (raw is! List) throw _invalid(label);
    try {
      return raw
          .map((item) => parser(Map<String, Object?>.from(item as Map)))
          .toList(growable: false);
    } on Object {
      throw _invalid(label);
    }
  }

  static Map<String, String> _auth(String token) => <String, String>{
    'Authorization': 'Bearer $token',
  };
  static AppException _invalid(String label) => AppException(
    code: 'INVALID_SERVER_RESPONSE',
    message: 'The server returned invalid $label data.',
  );
}
