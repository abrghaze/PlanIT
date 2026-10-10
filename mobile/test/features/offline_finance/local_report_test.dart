import 'package:flutter_test/flutter_test.dart';
import 'package:planit_mobile/core/money/money.dart';
import 'package:planit_mobile/features/offline_finance/domain/local_report.dart';
import 'package:planit_mobile/features/offline_finance/domain/offline_finance.dart';
import 'package:planit_mobile/features/transactions/domain/transaction.dart';

LedgerTransaction entry(
  String id,
  String amount, {
  TransactionType type = TransactionType.expense,
  TransactionStatus status = TransactionStatus.posted,
  String currency = 'MAD',
  String? pending,
  int month = 10,
  int day = 5,
  String? category = 'food',
  DateTime? at,
}) => LedgerTransaction(
  id: id,
  ownerId: 'owner',
  accountId: 'cash',
  type: type,
  effect: type == TransactionType.income || type == TransactionType.refund
      ? TransactionEffect.inflow
      : TransactionEffect.outflow,
  amount: Money.parse(amount, currency),
  occurredAt: at ?? DateTime(2026, month, day),
  status: status,
  categoryId: category,
  counterparty: null,
  note: null,
  tagIds: [],
  parentTransactionId: null,
  reversalOfId: null,
  clientOperationId: id,
  version: 1,
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
  syncState: pending == null
      ? LocalTransactionSyncState.synced
      : LocalTransactionSyncState.pending,
  pendingAction: pending,
  lastSyncError: null,
);

void main() {
  final month = DateTime(2026, 10);
  test(
    'phone report includes pending posts, refunds, fees and uncategorized expenses',
    () {
      final report = buildLocalReport(
        currency: 'MAD',
        month: month,
        transactions: [
          entry('food', '100.1200'),
          entry('refund', '10.0100', type: TransactionType.refund),
          entry('income', '900', type: TransactionType.income),
          entry(
            'pending',
            '20',
            pending: 'POST',
            status: TransactionStatus.draft,
          ),
          entry('fee', '3', type: TransactionType.transferFee, category: null),
          entry('transfer', '2000', type: TransactionType.transferOut),
          entry('loan', '3000', type: TransactionType.loanPrincipalOut),
          entry('draft', '777', status: TransactionStatus.draft),
          entry('void', '888', status: TransactionStatus.voided),
        ],
      );
      expect(report.grossSpending, Money.parse('123.12', 'MAD'));
      expect(report.netSpending, Money.parse('113.11', 'MAD'));
      expect(report.remainingIncome, Money.parse('786.89', 'MAD'));
      expect(report.categories['food'], Money.parse('110.11', 'MAD'));
      expect(report.categories[''], Money.parse('3', 'MAD'));
      expect(report.sources.length, 5);
      expect(report.pendingCount, 1);
    },
  );

  test(
    'month boundaries, future entries and currencies never bleed into totals',
    () {
      final rows = [
        entry('prior', '500', month: 9, day: 30),
        entry('next', '600', month: 11, day: 1),
        entry('today', '20'),
        entry('future', '700', day: 20),
        entry('foreign', '40', currency: 'EUR'),
      ];
      final report = buildLocalReport(
        currency: 'MAD',
        month: month,
        asOf: DateTime(2026, 10, 10),
        transactions: rows,
      );
      expect(report.netSpending, Money.parse('20', 'MAD'));
      expect(report.omittedCurrencies, {'EUR'});
      final euros = buildLocalReport(
        currency: 'EUR',
        month: month,
        transactions: rows,
      );
      expect(euros.netSpending, Money.parse('40', 'EUR'));
    },
  );

  test(
    'refunds exceeding this month expenses remain visible instead of destroying value',
    () {
      final report = buildLocalReport(
        currency: 'MAD',
        month: month,
        transactions: [
          entry('refund', '100', type: TransactionType.refund),
          entry('expense', '20'),
        ],
      );
      expect(report.netSpending, Money.parse('-80', 'MAD'));
      expect(report.remainingIncome, Money.parse('80', 'MAD'));
      expect(report.categories['food'], Money.parse('-80', 'MAD'));
    },
  );

  test(
    'pending reversal undoes original movement without double-counting it',
    () {
      final expense = entry('expense', '40', pending: 'REVERSE');
      final salary = entry(
        'salary',
        '100',
        type: TransactionType.income,
        pending: 'REVERSE',
      );
      final report = buildLocalReport(
        currency: 'MAD',
        month: month,
        transactions: [expense, salary],
      );
      expect(report.netSpending, Money.zero('MAD'));
      expect(report.income, Money.zero('MAD'));
      expect(report.pendingCount, 2);
      expect(
        buildPendingAccountBalances([expense])['cash']!.delta,
        Money.parse('40', 'MAD'),
      );
      expect(
        buildPendingAccountBalances([salary])['cash']!.delta,
        Money.parse('-100', 'MAD'),
      );
      expect(
        buildPendingAccountBalances([entry('posted', '70', pending: 'POST')]),
        isEmpty,
      );
    },
  );

  test(
    'budget copying preserves existing limits and skips archived categories',
    () {
      CategoryBudget budget(
        String id,
        String category,
        String month,
        String amount,
      ) => CategoryBudget(
        id: id,
        categoryId: category,
        monthKey: month,
        limit: Money.parse(amount, 'MAD'),
        warningPercent: 80,
        updatedAt: DateTime(2026),
      );
      final original = [
        budget('food-old', 'food', '2026-09', '500'),
        budget('travel-old', 'travel', '2026-09', '300'),
        budget('archived-old', 'archived', '2026-09', '200'),
        budget('food-new', 'food', '2026-10', '600'),
      ];
      final copied = copyMissingBudgets(
        budgets: original,
        fromMonth: '2026-09',
        toMonth: '2026-10',
        activeCategoryIds: {'food', 'travel'},
        newId: () => 'new-travel',
        now: month,
      );
      expect(copied.length, 5);
      expect(copied.last.limit, Money.parse('300', 'MAD'));
      expect(
        copied.singleWhere((b) => b.id == 'food-new').limit,
        Money.parse('600', 'MAD'),
      );
      expect(
        copyMissingBudgets(
          budgets: copied,
          fromMonth: '2026-09',
          toMonth: '2026-10',
          activeCategoryIds: {'food', 'travel'},
          newId: () => 'unused',
          now: month,
        ).length,
        5,
      );
      final progress = CategoryBudgetProgress(
        budget: copied.last,
        spent: Money.parse('375', 'MAD'),
      );
      expect(progress.overLimit, Money.parse('75', 'MAD'));
      expect(progress.percentUsed, 125);
    },
  );

  test('budget warning threshold uses exact arithmetic', () {
    final budget = CategoryBudget(
      id: 'b',
      categoryId: 'food',
      monthKey: '2026-10',
      limit: Money.parse('100', 'MAD'),
      warningPercent: 80,
      updatedAt: month,
    );
    expect(
      CategoryBudgetProgress(
        budget: budget,
        spent: Money.parse('79.9999', 'MAD'),
      ).isNearLimit,
      isFalse,
    );
    expect(
      CategoryBudgetProgress(
        budget: budget,
        spent: Money.parse('80', 'MAD'),
      ).isNearLimit,
      isTrue,
    );
  });
}
