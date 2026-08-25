import 'package:dio/dio.dart';
import 'package:planit_mobile/core/network/api_config.dart';

final class ApiClient {
  ApiClient({Dio? dio}) : _dio = dio ?? _buildDio();

  final Dio _dio;

  Dio get raw => _dio;

  String url(String path) {
    final normalizedPath = path.startsWith('/') ? path : '/$path';
    return '${_dio.options.baseUrl}$normalizedPath';
  }

  static Dio _buildDio() {
    return Dio(
      BaseOptions(
        baseUrl: ApiConfig.validatedBaseUrl,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 20),
        sendTimeout: const Duration(seconds: 20),
        headers: const <String, String>{'Accept': 'application/json'},
      ),
    );
  }
}
