import 'dart:convert';
import 'dart:io';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planit_mobile/core/database/app_database.dart';
import 'package:planit_mobile/core/money/money.dart';
import 'package:planit_mobile/features/local_wallet/data/wallet_store.dart';
import 'package:planit_mobile/features/local_wallet/domain/wallet.dart';
import 'package:planit_mobile/features/transactions/domain/transaction.dart';

WalletAccount cash([String id = 'cash']) =>
    WalletAccount(id: id, name: id, opening: Money.parse('100', 'MAD'));
WalletEntry expense(String id, String amount, {String account = 'cash'}) =>
    WalletEntry(
      id: id,
      accountId: account,
      type: TransactionType.expense,
      amount: Money.parse(amount, 'MAD'),
      date: DateTime(2026, 10, 5),
      categoryId: 'food',
      note: 'test',
    );
void main() {
  late AppDatabase db;
  late WalletStore store;
  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    store = WalletStore(db);
  });
  tearDown(() async {
    await db.close();
  });
  test(
    'concurrent edits persist; corrections/deletion/undo recalculate exact balances',
    () async {
      await store.saveAccount(cash());
      await Future.wait([
        store.saveEntry(expense('a', '10.0001')),
        store.saveEntry(expense('b', '20.0002')),
      ]);
      var w = await store.read();
      expect(w.entries, hasLength(2));
      expect(w.balance(w.accounts.single), Money.parse('69.9997', 'MAD'));
      await store.saveEntry(expense('a', '7.0001'));
      await store.setDeleted('b', true);
      w = await store.read();
      expect(w.balance(w.accounts.single), Money.parse('92.9999', 'MAD'));
      await store.setDeleted('b', false);
      w = await store.read();
      expect(w.balance(w.accounts.single), Money.parse('72.9997', 'MAD'));
      expect(await db.watchPendingOperationCount('personal').first, 0);
    },
  );
  test(
    'paired transfers preserve total money and delete/undo atomically',
    () async {
      await store.saveAccount(cash());
      await store.saveAccount(cash('savings'));
      await store.change(
        (w) => w.copyWith(
          entries: [
            WalletEntry(
              id: 'out',
              accountId: 'cash',
              type: TransactionType.transferOut,
              amount: Money.parse('30', 'MAD'),
              date: DateTime(2026, 10, 5),
              categoryId: null,
              note: '',
              transferId: 'pair',
            ),
            WalletEntry(
              id: 'in',
              accountId: 'savings',
              type: TransactionType.transferIn,
              amount: Money.parse('30', 'MAD'),
              date: DateTime(2026, 10, 5),
              categoryId: null,
              note: '',
              transferId: 'pair',
            ),
          ],
        ),
      );
      var w = await store.read();
      expect(w.balance(w.accounts[0]), Money.parse('70', 'MAD'));
      expect(w.balance(w.accounts[1]), Money.parse('130', 'MAD'));
      await store.setDeleted('out', true);
      w = await store.read();
      expect(w.entries.every((e) => e.deleted), isTrue);
      await store.setDeleted('out', false);
      w = await store.read();
      expect(w.balance(w.accounts[0]), Money.parse('70', 'MAD'));
    },
  );
  test(
    'restore is duplicate free, rejects conflicts atomically and replacement is explicit',
    () async {
      await store.saveAccount(cash());
      await store.saveEntry(expense('a', '10'));
      final backup = await store.read();
      await store.restore(backup, replace: false);
      await store.restore(backup, replace: false);
      expect((await store.read()).entries, hasLength(1));
      await store.saveEntry(expense('a', '20'));
      final before = jsonEncode((await store.read()).toJson());
      await expectLater(
        store.restore(backup, replace: false),
        throwsFormatException,
      );
      expect(jsonEncode((await store.read()).toJson()), before);
      await store.restore(backup, replace: true);
      expect((await store.read()).balance(cash()), Money.parse('90', 'MAD'));
      final invalid = backup.copyWith(
        entries: [expense('bad', '5', account: 'missing')],
      );
      await expectLater(
        store.restore(invalid, replace: true),
        throwsFormatException,
      );
      expect((await store.read()).entries.single.id, 'a');
    },
  );
  test(
    'corrupt local snapshot is preserved and can be replaced with a validated backup',
    () async {
      await db.customStatement(
        "INSERT INTO local_wallet_snapshots(id,payload_json) VALUES ('personal','broken')",
      );
      await expectLater(store.read(), throwsFormatException);
      expect(
        (await db.select(db.localWalletSnapshots).getSingle()).payloadJson,
        'broken',
      );
      await store.restore(
        Wallet.empty().copyWith(accounts: [cash()]),
        replace: true,
      );
      expect((await store.read()).accounts, hasLength(1));
    },
  );
  test(
    'linked goals follow corrections and category/account references reject destructive edits',
    () async {
      await store.saveAccount(cash());
      await store.saveEntry(expense('a', '40'));
      final g = WalletGoal(
        id: 'goal',
        name: 'Emergency',
        target: Money.parse('200', 'MAD'),
        saved: Money.zero('MAD'),
        accountId: 'cash',
      );
      await store.change((w) => w.copyWith(goals: [g]));
      expect((await store.read()).goalSaved(g), Money.parse('60', 'MAD'));
      await expectLater(
        store.change((w) => w.copyWith(accounts: [])),
        throwsFormatException,
      );
      await expectLater(
        store.change((w) => w.copyWith(categories: {})),
        throwsFormatException,
      );
    },
  );
  test(
    'schema 5 upgrade preserves signed-in cache and local wallet survives reopening',
    () async {
      await db.close();
      final dir = await Directory.systemTemp.createTemp('planit-wallet-');
      final file = File('${dir.path}${Platform.pathSeparator}wallet.sqlite');
      final first = AppDatabase(NativeDatabase(file));
      await first.saveAnalyticsDashboard(
        ownerId: 'signed-owner',
        cacheKey: 'month',
        payloadJson: '{"preserved":true}',
      );
      await WalletStore(first).saveAccount(cash());
      await first.customStatement('DROP TABLE local_wallet_snapshots');
      await first.customStatement('PRAGMA user_version = 5');
      await first.close();
      final second = AppDatabase(NativeDatabase(file));
      expect(
        (await second.readAnalyticsDashboard(
          'signed-owner',
          'month',
        ))!.payloadJson,
        '{"preserved":true}',
      );
      await WalletStore(second).saveAccount(cash());
      await WalletStore(second).saveEntry(expense('offline', '3.50'));
      await second.close();
      final reopened = AppDatabase(NativeDatabase(file));
      try {
        final w = await WalletStore(reopened).read();
        expect(w.entries.single.id, 'offline');
        expect(w.balance(cash()), Money.parse('96.5', 'MAD'));
        expect(
          (await reopened.readAnalyticsDashboard(
            'signed-owner',
            'month',
          ))!.payloadJson,
          '{"preserved":true}',
        );
      } finally {
        await reopened.close();
        await dir.delete(recursive: true);
      }
    },
  );
}
