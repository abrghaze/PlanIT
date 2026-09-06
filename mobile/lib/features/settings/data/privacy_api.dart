import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:planit_mobile/core/errors/app_exception.dart';
import 'package:planit_mobile/core/network/api_client.dart';
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
  });

  final int restoredRows;
  final int ignoredReceiptFiles;
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

  Future<PrivacyDownload> backup(String token) => _download(
    token,
    '/privacy/backup.json',
    fallbackFilename: 'planit-backup.json',
  );

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
      final response = await _client.raw.post<Map<String, Object?>>(
        _client.url('/privacy/restore'),
        data: <String, Object?>{
          'password': password,
          'confirmation': 'RESTORE MY PLANIT DATA',
          'backup': Map<String, Object?>.from(decoded),
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
      );
    } on FormatException {
      throw const AppException(
        code: 'BACKUP_INVALID',
        message: 'The selected file is not valid JSON.',
      );
    } on DioException catch (error) {
      throw AppException.fromDio(error);
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
}
