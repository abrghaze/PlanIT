import 'package:flutter_test/flutter_test.dart';
import 'package:planit_mobile/core/money/money.dart';
import 'package:planit_mobile/features/offline_finance/domain/offline_finance.dart';
import 'package:planit_mobile/features/transactions/domain/transaction.dart';

void main() {
  test('local dashboard counts saved pending posts before synchronization', () {
    final now = DateTime(2026, 9, 14, 12);
    final summary = buildLocalMonthlySummary(
      currency: 'MAD',
      now: now,
      transactions: <LedgerTransaction>[
        _transaction(
          id: 'coffee',
          amount: '35',
          occurredAt: now.subtract(const Duration(days: 1)),
          categoryId: 'food',
          status: TransactionStatus.draft,
          pendingAction: 'POST',
          syncState: LocalTransactionSyncState.pending,
        ),
        _transaction(
          id: 'salary',
          amount: '1500',
          occurredAt: now,
          type: TransactionType.income,
          effect: TransactionEffect.inflow,
        ),
        _transaction(
          id: 'last-month',
          amount: '999',
          occurredAt: DateTime(2026, 8, 31),
        ),
      ],
    );

    expect(summary.spending, Money.parse('35', 'MAD'));
    expect(summary.income, Money.parse('1500', 'MAD'));
    expect(summary.netIncome, Money.parse('1465', 'MAD'));
    expect(summary.spendingFor('food'), Money.parse('35', 'MAD'));
    expect(summary.pendingPostedCount, 1);
  });

  test(
    'local dashboard excludes other currencies instead of mixing totals',
    () {
      final now = DateTime(2026, 9, 14);
      final summary = buildLocalMonthlySummary(
        currency: 'MAD',
        now: now,
        transactions: <LedgerTransaction>[
          _transaction(id: 'mad', amount: '20', occurredAt: now),
          _transaction(
            id: 'eur',
            amount: '7',
            currency: 'EUR',
            occurredAt: now,
          ),
        ],
      );

      expect(summary.spending, Money.parse('20', 'MAD'));
      expect(summary.omittedCurrencies, <String>{'EUR'});
      expect(summary.hasCurrencyWarning, isTrue);
    },
  );

  test('refunds cannot make a category budget show negative spending', () {
    final now = DateTime(2026, 9, 14);
    final summary = buildLocalMonthlySummary(
      currency: 'MAD',
      now: now,
      transactions: <LedgerTransaction>[
        _transaction(
          id: 'purchase',
          amount: '25',
          occurredAt: now,
          categoryId: 'home',
        ),
        _transaction(
          id: 'refund',
          amount: '30',
          occurredAt: now,
          categoryId: 'home',
          type: TransactionType.refund,
          effect: TransactionEffect.inflow,
        ),
      ],
    );
    final budget = CategoryBudget(
      id: 'home-september',
      categoryId: 'home',
      monthKey: '2026-09',
      limit: Money.parse('100', 'MAD'),
      warningPercent: 80,
      updatedAt: now,
    );
    final progress = CategoryBudgetProgress(
      budget: budget,
      spent: summary.spendingFor('home'),
    );

    expect(summary.spending, Money.zero('MAD'));
    expect(progress.spent, Money.zero('MAD'));
    expect(progress.remaining, Money.parse('100', 'MAD'));
    expect(progress.percentUsed, 0);
  });

  test(
    'pending posted entries produce per-account estimated balance deltas',
    () {
      final now = DateTime(2026, 9, 14);
      final balances = buildPendingAccountBalances(<LedgerTransaction>[
        _transaction(
          id: 'expense',
          amount: '40',
          occurredAt: now,
          status: TransactionStatus.draft,
          pendingAction: 'POST',
          syncState: LocalTransactionSyncState.pending,
        ),
        _transaction(
          id: 'income',
          amount: '100',
          occurredAt: now,
          type: TransactionType.income,
          effect: TransactionEffect.inflow,
          status: TransactionStatus.draft,
          pendingAction: 'POST',
          syncState: LocalTransactionSyncState.retry,
        ),
      ]);

      expect(balances['cash']?.delta, Money.parse('60', 'MAD'));
      expect(balances['cash']?.transactionCount, 2);
    },
  );
}

LedgerTransaction _transaction({
  required String id,
  required String amount,
  required DateTime occurredAt,
  String currency = 'MAD',
  String? categoryId,
  TransactionType type = TransactionType.expense,
  TransactionEffect effect = TransactionEffect.outflow,
  TransactionStatus status = TransactionStatus.posted,
  LocalTransactionSyncState syncState = LocalTransactionSyncState.synced,
  String? pendingAction,
}) {
  return LedgerTransaction(
    id: id,
    ownerId: 'owner-a',
    accountId: 'cash',
    type: type,
    effect: effect,
    amount: Money.parse(amount, currency),
    occurredAt: occurredAt.toUtc(),
    status: status,
    categoryId: categoryId,
    counterparty: null,
    note: null,
    tagIds: const <String>[],
    parentTransactionId: null,
    reversalOfId: null,
    clientOperationId: 'operation-$id',
    version: 1,
    createdAt: occurredAt.toUtc(),
    updatedAt: occurredAt.toUtc(),
    syncState: syncState,
    pendingAction: pendingAction,
    lastSyncError: null,
  );
}
