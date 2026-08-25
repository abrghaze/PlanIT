import 'package:dio/dio.dart';
import 'package:planit_mobile/core/errors/app_exception.dart';
import 'package:planit_mobile/core/network/api_client.dart';
import 'package:planit_mobile/features/transactions/data/catalog_remote_data_source.dart';
import 'package:planit_mobile/features/transactions/domain/catalog.dart';

final class CatalogApi implements CatalogRemoteDataSource {
  const CatalogApi(this._client);

  final ApiClient _client;

  @override
  Future<List<TransactionCategory>> fetchCategories({
    required String ownerId,
    required String accessToken,
  }) async {
    try {
      final response = await _client.raw.get<Map<String, Object?>>(
        _client.url('/categories'),
        queryParameters: const <String, Object?>{'include_archived': true},
        options: Options(headers: _authorization(accessToken)),
      );
      return _parseList(
        response.data,
        (json) => TransactionCategory.fromJson(json, ownerId: ownerId),
        'category',
      );
    } on DioException catch (error) {
      throw AppException.fromDio(error);
    }
  }

  @override
  Future<List<TransactionTag>> fetchTags({
    required String ownerId,
    required String accessToken,
  }) async {
    try {
      final response = await _client.raw.get<Map<String, Object?>>(
        _client.url('/tags'),
        queryParameters: const <String, Object?>{'include_archived': true},
        options: Options(headers: _authorization(accessToken)),
      );
      return _parseList(
        response.data,
        (json) => TransactionTag.fromJson(json, ownerId: ownerId),
        'tag',
      );
    } on DioException catch (error) {
      throw AppException.fromDio(error);
    }
  }

  @override
  Future<TransactionCategory> createCategory({
    required String ownerId,
    required String accessToken,
    required String operationId,
    required CategoryDraft draft,
  }) async {
    try {
      final response = await _client.raw.post<Map<String, Object?>>(
        _client.url('/categories'),
        data: draft.toJson(),
        options: Options(headers: _operationHeaders(accessToken, operationId)),
      );
      return TransactionCategory.fromJson(
        _requireData(response.data, 'category'),
        ownerId: ownerId,
      );
    } on DioException catch (error) {
      throw AppException.fromDio(error);
    }
  }

  @override
  Future<TransactionTag> createTag({
    required String ownerId,
    required String accessToken,
    required String operationId,
    required TagDraft draft,
  }) async {
    try {
      final response = await _client.raw.post<Map<String, Object?>>(
        _client.url('/tags'),
        data: draft.toJson(),
        options: Options(headers: _operationHeaders(accessToken, operationId)),
      );
      return TransactionTag.fromJson(
        _requireData(response.data, 'tag'),
        ownerId: ownerId,
      );
    } on DioException catch (error) {
      throw AppException.fromDio(error);
    }
  }

  @override
  Future<TransactionCategory> setCategoryArchived({
    required String ownerId,
    required String accessToken,
    required String operationId,
    required TransactionCategory category,
    required bool archived,
  }) async {
    try {
      final response = await _client.raw.patch<Map<String, Object?>>(
        _client.url('/categories/${category.id}'),
        data: <String, Object?>{
          'version': category.version,
          'archived': archived,
        },
        options: Options(headers: _operationHeaders(accessToken, operationId)),
      );
      return TransactionCategory.fromJson(
        _requireData(response.data, 'category'),
        ownerId: ownerId,
      );
    } on DioException catch (error) {
      throw AppException.fromDio(error);
    }
  }

  @override
  Future<TransactionTag> setTagArchived({
    required String ownerId,
    required String accessToken,
    required String operationId,
    required TransactionTag tag,
    required bool archived,
  }) async {
    try {
      final response = await _client.raw.patch<Map<String, Object?>>(
        _client.url('/tags/${tag.id}'),
        data: <String, Object?>{'version': tag.version, 'archived': archived},
        options: Options(headers: _operationHeaders(accessToken, operationId)),
      );
      return TransactionTag.fromJson(
        _requireData(response.data, 'tag'),
        ownerId: ownerId,
      );
    } on DioException catch (error) {
      throw AppException.fromDio(error);
    }
  }

  static List<T> _parseList<T>(
    Map<String, Object?>? data,
    T Function(Map<String, Object?>) parse,
    String name,
  ) {
    final items = data?['items'];
    if (items is! List) {
      throw AppException(
        code: 'INVALID_SERVER_RESPONSE',
        message: 'The server returned an invalid $name list.',
      );
    }
    return items
        .map((item) => parse(Map<String, Object?>.from(item as Map)))
        .toList(growable: false);
  }

  static Map<String, Object?> _requireData(
    Map<String, Object?>? data,
    String name,
  ) {
    if (data == null) {
      throw AppException(
        code: 'INVALID_SERVER_RESPONSE',
        message: 'The server returned an invalid $name.',
      );
    }
    return data;
  }

  static Map<String, String> _authorization(String accessToken) {
    return <String, String>{'Authorization': 'Bearer $accessToken'};
  }

  static Map<String, String> _operationHeaders(
    String accessToken,
    String operationId,
  ) {
    return <String, String>{
      ..._authorization(accessToken),
      'Idempotency-Key': operationId,
    };
  }
}
