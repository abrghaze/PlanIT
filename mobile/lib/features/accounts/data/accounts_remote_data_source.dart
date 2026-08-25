import 'package:planit_mobile/features/accounts/domain/account.dart';

abstract interface class AccountsRemoteDataSource {
  Future<List<Account>> fetchAccounts({
    required String ownerId,
    required String accessToken,
  });

  Future<Account> createAccount({
    required String ownerId,
    required String accessToken,
    required String idempotencyKey,
    required AccountDraft draft,
  });

  Future<Account> updateAccount({
    required String ownerId,
    required String accessToken,
    required String accountId,
    required AccountPatch patch,
  });
}
