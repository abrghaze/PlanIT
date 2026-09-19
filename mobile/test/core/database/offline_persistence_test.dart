import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planit_mobile/core/database/app_database.dart';
import 'package:planit_mobile/core/money/money.dart';
import 'package:planit_mobile/features/transactions/data/transactions_local_data_source.dart';
import 'package:planit_mobile/features/transactions/domain/transaction.dart';

void main() {
  test(
    'queued financial data and dashboards survive a local database restart',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'planit-offline-',
      );
      final databaseFile = File(
        '${directory.path}${Platform.pathSeparator}planit.sqlite',
      );
      final draft = TransactionDraft(
        id: 'offline-transaction',
        clientOperationId: 'offline-create',
        accountId: 'cash-account',
        type: TransactionType.expense,
        amount: Money.parse('47.2500', 'MAD'),
        occurredAt: DateTime.utc(2026, 9, 14, 12),
        categoryId: 'groceries',
        counterparty: 'Local market',
        note: 'Saved while offline',
        tagIds: const <String>['essential'],
      );

      final firstDatabase = AppDatabase(
        NativeDatabase.createInBackground(databaseFile),
      );
      await TransactionsLocalDataSource(firstDatabase).queueCreate(
        ownerId: 'offline-owner',
        draft: draft,
        postAfterCreate: true,
        postOperationId: 'offline-post',
      );
      await firstDatabase.saveAnalyticsDashboard(
        ownerId: 'offline-owner',
        cacheKey: 'THIS_MONTH',
        payloadJson: '{"cached":"analytics"}',
      );
      await firstDatabase.savePlanningSnapshot(
        ownerId: 'offline-owner',
        payloadJson: '{"cached":"planning"}',
      );
      await firstDatabase.close();

      final reopenedDatabase = AppDatabase(
        NativeDatabase.createInBackground(databaseFile),
      );
      addTearDown(() async {
        await reopenedDatabase.close();
        await directory.delete(recursive: true);
      });
      final local = TransactionsLocalDataSource(reopenedDatabase);

      final transactions = await local.watch('offline-owner').first;
      final operations = await local
          .watchPendingOperations('offline-owner')
          .first;

      expect(transactions, hasLength(1));
      expect(transactions.single.id, 'offline-transaction');
      expect(transactions.single.amount, Money.parse('47.2500', 'MAD'));
      expect(transactions.single.pendingAction, 'POST');
      expect(operations.map((value) => value.id), <String>[
        'offline-create',
        'offline-post',
      ]);
      expect(
        (await reopenedDatabase.readAnalyticsDashboard(
          'offline-owner',
          'THIS_MONTH',
        ))?.payloadJson,
        '{"cached":"analytics"}',
      );
      expect(
        (await reopenedDatabase.readPlanningSnapshot(
          'offline-owner',
        ))?.payloadJson,
        '{"cached":"planning"}',
      );
    },
  );

  test(
    'database upgrade is idempotent when current columns already exist',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'planit-upgrade-',
      );
      final databaseFile = File(
        '${directory.path}${Platform.pathSeparator}planit.sqlite',
      );
      final initial = AppDatabase(NativeDatabase(databaseFile));
      await initial.saveAnalyticsDashboard(
        ownerId: 'upgrade-owner',
        cacheKey: 'THIS_MONTH:2026-09',
        payloadJson: '{"preserved":true}',
      );
      await initial.close();

      final versionEditor = AppDatabase(NativeDatabase(databaseFile));
      await versionEditor.customStatement('PRAGMA user_version = 2');
      await versionEditor.close();

      final upgraded = AppDatabase(NativeDatabase(databaseFile));
      addTearDown(() async {
        await upgraded.close();
        await directory.delete(recursive: true);
      });

      final saved = await upgraded.readAnalyticsDashboard(
        'upgrade-owner',
        'THIS_MONTH:2026-09',
      );
      expect(saved?.payloadJson, '{"preserved":true}');
      expect(upgraded.schemaVersion, 5);
    },
  );
}
