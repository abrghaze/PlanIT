import 'package:planit_mobile/features/accounts/domain/account.dart';

abstract interface class AccountsRemoteDataSource {
  Future<List<Account>> fetchAccounts({
    required String ownerId,
    required String accessToken,
  });
}
