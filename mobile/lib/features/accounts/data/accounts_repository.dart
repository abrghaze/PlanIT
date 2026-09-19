import 'package:planit_mobile/features/accounts/data/accounts_local_data_source.dart';
import 'package:planit_mobile/features/accounts/data/accounts_remote_data_source.dart';
import 'package:planit_mobile/features/accounts/domain/account.dart';

abstract interface class AccountsRepository {
  Stream<List<Account>> watch(String ownerId);

  Future<List<Account>> read(String ownerId);

  Future<void> refresh({required String ownerId, required String accessToken});

  Future<Account> create({
    required String ownerId,
    required String idempotencyKey,
    required AccountDraft draft,
  });

  Future<Account> update({
    required String ownerId,
    required String accountId,
    required String operationId,
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
    required String idempotencyKey,
    required AccountDraft draft,
  }) async {
    return local.queueCreate(
      ownerId: ownerId,
      draft: draft,
      operationId: idempotencyKey,
    );
  }

  @override
  Future<Account> update({
    required String ownerId,
    required String accountId,
    required String operationId,
    required AccountPatch patch,
  }) async {
    final accounts = await local.read(ownerId);
    final current = accounts
        .where((value) => value.id == accountId)
        .firstOrNull;
    if (current == null) {
      throw StateError('This account is not available on the phone.');
    }
    return local.queueUpdate(
      current: current,
      patch: patch,
      operationId: operationId,
    );
  }
}
