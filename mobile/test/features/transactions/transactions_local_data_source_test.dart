import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planit_mobile/core/database/app_database.dart';
import 'package:planit_mobile/core/money/money.dart';
import 'package:planit_mobile/features/transactions/data/transactions_local_data_source.dart';
import 'package:planit_mobile/features/transactions/domain/outbox_operation.dart';
import 'package:planit_mobile/features/transactions/domain/transaction.dart';

void main() {
  late AppDatabase database;
  late TransactionsLocalDataSource local;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
    local = TransactionsLocalDataSource(database);
  });

  tearDown(() => database.close());

  test('local transaction and ordered outbox operations are atomic', () async {
    final draft = _draft(
      transactionId: 'transaction-1',
      operationId: 'operation-create',
    );

    await local.queueCreate(
      ownerId: 'owner-a',
      draft: draft,
      postAfterCreate: true,
      postOperationId: 'operation-post',
    );

    final cached = await local.watch('owner-a').first;
    expect(cached, hasLength(1));
    expect(cached.single.status, TransactionStatus.draft);
    expect(cached.single.pendingAction, 'POST');
    expect(await local.watchPendingCount('owner-a').first, 2);

    final create = await local.readNextOperation('owner-a', force: true);
    expect(create?.id, 'operation-create');
    expect(create?.type, OutboxOperationType.createDraft);

    await local.acknowledge(
      operation: create!,
      canonical: _canonical(
        id: 'transaction-1',
        clientOperationId: 'operation-create',
        status: TransactionStatus.draft,
        version: 1,
      ),
    );
    final post = await local.readNextOperation('owner-a', force: true);
    expect(post?.id, 'operation-post');
    expect(post?.payload, <String, Object?>{'version': 1});

    await local.acknowledge(
      operation: post!,
      canonical: _canonical(
        id: 'transaction-1',
        clientOperationId: 'operation-create',
        status: TransactionStatus.posted,
        version: 2,
      ),
    );
    final posted = (await local.watch('owner-a').first).single;
    expect(posted.status, TransactionStatus.posted);
    expect(posted.syncState, LocalTransactionSyncState.synced);
    expect(await local.watchPendingCount('owner-a').first, 0);
  });

  test(
    'a duplicate operation rolls back the local transaction write',
    () async {
      await local.queueCreate(
        ownerId: 'owner-a',
        draft: _draft(
          transactionId: 'transaction-1',
          operationId: 'same-operation',
        ),
        postAfterCreate: false,
        postOperationId: null,
      );

      await expectLater(
        local.queueCreate(
          ownerId: 'owner-a',
          draft: _draft(
            transactionId: 'transaction-2',
            operationId: 'same-operation',
          ),
          postAfterCreate: false,
          postOperationId: null,
        ),
        throwsA(isA<Exception>()),
      );

      final cached = await local.watch('owner-a').first;
      expect(cached.map((value) => value.id), <String>['transaction-1']);
      expect(await local.watchPendingCount('owner-a').first, 1);
    },
  );

  test(
    'retry retains the same operation identity and records backoff',
    () async {
      await local.queueCreate(
        ownerId: 'owner-a',
        draft: _draft(
          transactionId: 'transaction-1',
          operationId: 'stable-operation',
        ),
        postAfterCreate: false,
        postOperationId: null,
      );
      final operation = await local.readNextOperation('owner-a', force: true);
      await local.markFailure(
        operation: operation!,
        error: 'Offline',
        conflict: false,
      );

      expect(await local.readNextOperation('owner-a'), isNull);
      final retry = await local.readNextOperation('owner-a', force: true);
      expect(retry?.id, 'stable-operation');
      expect(retry?.attemptCount, 1);
      expect(retry?.payload, operation.payload);
      expect(
        (await local.watch('owner-a').first).single.syncState,
        LocalTransactionSyncState.retry,
      );
    },
  );

  test(
    'a parked conflict can be retried manually with the same identity',
    () async {
      await local.queueCreate(
        ownerId: 'owner-a',
        draft: _draft(
          transactionId: 'transaction-1',
          operationId: 'conflicted-operation',
        ),
        postAfterCreate: false,
        postOperationId: null,
      );
      final operation = await local.readNextOperation('owner-a', force: true);
      await local.markFailure(
        operation: operation!,
        error: 'Balance changed',
        conflict: true,
      );

      expect(await local.readNextOperation('owner-a'), isNull);
      final retry = await local.readNextOperation('owner-a', force: true);
      expect(retry?.id, 'conflicted-operation');
      expect(retry?.attemptCount, 1);
      expect(retry?.payload, operation.payload);
      expect(
        (await local.watch('owner-a').first).single.syncState,
        LocalTransactionSyncState.conflict,
      );

      await local.discardPending((await local.watch('owner-a').first).single);
      expect(await local.watchPendingCount('owner-a').first, 0);
      expect(await local.watch('owner-a').first, isEmpty);
    },
  );
}

TransactionDraft _draft({
  required String transactionId,
  required String operationId,
}) {
  return TransactionDraft(
    id: transactionId,
    clientOperationId: operationId,
    accountId: 'account-a',
    type: TransactionType.expense,
    amount: Money.parse('12.5000', 'MAD'),
    occurredAt: DateTime.utc(2026, 8, 25, 12),
    categoryId: 'category-a',
    counterparty: 'Shop',
    note: null,
    tagIds: const <String>['tag-a'],
  );
}

LedgerTransaction _canonical({
  required String id,
  required String clientOperationId,
  required TransactionStatus status,
  required int version,
}) {
  final now = DateTime.utc(2026, 8, 25, 12);
  return LedgerTransaction(
    id: id,
    ownerId: 'owner-a',
    accountId: 'account-a',
    type: TransactionType.expense,
    effect: TransactionEffect.outflow,
    amount: Money.parse('12.5000', 'MAD'),
    occurredAt: now,
    status: status,
    categoryId: 'category-a',
    counterparty: 'Shop',
    note: null,
    tagIds: const <String>['tag-a'],
    parentTransactionId: null,
    reversalOfId: null,
    clientOperationId: clientOperationId,
    version: version,
    createdAt: now,
    updatedAt: now,
    syncState: LocalTransactionSyncState.synced,
    pendingAction: null,
    lastSyncError: null,
  );
}
