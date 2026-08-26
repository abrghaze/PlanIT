import 'dart:async';

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

  test(
    'specialized retry keeps its operation id and stores every movement',
    () async {
      final database = AppDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      final local = TransactionsLocalDataSource(database);
      final remote = _RetryingTransferRemote();
      final TransactionsRepository repository = DefaultTransactionsRepository(
        remote: remote,
        local: local,
      );

      await repository.queueFinancialOperation(
        ownerId: 'owner-a',
        operationId: 'operation-transfer',
        entityId: 'transfer-1',
        type: OutboxOperationType.transferCommit,
        payload: const <String, Object?>{
          'id': 'transfer-1',
          'client_operation_id': 'operation-transfer',
        },
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
      expect(remote.operationIds, <String>[
        'operation-transfer',
        'operation-transfer',
      ]);
      expect(await repository.watchPendingOperations('owner-a').first, isEmpty);
      expect(
        (await repository.watch('owner-a').first).map((value) => value.type),
        containsAll(<TransactionType>[
          TransactionType.transferOut,
          TransactionType.transferIn,
        ]),
      );
    },
  );

  test('concurrent synchronization calls share one FIFO processor', () async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final local = TransactionsLocalDataSource(database);
    final remote = _BlockingTransferRemote();
    final repository = DefaultTransactionsRepository(
      remote: remote,
      local: local,
    );
    await repository.queueFinancialOperation(
      ownerId: 'owner-a',
      operationId: 'operation-transfer',
      entityId: 'transfer-1',
      type: OutboxOperationType.transferCommit,
      payload: const <String, Object?>{
        'id': 'transfer-1',
        'client_operation_id': 'operation-transfer',
      },
    );

    final first = repository.synchronize(
      ownerId: 'owner-a',
      accessToken: 'token',
      force: true,
    );
    final second = repository.synchronize(
      ownerId: 'owner-a',
      accessToken: 'token',
      force: true,
    );
    await remote.started.future;

    expect(remote.calls, 1);
    remote.release.complete();
    final results = await Future.wait(<Future<TransactionSyncResult>>[
      first,
      second,
    ]);
    expect(results.every((result) => !result.blocked), isTrue);
    expect(remote.calls, 1);
  });
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
      transactions: <LedgerTransaction>[
        LedgerTransaction(
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
      ],
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

final class _RetryingTransferRemote implements TransactionsRemoteDataSource {
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
    return RemoteOperationResult(
      transactions: <LedgerTransaction>[
        _movement(
          operation: operation,
          id: 'source-transaction',
          accountId: 'account-a',
          type: TransactionType.transferOut,
          effect: TransactionEffect.outflow,
        ),
        _movement(
          operation: operation,
          id: 'destination-transaction',
          accountId: 'account-b',
          type: TransactionType.transferIn,
          effect: TransactionEffect.inflow,
        ),
      ],
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

final class _BlockingTransferRemote implements TransactionsRemoteDataSource {
  final Completer<void> started = Completer<void>();
  final Completer<void> release = Completer<void>();
  var calls = 0;

  @override
  Future<RemoteOperationResult> execute({
    required String accessToken,
    required PendingOperation operation,
  }) async {
    calls += 1;
    if (!started.isCompleted) {
      started.complete();
    }
    await release.future;
    return RemoteOperationResult(
      transactions: <LedgerTransaction>[
        _movement(
          operation: operation,
          id: 'source-transaction',
          accountId: 'account-a',
          type: TransactionType.transferOut,
          effect: TransactionEffect.outflow,
        ),
        _movement(
          operation: operation,
          id: 'destination-transaction',
          accountId: 'account-b',
          type: TransactionType.transferIn,
          effect: TransactionEffect.inflow,
        ),
      ],
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

LedgerTransaction _movement({
  required PendingOperation operation,
  required String id,
  required String accountId,
  required TransactionType type,
  required TransactionEffect effect,
}) {
  final now = DateTime.utc(2026, 8, 25, 12);
  return LedgerTransaction(
    id: id,
    ownerId: operation.ownerId,
    accountId: accountId,
    type: type,
    effect: effect,
    amount: Money.parse('40.0000', 'MAD'),
    occurredAt: now,
    status: TransactionStatus.posted,
    categoryId: null,
    counterparty: null,
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
  );
}
