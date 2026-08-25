import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planit_mobile/core/database/app_database.dart';
import 'package:planit_mobile/core/errors/app_exception.dart';
import 'package:planit_mobile/core/money/money.dart';
import 'package:planit_mobile/features/transactions/data/transactions_local_data_source.dart';
import 'package:planit_mobile/features/transactions/data/transactions_remote_data_source.dart';
import 'package:planit_mobile/features/transactions/data/transactions_repository.dart';
import 'package:planit_mobile/features/transactions/domain/outbox_operation.dart';
import 'package:planit_mobile/features/transactions/domain/transaction.dart';

void main() {
  test(
    'network retry reuses one operation id and produces one entity',
    () async {
      final database = AppDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      final local = TransactionsLocalDataSource(database);
      final remote = _RetryingRemote();
      final repository = DefaultTransactionsRepository(
        remote: remote,
        local: local,
      );
      final draft = TransactionDraft(
        id: 'transaction-1',
        clientOperationId: 'operation-1',
        accountId: 'account-a',
        type: TransactionType.income,
        amount: Money.parse('50.0000', 'MAD'),
        occurredAt: DateTime.utc(2026, 8, 25, 12),
        categoryId: 'salary',
        counterparty: 'Employer',
        note: null,
        tagIds: const <String>[],
      );
      await repository.queueCreate(
        ownerId: 'owner-a',
        draft: draft,
        postAfterCreate: false,
        postOperationId: null,
      );

      final first = await repository.synchronize(
        ownerId: 'owner-a',
        accessToken: 'token',
        force: true,
      );
      final second = await repository.synchronize(
        ownerId: 'owner-a',
        accessToken: 'token',
        force: true,
      );

      expect(first.blocked, isTrue);
      expect(second.blocked, isFalse);
      expect(remote.operationIds, <String>['operation-1', 'operation-1']);
      expect((await repository.watch('owner-a').first), hasLength(1));
      expect(await repository.watchPendingCount('owner-a').first, 0);
    },
  );
}

final class _RetryingRemote implements TransactionsRemoteDataSource {
  final List<String> operationIds = <String>[];
  var calls = 0;

  @override
  Future<RemoteOperationResult> execute({
    required String accessToken,
    required PendingOperation operation,
  }) async {
    operationIds.add(operation.id);
    calls += 1;
    if (calls == 1) {
      throw const AppException(
        code: 'NETWORK_UNAVAILABLE',
        message: 'Offline',
        isNetworkFailure: true,
      );
    }
    final now = DateTime.utc(2026, 8, 25, 12);
    return RemoteOperationResult(
      primary: LedgerTransaction(
        id: operation.entityId,
        ownerId: operation.ownerId,
        accountId: 'account-a',
        type: TransactionType.income,
        effect: TransactionEffect.inflow,
        amount: Money.parse('50.0000', 'MAD'),
        occurredAt: now,
        status: TransactionStatus.draft,
        categoryId: 'salary',
        counterparty: 'Employer',
        note: null,
        tagIds: const <String>[],
        parentTransactionId: null,
        reversalOfId: null,
        clientOperationId: operation.id,
        version: 1,
        createdAt: now,
        updatedAt: now,
        syncState: LocalTransactionSyncState.synced,
        pendingAction: null,
        lastSyncError: null,
      ),
    );
  }

  @override
  Future<List<LedgerTransaction>> fetchTransactions({
    required String ownerId,
    required String accessToken,
  }) async {
    return const <LedgerTransaction>[];
  }
}
