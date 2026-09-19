import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planit_mobile/core/database/app_database.dart';
import 'package:planit_mobile/core/money/money.dart';
import 'package:planit_mobile/features/accounts/data/accounts_local_data_source.dart';
import 'package:planit_mobile/features/accounts/domain/account.dart';
import 'package:planit_mobile/features/transactions/data/transactions_local_data_source.dart';

void main() {
  late AppDatabase database;
  late AccountsLocalDataSource local;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
    local = AccountsLocalDataSource(database);
  });

  tearDown(() => database.close());

  test(
    'cache preserves exact money, sort order, and owner isolation',
    () async {
      await local.replace('owner-a', <Account>[
        _account(
          id: 'account-2',
          ownerId: 'owner-a',
          name: 'Second',
          amount: '20.1234',
          sortOrder: 2,
        ),
        _account(
          id: 'account-1',
          ownerId: 'owner-a',
          name: 'First',
          amount: '10.0001',
          sortOrder: 1,
        ),
      ]);
      await local.replace('owner-b', <Account>[
        _account(
          id: 'account-b',
          ownerId: 'owner-b',
          name: 'Private B',
          amount: '999.9999',
        ),
      ]);

      final ownerA = await local.read('owner-a');
      final ownerB = await local.read('owner-b');

      expect(ownerA.map((account) => account.name), <String>[
        'First',
        'Second',
      ]);
      expect(ownerA.first.calculatedBalance.toApiString(), '10.0001');
      expect(ownerA.last.calculatedBalance.toApiString(), '20.1234');
      expect(ownerB.single.name, 'Private B');

      await local.replace('owner-a', <Account>[
        _account(
          id: 'account-3',
          ownerId: 'owner-a',
          name: 'Replacement',
          amount: '5.0000',
        ),
      ]);

      expect((await local.read('owner-a')).single.name, 'Replacement');
      expect((await local.read('owner-b')).single.name, 'Private B');
    },
  );

  test('cache rejects rows attributed to a different owner', () {
    expect(
      () => local.replace('owner-a', <Account>[
        _account(
          id: 'account-b',
          ownerId: 'owner-b',
          name: 'Wrong owner',
          amount: '1.0000',
        ),
      ]),
      throwsArgumentError,
    );
  });

  test('database constraints reject invalid account ordering', () async {
    await expectLater(
      local.replace('owner-a', <Account>[
        _account(
          id: 'invalid',
          ownerId: 'owner-a',
          name: 'Invalid',
          amount: '1.0000',
          sortOrder: -1,
        ),
      ]),
      throwsA(isA<Exception>()),
    );
  });

  test(
    'offline account creation is atomic with its durable operation',
    () async {
      final account = await local.queueCreate(
        ownerId: 'owner-a',
        operationId: 'operation-account-create',
        draft: AccountDraft(
          id: 'offline-account',
          name: 'Offline wallet',
          type: AccountType.cash,
          openingBalance: Money.parse('75', 'MAD'),
          openedAt: DateTime.utc(2026, 9, 18),
          includeInTotal: true,
          allowNegative: false,
          sortOrder: 0,
        ),
      );

      expect(account.calculatedBalance, Money.parse('75', 'MAD'));
      expect((await local.read('owner-a')).single.id, 'offline-account');
      final operation =
          (await database.watchOutboxOperations('owner-a').first).single;
      expect(operation.type, 'ACCOUNT_CREATE');
      expect(operation.entityId, 'offline-account');
    },
  );

  test('offline account update is visible and queued once', () async {
    final current = _account(
      id: 'account-a',
      ownerId: 'owner-a',
      name: 'Wallet',
      amount: '100.0000',
    );
    await local.upsert(current);

    final updated = await local.queueUpdate(
      current: current,
      operationId: 'operation-account-update',
      patch: const AccountPatch(version: 1, name: 'Everyday wallet'),
    );

    expect(updated.name, 'Everyday wallet');
    expect((await local.read('owner-a')).single.name, 'Everyday wallet');
    await expectLater(
      local.queueUpdate(
        current: updated,
        operationId: 'operation-account-update-2',
        patch: const AccountPatch(version: 1, name: 'Duplicate edit'),
      ),
      throwsStateError,
    );
  });

  test('server refresh cannot erase a pending offline account', () async {
    await local.queueCreate(
      ownerId: 'owner-a',
      operationId: 'operation-account-create',
      draft: AccountDraft(
        id: 'offline-account',
        name: 'Offline wallet',
        type: AccountType.cash,
        openingBalance: Money.parse('25', 'MAD'),
        openedAt: DateTime.utc(2026, 9, 18),
        includeInTotal: true,
        allowNegative: false,
        sortOrder: 0,
      ),
    );

    await local.replace('owner-a', const <Account>[]);

    expect((await local.read('owner-a')).single.id, 'offline-account');
  });

  test(
    'discarding an account update restores the confirmed snapshot',
    () async {
      final current = _account(
        id: 'account-a',
        ownerId: 'owner-a',
        name: 'Confirmed wallet',
        amount: '100.0000',
      );
      await local.upsert(current);
      await local.queueUpdate(
        current: current,
        operationId: 'operation-account-update',
        patch: const AccountPatch(version: 1, name: 'Offline edit'),
      );
      final transactions = TransactionsLocalDataSource(database);
      final operation =
          (await transactions.watchPendingOperations('owner-a').first).single;

      await transactions.discardPendingOperation(operation);

      expect((await local.read('owner-a')).single.name, 'Confirmed wallet');
      expect(await database.watchPendingOperationCount('owner-a').first, 0);
    },
  );
}

Account _account({
  required String id,
  required String ownerId,
  required String name,
  required String amount,
  int sortOrder = 0,
}) {
  final now = DateTime.utc(2026, 8, 25, 12);
  return Account(
    id: id,
    ownerId: ownerId,
    name: name,
    type: AccountType.bank,
    currency: 'MAD',
    openingBalance: Money.parse(amount, 'MAD'),
    calculatedBalance: Money.parse(amount, 'MAD'),
    balanceAsOf: now,
    openedAt: now.subtract(const Duration(days: 30)),
    includeInTotal: true,
    allowNegative: false,
    status: AccountStatus.active,
    sortOrder: sortOrder,
    archivedAt: null,
    closedAt: null,
    version: 1,
    createdAt: now,
    updatedAt: now,
  );
}
