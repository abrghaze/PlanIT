import 'dart:convert';
import 'package:drift/native.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planit_mobile/core/database/app_database.dart';
import 'package:planit_mobile/core/money/money.dart';
import 'package:planit_mobile/features/accounts/data/accounts_local_data_source.dart';
import 'package:planit_mobile/features/accounts/domain/account.dart';
import 'package:planit_mobile/features/offline_finance/data/offline_finance_store.dart';
import 'package:planit_mobile/features/settings/data/local_data_export.dart';
import 'package:planit_mobile/features/transactions/data/transactions_local_data_source.dart';
import 'package:planit_mobile/features/transactions/domain/transaction.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppDatabase database;
  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
    FlutterSecureStorage.setMockInitialValues({});
  });
  tearDown(() => database.close());

  Future<void> seed(String owner) async {
    await AccountsLocalDataSource(database).queueCreate(
      ownerId: owner,
      operationId: '$owner-create-account',
      draft: AccountDraft(
        id: '$owner-cash',
        name: '=private-$owner',
        type: AccountType.cash,
        openingBalance: Money.parse('100', 'MAD'),
        openedAt: DateTime(2026, 10, 1),
        includeInTotal: true,
        allowNegative: false,
        sortOrder: 0,
      ),
    );
    await TransactionsLocalDataSource(database).queueCreate(
      ownerId: owner,
      draft: TransactionDraft(
        id: '$owner-expense',
        clientOperationId: '$owner-create',
        accountId: '$owner-cash',
        type: TransactionType.expense,
        amount: Money.parse('12.3456', 'MAD'),
        occurredAt: DateTime(2026, 10, 2),
        categoryId: null,
        counterparty: 'Shop, "Cafe"',
        note: 'line one\nline two',
        tagIds: [],
      ),
      postAfterCreate: true,
      postOperationId: '$owner-post',
    );
  }

  test(
    'offline CSV includes unsent work, exact decimals, proper quotes and no other owner',
    () async {
      await seed('owner-a');
      await seed('owner-b');
      final csv = utf8.decode(
        (await LocalDataExport(database).transactions('owner-a')).bytes,
      );
      expect(csv, contains('12.3456'));
      expect(csv, contains('Shop, ""Cafe""'));
      expect(csv, contains("'=private-owner-a"));
      expect(csv, contains('"DRAFT"'));
      expect(csv, contains('"POST"'));
      expect(csv, isNot(contains('owner-b')));
      final balances = utf8.decode(
        (await LocalDataExport(database).accounts('owner-a')).bytes,
      );
      expect(balances, contains('"100.0000","-12.3456","87.6544"'));
    },
  );

  test(
    'recovery archive includes owner queue and local records but no credentials',
    () async {
      await seed('owner-a');
      await seed('owner-b');
      FlutterSecureStorage.setMockInitialValues({
        'planit.auth.session.v1': 'private-secret',
      });
      final download = await LocalDataExport(
        database,
      ).archive('owner-a', SecureOfflineFinanceStore());
      final text = utf8.decode(download.bytes);
      final archive = jsonDecode(text) as Map<String, dynamic>;
      final tables = archive['tables'] as Map<String, dynamic>;
      expect((tables['outbox_operations'] as List).length, 3);
      expect((tables['cached_accounts'] as List).length, 1);
      expect(text, isNot(contains('owner-b')));
      expect(text, isNot(contains('private-secret')));
      expect(archive['format'], 'planit-device-recovery-archive');
      expect(await database.watchPendingOperationCount('owner-a').first, 3);
    },
  );

  test('spreadsheet formulas are escaped without changing numeric money', () {
    for (final text in [
      '=SUM(1,2)',
      '+cmd',
      '-cmd',
      '@SUM(1)',
      '  =cmd',
      '\tcmd',
      '\rcmd',
    ]) {
      expect(csvCell(text), startsWith('"\''));
    }
    expect(csvCell('-12.3456', numeric: true), '"-12.3456"');
    expect(csvCell('A "quoted", café'), '"A ""quoted"", café"');
  });
}
