import 'package:flutter/foundation.dart';

abstract final class ApiConfig {
  static const String baseUrl = String.fromEnvironment(
    'PLANIT_API_BASE_URL',
    defaultValue: 'http://10.0.2.2:8000/api/v1',
  );

  static String get validatedBaseUrl =>
      validateBaseUrl(baseUrl, requireHttps: kReleaseMode);

  static String validateBaseUrl(String value, {bool requireHttps = false}) {
    final uri = Uri.tryParse(value);
    if (uri == null ||
        !uri.hasAuthority ||
        (uri.scheme != 'http' && uri.scheme != 'https') ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment ||
        !uri.path.endsWith('/api/v1')) {
      throw ArgumentError.value(value, 'value', 'Invalid PlanIT API base URL.');
    }
    if (requireHttps && uri.scheme != 'https') {
      throw StateError('Release API endpoints must use HTTPS.');
    }
    return value;
  }
}
