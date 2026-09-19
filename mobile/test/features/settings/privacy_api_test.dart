import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planit_mobile/core/money/money.dart';
import 'package:planit_mobile/core/network/api_client.dart';
import 'package:planit_mobile/features/offline_finance/domain/offline_finance.dart';
import 'package:planit_mobile/features/settings/data/privacy_api.dart';
import 'package:planit_mobile/features/transactions/domain/transaction.dart';

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
    expect(result.budgets, isEmpty);
    expect(result.templates, isEmpty);
    expect(
      adapter.request!.headers['Authorization'],
      'Bearer private-access-token',
    );
    expect(adapter.request!.headers['Idempotency-Key'], isNotEmpty);
    expect(adapter.request!.data, isA<Map<String, Object?>>());
    final payload = adapter.request!.data! as Map<String, Object?>;
    expect(payload['confirmation'], 'RESTORE MY PLANIT DATA');
    expect(payload['password'], 'correct horse battery staple');
  });

  test('complete backup round-trips phone-only finance tools', () async {
    final downloadAdapter = _PrivacyAdapter();
    final downloadDio = Dio(BaseOptions(baseUrl: 'http://localhost/api/v1'));
    downloadDio.httpClientAdapter = downloadAdapter;
    final api = PrivacyApi(ApiClient(dio: downloadDio));
    final budget = CategoryBudget(
      id: 'budget-1',
      categoryId: 'groceries',
      monthKey: '2026-09',
      limit: Money.parse('500', 'MAD'),
      warningPercent: 80,
      updatedAt: DateTime.utc(2026, 9, 18),
    );
    final template = QuickTransactionTemplate(
      id: 'template-1',
      name: 'Coffee',
      type: TransactionType.expense,
      accountId: 'account-1',
      categoryId: 'food',
      amount: Money.parse('20', 'MAD'),
      counterparty: 'Cafe',
      note: null,
      tagIds: const <String>[],
      updatedAt: DateTime.utc(2026, 9, 18),
    );

    final backup = await api.backup(
      'private-access-token',
      budgets: <CategoryBudget>[budget],
      templates: <QuickTransactionTemplate>[template],
    );
    final restoreAdapter = _RestoreAdapter();
    final restoreDio = Dio(BaseOptions(baseUrl: 'http://localhost/api/v1'));
    restoreDio.httpClientAdapter = restoreAdapter;
    final restored = await PrivacyApi(
      ApiClient(dio: restoreDio),
    ).restore(
      'private-access-token',
      bytes: backup.bytes,
      password: 'correct horse battery staple',
    );

    expect(backup.filename, 'planit-complete-backup.json');
    expect(restored.budgets.single.limit, Money.parse('500', 'MAD'));
    expect(restored.templates.single.name, 'Coffee');
    final payload = restoreAdapter.request!.data! as Map<String, Object?>;
    final serverBackup = payload['backup']! as Map<String, Object?>;
    expect(serverBackup['format'], 'planit-portable-backup');
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
    if (Uri.parse(options.path).path.endsWith('/privacy/backup.json')) {
      return ResponseBody.fromBytes(
        utf8.encode(
          jsonEncode(<String, Object?>{
            'format': 'planit-portable-backup',
            'schema_version': 2,
            'profile': <String, Object?>{},
            'data': <String, Object?>{},
          }),
        ),
        200,
        headers: <String, List<String>>{
          Headers.contentTypeHeader: <String>['application/json'],
        },
      );
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
