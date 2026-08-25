import 'package:dio/dio.dart';
import 'package:planit_mobile/core/auth/data/auth_remote_data_source.dart';
import 'package:planit_mobile/core/auth/domain/auth_session.dart';
import 'package:planit_mobile/core/errors/app_exception.dart';
import 'package:planit_mobile/core/network/api_client.dart';

final class AuthApi implements AuthRemoteDataSource {
  AuthApi(this._client);

  final ApiClient _client;

  @override
  Future<AuthSession> register({
    required String email,
    required String password,
    required String displayName,
    required String baseCurrency,
    required String timezone,
    String? deviceLabel,
  }) {
    return _postSession('/auth/register', <String, Object?>{
      'email': email,
      'password': password,
      'display_name': displayName,
      'base_currency': baseCurrency,
      'timezone': timezone,
      'device_label': ?deviceLabel,
    });
  }

  @override
  Future<AuthSession> login({
    required String email,
    required String password,
    String? deviceLabel,
  }) {
    return _postSession('/auth/login', <String, Object?>{
      'email': email,
      'password': password,
      'device_label': ?deviceLabel,
    });
  }

  @override
  Future<AuthSession> refresh(String refreshToken) {
    return _postSession('/auth/refresh', <String, Object?>{
      'refresh_token': refreshToken,
    });
  }

  @override
  Future<void> logout(String refreshToken) async {
    try {
      await _client.raw.post<void>(
        _client.url('/auth/logout'),
        data: <String, Object?>{'refresh_token': refreshToken},
      );
    } on DioException catch (error) {
      throw AppException.fromDio(error);
    }
  }

  Future<AuthSession> _postSession(
    String path,
    Map<String, Object?> body,
  ) async {
    try {
      final response = await _client.raw.post<Map<String, Object?>>(
        _client.url(path),
        data: body,
      );
      final data = response.data;
      if (data == null) {
        throw const AppException(
          code: 'INVALID_SERVER_RESPONSE',
          message: 'The server returned an incomplete authentication response.',
        );
      }
      return AuthSession.fromJson(data);
    } on DioException catch (error) {
      throw AppException.fromDio(error);
    }
  }
}
