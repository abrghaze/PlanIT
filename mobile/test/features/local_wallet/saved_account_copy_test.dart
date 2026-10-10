import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planit_mobile/core/database/app_database.dart';
import 'package:planit_mobile/core/money/money.dart';
import 'package:planit_mobile/features/accounts/data/accounts_local_data_source.dart';
import 'package:planit_mobile/features/accounts/domain/account.dart';
import 'package:planit_mobile/features/local_wallet/data/saved_account_copy.dart';
import 'package:planit_mobile/features/local_wallet/data/wallet_store.dart';
import 'package:planit_mobile/features/transactions/data/transactions_local_data_source.dart';
import 'package:planit_mobile/features/transactions/domain/transaction.dart';

void main() {
  test(
    'copy preserves saved balances and outbox, separates owners and prevents duplicates',
    () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final accounts = AccountsLocalDataSource(db);
      final transactions = TransactionsLocalDataSource(db);
      for (final owner in ['owner', 'other']) {
        await accounts.queueCreate(
          ownerId: owner,
          operationId: '$owner-account',
          draft: AccountDraft(
            id: 'cash-$owner',
            name: 'Cash',
            type: AccountType.cash,
            openingBalance: Money.parse('100', 'MAD'),
            openedAt: DateTime(2026, 1),
            includeInTotal: true,
            allowNegative: false,
            sortOrder: 0,
          ),
        );
        await transactions.queueCreate(
          ownerId: owner,
          postAfterCreate: true,
          postOperationId: '$owner-post',
          draft: TransactionDraft(
            id: '$owner-expense',
            clientOperationId: '$owner-create',
            accountId: 'cash-$owner',
            type: TransactionType.expense,
            amount: Money.parse('12.3456', 'MAD'),
            occurredAt: DateTime(2026, 1, 2),
            categoryId: null,
            counterparty: 'Shop',
            note: 'Lunch',
            tagIds: [],
          ),
        );
      }
      final original = await db.watchTransactions('owner').first;
      final count = await db.watchPendingOperationCount('owner').first;
      final copy = await copySavedAccount(db, 'owner', 'MAD');
      expect(copy.accounts, hasLength(1));
      expect(copy.entries, hasLength(1));
      expect(copy.entries.single.note, 'Lunch');
      expect(copy.balance(copy.accounts.single), Money.parse('87.6544', 'MAD'));
      expect(copy.entries.every((r) => !r.id.contains('other')), isTrue);
      final local = WalletStore(db);
      await local.restore(copy, replace: false);
      await local.restore(
        await copySavedAccount(db, 'owner', 'MAD'),
        replace: false,
      );
      expect((await local.read()).entries, hasLength(1));
      expect(await db.watchPendingOperationCount('owner').first, count);
      expect(await db.watchTransactions('owner').first, original);
      expect(
        (await accounts.read('owner')).single.calculatedBalance,
        Money.parse('100', 'MAD'),
      );
    },
  );
}
