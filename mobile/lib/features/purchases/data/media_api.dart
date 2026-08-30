import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:planit_mobile/core/errors/app_exception.dart';
import 'package:planit_mobile/core/network/api_client.dart';
import 'package:uuid/uuid.dart';

final class MediaApi {
  const MediaApi(this._client);
  final ApiClient _client;

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
}
