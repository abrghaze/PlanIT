import 'package:dio/dio.dart';
import 'package:planit_mobile/core/errors/app_exception.dart';
import 'package:planit_mobile/core/network/api_client.dart';
import 'package:planit_mobile/features/accounts/data/accounts_remote_data_source.dart';
import 'package:planit_mobile/features/accounts/domain/account.dart';

final class AccountsApi implements AccountsRemoteDataSource {
  AccountsApi(this._client);

  final ApiClient _client;

  @override
  Future<List<Account>> fetchAccounts({
    required String ownerId,
    required String accessToken,
  }) async {
    try {
      final response = await _client.raw.get<Map<String, Object?>>(
        _client.url('/accounts'),
        options: Options(headers: _authorization(accessToken)),
      );
      final items = response.data?['items'];
      if (items is! List) {
        throw const AppException(
          code: 'INVALID_SERVER_RESPONSE',
          message: 'The server returned an invalid account list.',
        );
      }
      return items
          .map(
            (item) => Account.fromJson(
              Map<String, Object?>.from(item as Map),
              ownerId: ownerId,
            ),
          )
          .toList(growable: false);
    } on DioException catch (error) {
      throw AppException.fromDio(error);
    }
  }

  @override
  Future<Account> createAccount({
    required String ownerId,
    required String accessToken,
    required String idempotencyKey,
    required AccountDraft draft,
  }) async {
    try {
      final response = await _client.raw.post<Map<String, Object?>>(
        _client.url('/accounts'),
        data: draft.toJson(),
        options: Options(
          headers: <String, String>{
            ..._authorization(accessToken),
            'Idempotency-Key': idempotencyKey,
          },
        ),
      );
      return _parseAccount(response.data, ownerId: ownerId);
    } on DioException catch (error) {
      throw AppException.fromDio(error);
    }
  }

  @override
  Future<Account> updateAccount({
    required String ownerId,
    required String accessToken,
    required String accountId,
    required AccountPatch patch,
  }) async {
    try {
      final response = await _client.raw.patch<Map<String, Object?>>(
        _client.url('/accounts/$accountId'),
        data: patch.toJson(),
        options: Options(headers: _authorization(accessToken)),
      );
      return _parseAccount(response.data, ownerId: ownerId);
    } on DioException catch (error) {
      throw AppException.fromDio(error);
    }
  }

  static Map<String, String> _authorization(String accessToken) {
    return <String, String>{'Authorization': 'Bearer $accessToken'};
  }

  static Account _parseAccount(
    Map<String, Object?>? data, {
    required String ownerId,
  }) {
    if (data == null) {
      throw const AppException(
        code: 'INVALID_SERVER_RESPONSE',
        message: 'The server returned an incomplete account response.',
      );
    }
    return Account.fromJson(data, ownerId: ownerId);
  }
}
