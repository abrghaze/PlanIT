import 'dart:async';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planit_mobile/core/money/money.dart';
import 'package:planit_mobile/features/offline_finance/data/local_write_queue.dart';
import 'package:planit_mobile/features/offline_finance/data/offline_finance_store.dart';
import 'package:planit_mobile/features/offline_finance/domain/offline_finance.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));
  test(
    'corrupt or structurally invalid finance data remains intact for recovery',
    () async {
      for (final raw in ['{broken', '{}', '[42]']) {
        FlutterSecureStorage.setMockInitialValues({
          'planit.offline.budgets.v1.owner': raw,
        });
        await expectLater(
          SecureOfflineFinanceStore().readBudgets('owner'),
          throwsFormatException,
        );
        expect(
          await const FlutterSecureStorage().read(
            key: 'planit.offline.budgets.v1.owner',
          ),
          raw,
        );
      }
    },
  );
  test(
    'budgets survive a new store instance and remain owner isolated',
    () async {
      final budget = CategoryBudget(
        id: 'budget',
        categoryId: 'food',
        monthKey: '2026-10',
        limit: Money.parse('999.1234', 'MAD'),
        warningPercent: 90,
        updatedAt: DateTime.utc(2026, 10, 1),
      );
      await SecureOfflineFinanceStore().saveBudgets('owner', [budget]);
      expect(
        (await SecureOfflineFinanceStore().readBudgets('owner')).single.limit,
        budget.limit,
      );
      expect(await SecureOfflineFinanceStore().readBudgets('other'), isEmpty);
    },
  );
  test(
    'serialized writes prevent lost updates and recover after a failure',
    () async {
      final queue = LocalWriteQueue();
      final gate = Completer<void>();
      final values = <int>[];
      final first = queue.run(() async {
        await gate.future;
        values.add(1);
      });
      final second = queue.run(() async {
        values.add(2);
      });
      expect(values, isEmpty);
      gate.complete();
      await Future.wait([first, second]);
      expect(values, [1, 2]);
      await expectLater(
        queue.run<void>(() async => throw StateError('disk unavailable')),
        throwsStateError,
      );
      await queue.run(() async => values.add(3));
      expect(values, [1, 2, 3]);
    },
  );
}
