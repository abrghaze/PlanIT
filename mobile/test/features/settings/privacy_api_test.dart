import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planit_mobile/core/network/api_client.dart';
import 'package:planit_mobile/features/settings/data/privacy_api.dart';

void main() {
  test(
    'privacy API downloads owner export and sends deliberate deletion',
    () async {
      final adapter = _PrivacyAdapter();
      final dio = Dio(BaseOptions(baseUrl: 'http://localhost/api/v1'));
      dio.httpClientAdapter = adapter;
      final api = PrivacyApi(ApiClient(dio: dio));

      final download = await api.exportCsv(
        'private-access-token',
        dataType: 'transactions',
      );
      await api.deleteProfile(
        'private-access-token',
        password: 'correct horse battery staple',
        confirmation: 'DELETE MY PLANIT DATA',
      );

      expect(download.filename, 'planit-transactions-2026-08-30.csv');
      expect(utf8.decode(download.bytes), contains('amount'));
      expect(adapter.requests, hasLength(2));
      final export = adapter.requests.first;
      expect(Uri.parse(export.path).path, '/api/v1/privacy/export.csv');
      expect(export.queryParameters['data_type'], 'transactions');
      expect(export.headers['Authorization'], 'Bearer private-access-token');
      expect(export.responseType, ResponseType.bytes);

      final deletion = adapter.requests.last;
      expect(deletion.method, 'DELETE');
      expect(deletion.data, <String, String>{
        'password': 'correct horse battery staple',
        'confirmation': 'DELETE MY PLANIT DATA',
      });
    },
  );

  test('privacy API validates and uploads a portable restore', () async {
    final adapter = _RestoreAdapter();
    final dio = Dio(BaseOptions(baseUrl: 'http://localhost/api/v1'));
    dio.httpClientAdapter = adapter;
    final api = PrivacyApi(ApiClient(dio: dio));
    final backup = utf8.encode(
      jsonEncode(<String, Object?>{
        'format': 'planit-portable-backup',
        'schema_version': 1,
        'profile': <String, Object?>{},
        'data': <String, Object?>{},
      }),
    );

    final result = await api.restore(
      'private-access-token',
      bytes: backup,
      password: 'correct horse battery staple',
    );

    expect(result.restoredRows, 14);
    expect(result.ignoredReceiptFiles, 2);
    expect(adapter.request!.headers['Authorization'], 'Bearer private-access-token');
    expect(adapter.request!.headers['Idempotency-Key'], isNotEmpty);
    expect(adapter.request!.data, isA<Map<String, Object?>>());
    final payload = adapter.request!.data! as Map<String, Object?>;
    expect(payload['confirmation'], 'RESTORE MY PLANIT DATA');
    expect(payload['password'], 'correct horse battery staple');
  });
}

final class _PrivacyAdapter implements HttpClientAdapter {
  final List<RequestOptions> requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    if (options.method == 'DELETE') {
      return ResponseBody.fromBytes(const <int>[], 204);
    }
    return ResponseBody.fromBytes(
      utf8.encode('id,amount\ntransaction-1,12.3400\n'),
      200,
      headers: <String, List<String>>{
        Headers.contentTypeHeader: <String>['text/csv'],
        'content-disposition': <String>[
          'attachment; filename="planit-transactions-2026-08-30.csv"',
        ],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

final class _RestoreAdapter implements HttpClientAdapter {
  RequestOptions? request;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    request = options;
    return ResponseBody.fromString(
      jsonEncode(<String, int>{
        'restored_rows': 14,
        'ignored_receipt_files': 2,
      }),
      200,
      headers: <String, List<String>>{
        Headers.contentTypeHeader: <String>['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
