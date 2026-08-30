import 'package:dio/dio.dart';
import 'package:planit_mobile/core/errors/app_exception.dart';
import 'package:planit_mobile/core/network/api_client.dart';
import 'package:planit_mobile/features/purchases/domain/purchase_catalog.dart';

final class PurchaseCatalogApi {
  const PurchaseCatalogApi(this._client);
  final ApiClient _client;
  Map<String, String> _headers(String token, [String? operation]) =>
      <String, String>{
        'Authorization': 'Bearer $token',
        'Idempotency-Key': ?operation,
      };

  Future<List<Merchant>> merchants(String token) async =>
      _list('/merchants', token, Merchant.fromJson);
  Future<List<Product>> products(String token) async =>
      _list('/products', token, Product.fromJson);
  Future<Merchant> createMerchant(
    String token,
    String operation,
    Map<String, Object?> payload,
  ) async => _one('/merchants', token, operation, payload, Merchant.fromJson);
  Future<Merchant> createLocation(
    String token,
    String operation,
    String merchantId,
    Map<String, Object?> payload,
  ) async => _one(
    '/merchants/${Uri.encodeComponent(merchantId)}/locations',
    token,
    operation,
    payload,
    Merchant.fromJson,
  );
  Future<Product> createProduct(
    String token,
    String operation,
    Map<String, Object?> payload,
  ) async => _one('/products', token, operation, payload, Product.fromJson);

  Future<List<T>> _list<T>(
    String path,
    String token,
    T Function(Map<String, Object?>) parse,
  ) async {
    try {
      final response = await _client.raw.get<Map<String, Object?>>(
        _client.url(path),
        options: Options(headers: _headers(token)),
      );
      final values = response.data?['items'];
      if (values is! List) {
        throw const AppException(
          code: 'INVALID_SERVER_RESPONSE',
          message: 'The server returned an invalid catalog.',
        );
      }
      return values
          .map((value) => parse(Map<String, Object?>.from(value as Map)))
          .toList(growable: false);
    } on DioException catch (error) {
      throw AppException.fromDio(error);
    }
  }

  Future<T> _one<T>(
    String path,
    String token,
    String operation,
    Map<String, Object?> payload,
    T Function(Map<String, Object?>) parse,
  ) async {
    try {
      final response = await _client.raw.post<Map<String, Object?>>(
        _client.url(path),
        data: payload,
        options: Options(headers: _headers(token, operation)),
      );
      if (response.data == null) {
        throw const AppException(
          code: 'INVALID_SERVER_RESPONSE',
          message: 'The server returned an invalid catalog item.',
        );
      }
      return parse(response.data!);
    } on DioException catch (error) {
      throw AppException.fromDio(error);
    }
  }
}
