import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:planit_mobile/core/errors/app_exception.dart';
import 'package:planit_mobile/core/network/api_client.dart';
import 'package:uuid/uuid.dart';

final class MediaAsset {
  const MediaAsset({
    required this.id,
    required this.kind,
    required this.mimeType,
    required this.sizeBytes,
    required this.createdAt,
  });

  final String id;
  final String kind;
  final String mimeType;
  final int sizeBytes;
  final DateTime createdAt;

  factory MediaAsset.fromJson(Map<String, Object?> json) => MediaAsset(
    id: json['id']! as String,
    kind: json['kind']! as String,
    mimeType: json['mime_type']! as String,
    sizeBytes: json['size_bytes']! as int,
    createdAt: DateTime.parse(json['created_at']! as String).toUtc(),
  );
}

final class MediaApi {
  const MediaApi(this._client);
  final ApiClient _client;

  Future<List<MediaAsset>> list({
    required String token,
    required String entityType,
    required String entityId,
  }) async {
    try {
      final response = await _client.raw.get<Map<String, Object?>>(
        _client.url('/media'),
        queryParameters: <String, Object?>{
          'entity_type': entityType,
          'entity_id': entityId,
        },
        options: Options(headers: _auth(token)),
      );
      final values = response.data?['items'];
      if (values is! List) {
        throw const AppException(
          code: 'INVALID_SERVER_RESPONSE',
          message: 'The server returned an invalid attachment list.',
        );
      }
      return values
          .map(
            (value) => MediaAsset.fromJson(
              Map<String, Object?>.from(value! as Map),
            ),
          )
          .toList(growable: false);
    } on DioException catch (error) {
      throw AppException.fromDio(error);
    }
  }

  Future<String> readUrl({
    required String token,
    required String mediaId,
  }) async {
    try {
      final response = await _client.raw.get<Map<String, Object?>>(
        _client.url('/media/$mediaId/read-url'),
        options: Options(headers: _auth(token)),
      );
      final value = response.data?['read_url'];
      if (value is! String || value.isEmpty) {
        throw const AppException(
          code: 'INVALID_SERVER_RESPONSE',
          message: 'The server did not provide a receipt link.',
        );
      }
      return value;
    } on DioException catch (error) {
      throw AppException.fromDio(error);
    }
  }

  Future<void> delete({
    required String token,
    required String mediaId,
    required String operationId,
  }) async {
    try {
      await _client.raw.delete<void>(
        _client.url('/media/$mediaId'),
        options: Options(
          headers: <String, String>{
            ..._auth(token),
            'Idempotency-Key': operationId,
          },
        ),
      );
    } on DioException catch (error) {
      throw AppException.fromDio(error);
    }
  }

  Future<void> uploadImage({
    required String token,
    required String operationId,
    required String mediaId,
    required String entityType,
    required String entityId,
    required String mimeType,
    required Uint8List bytes,
  }) async {
    try {
      final reservation = await _client.raw.post<Map<String, Object?>>(
        _client.url('/media/uploads'),
        data: <String, Object?>{
          'id': mediaId,
          'entity_type': entityType,
          'entity_id': entityId,
          'mime_type': mimeType,
          'size_bytes': bytes.length,
        },
        options: Options(
          headers: <String, String>{
            'Authorization': 'Bearer $token',
            'Idempotency-Key': operationId,
          },
        ),
      );
      final url = reservation.data?['upload_url'];
      if (url is! String) {
        throw const AppException(
          code: 'INVALID_SERVER_RESPONSE',
          message: 'The server did not provide an upload URL.',
        );
      }
      await Dio().put<void>(
        url,
        data: Stream<List<int>>.value(bytes),
        options: Options(
          headers: <String, String>{
            'Content-Type': mimeType,
            'Content-Length': '${bytes.length}',
          },
        ),
      );
      final finalizeOperation = const Uuid().v4();
      await _client.raw.post<Map<String, Object?>>(
        _client.url('/media/uploads/$mediaId/finalize'),
        data: <String, Object?>{'id': mediaId},
        options: Options(
          headers: <String, String>{
            'Authorization': 'Bearer $token',
            'Idempotency-Key': finalizeOperation,
          },
        ),
      );
    } on DioException catch (error) {
      throw AppException.fromDio(error);
    }
  }

  static Map<String, String> _auth(String token) => <String, String>{
    'Authorization': 'Bearer $token',
  };
}
