import 'package:planit_mobile/features/accounts/data/accounts_local_data_source.dart';
import 'package:planit_mobile/features/accounts/data/accounts_remote_data_source.dart';
import 'package:planit_mobile/features/accounts/domain/account.dart';

abstract interface class AccountsRepository {
  Stream<List<Account>> watch(String ownerId);

  Future<List<Account>> read(String ownerId);

  Future<void> refresh({required String ownerId, required String accessToken});

  Future<Account> create({
    required String ownerId,
    required String accessToken,
    required String idempotencyKey,
    required AccountDraft draft,
  });

  Future<Account> update({
    required String ownerId,
    required String accessToken,
    required String accountId,
    required AccountPatch patch,
  });
}

final class DefaultAccountsRepository implements AccountsRepository {
  const DefaultAccountsRepository({required this.remote, required this.local});

  final AccountsRemoteDataSource remote;
  final AccountsLocalDataSource local;

  @override
  Stream<List<Account>> watch(String ownerId) => local.watch(ownerId);

  @override
  Future<List<Account>> read(String ownerId) => local.read(ownerId);

  @override
  Future<void> refresh({
    required String ownerId,
    required String accessToken,
  }) async {
    final accounts = await remote.fetchAccounts(
      ownerId: ownerId,
      accessToken: accessToken,
    );
    await local.replace(ownerId, accounts);
  }

  @override
  Future<Account> create({
    required String ownerId,
    required String accessToken,
    required String idempotencyKey,
    required AccountDraft draft,
  }) async {
    final account = await remote.createAccount(
      ownerId: ownerId,
      accessToken: accessToken,
      idempotencyKey: idempotencyKey,
      draft: draft,
    );
    _requireOwner(account, ownerId);
    await local.upsert(account);
    return account;
  }

  @override
  Future<Account> update({
    required String ownerId,
    required String accessToken,
    required String accountId,
    required AccountPatch patch,
  }) async {
    final account = await remote.updateAccount(
      ownerId: ownerId,
      accessToken: accessToken,
      accountId: accountId,
      patch: patch,
    );
    _requireOwner(account, ownerId);
    await local.upsert(account);
    return account;
  }

  static void _requireOwner(Account account, String ownerId) {
    if (account.ownerId != ownerId) {
      throw StateError('The account response belongs to another owner.');
    }
  }
}
