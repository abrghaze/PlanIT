import 'package:flutter_test/flutter_test.dart';
import 'package:planit_mobile/core/network/api_client.dart';
import 'package:planit_mobile/core/network/api_config.dart';

void main() {
  test('API client initializes from compile-time configuration', () {
    final client = ApiClient();

    expect(client.raw.options.baseUrl, ApiConfig.validatedBaseUrl);
    expect(client.raw.options.baseUrl, endsWith('/api/v1'));
    expect(client.raw.options.connectTimeout, const Duration(seconds: 10));
    expect(client.raw.options.receiveTimeout, const Duration(seconds: 20));
    expect(client.raw.options.sendTimeout, const Duration(seconds: 20));
    expect(client.raw.options.headers['Accept'], 'application/json');
  });

  test('API configuration rejects malformed and insecure release URLs', () {
    expect(() => ApiConfig.validateBaseUrl('not-a-url'), throwsArgumentError);
    expect(
      () => ApiConfig.validateBaseUrl(
        'http://api.example/api/v1',
        requireHttps: true,
      ),
      throwsStateError,
    );
    expect(
      ApiConfig.validateBaseUrl(
        'https://api.example/api/v1',
        requireHttps: true,
      ),
      'https://api.example/api/v1',
    );
  });
}
