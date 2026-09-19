import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:planit_mobile/core/errors/app_exception.dart';
import 'package:planit_mobile/core/network/api_client.dart';
import 'package:planit_mobile/features/offline_finance/domain/offline_finance.dart';
import 'package:uuid/uuid.dart';

final class PrivacyDownload {
  const PrivacyDownload({required this.filename, required this.bytes});

  final String filename;
  final List<int> bytes;
}

final class PrivacyRestoreResult {
  const PrivacyRestoreResult({
    required this.restoredRows,
    required this.ignoredReceiptFiles,
    required this.budgets,
    required this.templates,
  });

  final int restoredRows;
  final int ignoredReceiptFiles;
  final List<CategoryBudget> budgets;
  final List<QuickTransactionTemplate> templates;
}

final class PrivacyApi {
  const PrivacyApi(this._client);

  final ApiClient _client;

  Future<PrivacyDownload> exportCsv(String token, {required String dataType}) =>
      _download(
        token,
        '/privacy/export.csv',
        query: <String, Object?>{'data_type': dataType},
        fallbackFilename: 'planit-$dataType.csv',
      );

  Future<PrivacyDownload> backup(
    String token, {
    required List<CategoryBudget> budgets,
    required List<QuickTransactionTemplate> templates,
  }) async {
    final server = await _download(
      token,
      '/privacy/backup.json',
      fallbackFilename: 'planit-backup.json',
    );
    try {
      final decoded = jsonDecode(utf8.decode(server.bytes));
      if (decoded is! Map) throw const FormatException();
      final bundle = <String, Object?>{
        'format': 'planit-portable-bundle',
        'version': 1,
        'created_at': DateTime.now().toUtc().toIso8601String(),
        'server_backup': Map<String, Object?>.from(decoded),
        'device_data': <String, Object?>{
          'budgets': budgets.map((value) => value.toJson()).toList(),
          'quick_transaction_templates': templates
              .map((value) => value.toJson())
              .toList(),
        },
      };
      return PrivacyDownload(
        filename: 'planit-complete-backup.json',
        bytes: utf8.encode(const JsonEncoder.withIndent('  ').convert(bundle)),
      );
    } on Object {
      throw const AppException(
        code: 'INVALID_SERVER_RESPONSE',
        message: 'PlanIT could not prepare a complete portable backup.',
      );
    }
  }

  Future<PrivacyRestoreResult> restore(
    String token, {
    required List<int> bytes,
    required String password,
  }) async {
    try {
      final decoded = jsonDecode(utf8.decode(bytes));
      if (decoded is! Map) {
        throw const AppException(
          code: 'BACKUP_INVALID',
          message: 'The selected file is not a PlanIT portable-data file.',
        );
      }
      final decodedMap = Map<String, Object?>.from(decoded);
      final bundled = decodedMap['format'] == 'planit-portable-bundle';
      if (bundled && decodedMap['version'] != 1) {
        throw const AppException(
          code: 'BACKUP_VERSION_UNSUPPORTED',
          message: 'This PlanIT backup version is not supported.',
        );
      }
      final serverBackup = bundled
          ? _requiredMap(decodedMap['server_backup'])
          : decodedMap;
      final deviceData = bundled
          ? _requiredMap(decodedMap['device_data'])
          : const <String, Object?>{};
      final budgets = _decodeList(
        deviceData['budgets'],
        CategoryBudget.fromJson,
      );
      final templates = _decodeList(
        deviceData['quick_transaction_templates'],
        QuickTransactionTemplate.fromJson,
      );
      final response = await _client.raw.post<Map<String, Object?>>(
        _client.url('/privacy/restore'),
        data: <String, Object?>{
          'password': password,
          'confirmation': 'RESTORE MY PLANIT DATA',
          'backup': serverBackup,
        },
        options: Options(
          headers: <String, String>{
            ..._auth(token),
            'Idempotency-Key': const Uuid().v4(),
          },
        ),
      );
      final restoredRows = response.data?['restored_rows'];
      final ignoredReceiptFiles = response.data?['ignored_receipt_files'];
      if (restoredRows is! int || ignoredReceiptFiles is! int) {
        throw const AppException(
          code: 'INVALID_SERVER_RESPONSE',
          message: 'The server returned an invalid restore result.',
        );
      }
      return PrivacyRestoreResult(
        restoredRows: restoredRows,
        ignoredReceiptFiles: ignoredReceiptFiles,
        budgets: budgets,
        templates: templates,
      );
    } on DioException catch (error) {
      throw AppException.fromDio(error);
    } on AppException {
      rethrow;
    } on Object {
      throw const AppException(
        code: 'BACKUP_INVALID',
        message: 'The selected file is not a valid PlanIT backup.',
      );
    }
  }

  Future<void> deleteProfile(
    String token, {
    required String password,
    required String confirmation,
  }) async {
    try {
      await _client.raw.delete<void>(
        _client.url('/privacy/profile'),
        data: <String, String>{
          'password': password,
          'confirmation': confirmation,
        },
        options: Options(headers: _auth(token)),
      );
    } on DioException catch (error) {
      throw AppException.fromDio(error);
    }
  }

  Future<PrivacyDownload> _download(
    String token,
    String path, {
    Map<String, Object?>? query,
    required String fallbackFilename,
  }) async {
    try {
      final response = await _client.raw.get<List<int>>(
        _client.url(path),
        queryParameters: query,
        options: Options(
          headers: _auth(token),
          responseType: ResponseType.bytes,
        ),
      );
      final bytes = response.data;
      if (bytes == null) {
        throw const AppException(
          code: 'INVALID_SERVER_RESPONSE',
          message: 'The server returned an empty export.',
        );
      }
      return PrivacyDownload(
        filename: _filename(response.headers, fallbackFilename),
        bytes: bytes,
      );
    } on DioException catch (error) {
      throw AppException.fromDio(error);
    }
  }

  static String _filename(Headers headers, String fallback) {
    final disposition = headers.value('content-disposition');
    final match = disposition == null
        ? null
        : RegExp('filename="?([^";]+)"?').firstMatch(disposition);
    final candidate = match?.group(1)?.trim();
    return candidate == null || candidate.isEmpty ? fallback : candidate;
  }

  static Map<String, String> _auth(String token) => <String, String>{
    'Authorization': 'Bearer $token',
  };

  static Map<String, Object?> _requiredMap(Object? value) {
    if (value is! Map) throw const FormatException();
    return Map<String, Object?>.from(value);
  }

  static List<T> _decodeList<T>(
    Object? value,
    T Function(Map<String, Object?>) decode,
  ) {
    if (value == null) return <T>[];
    if (value is! List) throw const FormatException();
    return value.map((item) => decode(_requiredMap(item))).toList();
  }
}
