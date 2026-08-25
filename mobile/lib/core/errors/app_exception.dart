import 'package:dio/dio.dart';

final class AppException implements Exception {
  const AppException({
    required this.code,
    required this.message,
    this.statusCode,
    this.details = const <String, Object?>{},
    this.isNetworkFailure = false,
  });

  final String code;
  final String message;
  final int? statusCode;
  final Map<String, Object?> details;
  final bool isNetworkFailure;

  bool get isAuthenticationFailure =>
      statusCode == 401 ||
      code == 'INVALID_CREDENTIALS' ||
      code == 'INVALID_REFRESH_TOKEN' ||
      code == 'TOKEN_REUSE_DETECTED';

  factory AppException.fromDio(DioException error) {
    final response = error.response;
    final data = response?.data;
    if (data is Map) {
      final rawError = data['error'];
      if (rawError is Map) {
        final rawDetails = rawError['details'];
        return AppException(
          code: rawError['code']?.toString() ?? 'API_ERROR',
          message:
              rawError['message']?.toString() ??
              'The request could not be completed.',
          statusCode: response?.statusCode,
          details: rawDetails is Map
              ? rawDetails.map((key, value) => MapEntry(key.toString(), value))
              : const <String, Object?>{},
        );
      }
    }

    final networkFailure = response == null;
    return AppException(
      code: networkFailure ? 'NETWORK_UNAVAILABLE' : 'API_ERROR',
      message: networkFailure
          ? 'PlanIT could not reach the server. Check your connection.'
          : 'The request could not be completed.',
      statusCode: response?.statusCode,
      isNetworkFailure: networkFailure,
    );
  }

  @override
  String toString() => '$code: $message';
}
