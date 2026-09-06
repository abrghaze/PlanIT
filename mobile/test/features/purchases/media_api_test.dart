import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planit_mobile/core/network/api_client.dart';
import 'package:planit_mobile/features/purchases/data/media_api.dart';

void main() {
  test('media API lists, opens, and deletes private receipts', () async {
    final adapter = _MediaAdapter();
    final dio = Dio(BaseOptions(baseUrl: 'http://localhost/api/v1'));
    dio.httpClientAdapter = adapter;
    final api = MediaApi(ApiClient(dio: dio));

    final receipts = await api.list(
      token: 'private-token',
      entityType: 'TRANSACTION',
      entityId: 'transaction-1',
    );
    final url = await api.readUrl(
      token: 'private-token',
      mediaId: receipts.single.id,
    );
    await api.delete(
      token: 'private-token',
      mediaId: receipts.single.id,
      operationId: 'operation-1',
    );

    expect(receipts.single.kind, 'RECEIPT');
    expect(receipts.single.sizeBytes, 321);
    expect(url, 'https://private.example/receipt');
    expect(adapter.requests, hasLength(3));
    expect(adapter.requests[0].queryParameters, <String, Object?>{
      'entity_type': 'TRANSACTION',
      'entity_id': 'transaction-1',
    });
    expect(
      adapter.requests[2].headers['Idempotency-Key'],
      'operation-1',
    );
    for (final request in adapter.requests) {
      expect(request.headers['Authorization'], 'Bearer private-token');
    }
  });
}

final class _MediaAdapter implements HttpClientAdapter {
  final List<RequestOptions> requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    final path = Uri.parse(options.path).path;
    if (options.method == 'DELETE') {
      return ResponseBody.fromString('{"deleted":true}', 200);
    }
    if (path.endsWith('/read-url')) {
      return _json(<String, Object?>{
        'read_url': 'https://private.example/receipt',
        'expires_in_seconds': 300,
      });
    }
    return _json(<String, Object?>{
      'items': <Object?>[
        <String, Object?>{
          'id': 'media-1',
          'kind': 'RECEIPT',
          'status': 'FINALIZED',
          'mime_type': 'image/jpeg',
          'size_bytes': 321,
          'created_at': '2026-09-06T10:00:00Z',
          'finalized_at': '2026-09-06T10:00:01Z',
        },
      ],
    });
  }

  ResponseBody _json(Map<String, Object?> value) => ResponseBody.fromString(
    jsonEncode(value),
    200,
    headers: <String, List<String>>{
      Headers.contentTypeHeader: <String>['application/json'],
    },
  );

  @override
  void close({bool force = false}) {}
}
