import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planit_mobile/core/database/app_database.dart';
import 'package:planit_mobile/core/money/money.dart';
import 'package:planit_mobile/features/accounts/data/accounts_local_data_source.dart';
import 'package:planit_mobile/features/accounts/domain/account.dart';

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
