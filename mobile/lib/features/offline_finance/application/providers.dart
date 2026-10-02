import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:planit_mobile/core/auth/application/auth_controller.dart';
import 'package:planit_mobile/core/money/money.dart';
import 'package:planit_mobile/features/offline_finance/data/local_write_queue.dart';
import 'package:planit_mobile/features/offline_finance/data/offline_finance_store.dart';
import 'package:planit_mobile/features/offline_finance/domain/offline_finance.dart';
import 'package:planit_mobile/features/transactions/application/providers.dart';
import 'package:uuid/uuid.dart';

final localClockProvider = Provider<DateTime>((ref) {
  final timer = Timer(const Duration(minutes: 1), ref.invalidateSelf);
  ref.onDispose(timer.cancel);
  return DateTime.now();
});

final Provider<OfflineFinanceStore> offlineFinanceStoreProvider =
    Provider<OfflineFinanceStore>((ref) => SecureOfflineFinanceStore());

final AsyncNotifierProvider<OfflineBudgetsController, List<CategoryBudget>>
offlineBudgetsProvider =
    AsyncNotifierProvider<OfflineBudgetsController, List<CategoryBudget>>(
      OfflineBudgetsController.new,
    );

final AsyncNotifierProvider<
  OfflineTemplatesController,
  List<QuickTransactionTemplate>
>
offlineTemplatesProvider =
    AsyncNotifierProvider<
      OfflineTemplatesController,
      List<QuickTransactionTemplate>
    >(OfflineTemplatesController.new);

final Provider<LocalMonthlySummary?> localMonthlySummaryProvider =
    Provider<LocalMonthlySummary?>((ref) {
      final session = ref.watch(authControllerProvider).session;
      final transactions = ref.watch(transactionsProvider).value;
      if (session == null || transactions == null) return null;
      return buildLocalMonthlySummary(
        transactions: transactions,
        currency: session.user.baseCurrency,
        now: ref.watch(localClockProvider),
      );
    });

final Provider<Map<String, PendingAccountBalance>>
pendingAccountBalancesProvider = Provider<Map<String, PendingAccountBalance>>((
  ref,
) {
  final transactions = ref.watch(transactionsProvider).value;
  if (transactions == null) return const <String, PendingAccountBalance>{};
  return buildPendingAccountBalances(transactions);
});

final Provider<List<CategoryBudgetProgress>> offlineBudgetProgressProvider =
    Provider<List<CategoryBudgetProgress>>((ref) {
      final summary = ref.watch(localMonthlySummaryProvider);
      final budgets = ref.watch(offlineBudgetsProvider).value;
      if (summary == null || budgets == null) {
        return const <CategoryBudgetProgress>[];
      }
      return budgets
          .where(
            (budget) =>
                budget.monthKey == summary.monthKey &&
                budget.limit.currency == summary.currency,
          )
          .map(
            (budget) => CategoryBudgetProgress(
              budget: budget,
              spent: summary.spendingFor(budget.categoryId),
            ),
          )
          .toList(growable: false)
        ..sort((left, right) => right.percentUsed.compareTo(left.percentUsed));
    });

final class OfflineBudgetsController
    extends AsyncNotifier<List<CategoryBudget>> {
  String? _ownerId;
  final _writes = LocalWriteQueue();

  Future<T> _forOwner<T>(Future<T> Function(String) action) {
    final requestedOwner = _ownerId;
    return _writes.run(() async {
      if (!ref.mounted ||
          requestedOwner == null ||
          _ownerId != requestedOwner) {
        throw StateError('The active account changed. Please try again.');
      }
      return action(requestedOwner);
    });
  }

  @override
  Future<List<CategoryBudget>> build() async {
    final ownerId = ref.watch(
      authControllerProvider.select((state) => state.session?.user.id),
    );
    _ownerId = ownerId;
    if (ownerId == null) return const <CategoryBudget>[];
    return ref.read(offlineFinanceStoreProvider).readBudgets(ownerId);
  }

  Future<void> save({
    required String categoryId,
    required String monthKey,
    required String amount,
    required String currency,
    required int warningPercent,
    String? id,
  }) => _forOwner((ownerId) async {
    final current = await future;
    if (_ownerId != ownerId) throw StateError('The active account changed.');
    if (!RegExp(r'^\d{4}-(0[1-9]|1[0-2])$').hasMatch(monthKey) ||
        warningPercent < 1 ||
        warningPercent > 100) {
      throw const FormatException('Invalid budget month or warning threshold.');
    }
    final limit = Money.parse(amount, currency);
    if (limit.scaledAmount <= BigInt.zero) {
      throw const FormatException('A budget must be greater than zero.');
    }
    final budget = CategoryBudget(
      id: id ?? const Uuid().v4(),
      categoryId: categoryId,
      monthKey: monthKey,
      limit: limit,
      warningPercent: warningPercent,
      updatedAt: DateTime.now().toUtc(),
    );
    final next = <CategoryBudget>[
      for (final value in current)
        if (value.id != budget.id &&
            !(value.categoryId == budget.categoryId &&
                value.monthKey == budget.monthKey))
          value,
      budget,
    ];
    await ref.read(offlineFinanceStoreProvider).saveBudgets(ownerId, next);
    if (ref.mounted && _ownerId == ownerId) {
      state = AsyncData<List<CategoryBudget>>(_sortedBudgets(next));
    }
  });

  Future<void> remove(String id) => _forOwner((ownerId) async {
    final current = await future;
    if (_ownerId != ownerId) throw StateError('The active account changed.');
    final next = current.where((value) => value.id != id).toList();
    await ref.read(offlineFinanceStoreProvider).saveBudgets(ownerId, next);
    if (ref.mounted && _ownerId == ownerId) {
      state = AsyncData<List<CategoryBudget>>(_sortedBudgets(next));
    }
  });

  Future<int> copyPreviousMonth(
    DateTime month,
    Set<String> activeCategoryIds,
  ) => _forOwner((ownerId) async {
    final current = await future;
    if (_ownerId != ownerId) throw StateError('The active account changed.');
    final next = copyMissingBudgets(
      budgets: current,
      fromMonth: localMonthKey(DateTime(month.year, month.month - 1)),
      toMonth: localMonthKey(month),
      activeCategoryIds: activeCategoryIds,
      newId: const Uuid().v4,
      now: DateTime.now(),
    );
    await ref.read(offlineFinanceStoreProvider).saveBudgets(ownerId, next);
    if (ref.mounted && _ownerId == ownerId) {
      state = AsyncData(_sortedBudgets(next));
    }
    return next.length - current.length;
  });
}

final class OfflineTemplatesController
    extends AsyncNotifier<List<QuickTransactionTemplate>> {
  String? _ownerId;
  final _writes = LocalWriteQueue();

  Future<T> _forOwner<T>(Future<T> Function(String) action) {
    final requestedOwner = _ownerId;
    return _writes.run(() async {
      if (!ref.mounted ||
          requestedOwner == null ||
          _ownerId != requestedOwner) {
        throw StateError('The active account changed. Please try again.');
      }
      return action(requestedOwner);
    });
  }

  @override
  Future<List<QuickTransactionTemplate>> build() async {
    final ownerId = ref.watch(
      authControllerProvider.select((state) => state.session?.user.id),
    );
    _ownerId = ownerId;
    if (ownerId == null) return const <QuickTransactionTemplate>[];
    return ref.read(offlineFinanceStoreProvider).readTemplates(ownerId);
  }

  Future<void> save(QuickTransactionTemplate template) => _forOwner((
    ownerId,
  ) async {
    final current = await future;
    if (_ownerId != ownerId) throw StateError('The active account changed.');
    final next = <QuickTransactionTemplate>[
      for (final value in current)
        if (value.id != template.id) value,
      template,
    ];
    await ref.read(offlineFinanceStoreProvider).saveTemplates(ownerId, next);
    if (ref.mounted && _ownerId == ownerId) {
      state = AsyncData<List<QuickTransactionTemplate>>(_sortedTemplates(next));
    }
  });

  Future<void> remove(String id) => _forOwner((ownerId) async {
    final current = await future;
    if (_ownerId != ownerId) throw StateError('The active account changed.');
    final next = current.where((value) => value.id != id).toList();
    await ref.read(offlineFinanceStoreProvider).saveTemplates(ownerId, next);
    if (ref.mounted && _ownerId == ownerId) {
      state = AsyncData<List<QuickTransactionTemplate>>(_sortedTemplates(next));
    }
  });
}

List<CategoryBudget> _sortedBudgets(Iterable<CategoryBudget> budgets) =>
    budgets.toList(growable: false)
      ..sort((left, right) => left.categoryId.compareTo(right.categoryId));

List<QuickTransactionTemplate> _sortedTemplates(
  Iterable<QuickTransactionTemplate> templates,
) =>
    templates.toList(growable: false)
      ..sort((left, right) => left.name.compareTo(right.name));
