import 'package:planit_mobile/core/money/money.dart';
import 'package:planit_mobile/features/transactions/domain/transaction.dart';

String localMonthKey(DateTime value) {
  final local = value.toLocal();
  return '${local.year.toString().padLeft(4, '0')}-'
      '${local.month.toString().padLeft(2, '0')}';
}

final class CategoryBudget {
  const CategoryBudget({
    required this.id,
    required this.categoryId,
    required this.monthKey,
    required this.limit,
    required this.warningPercent,
    required this.updatedAt,
  });

  final String id;
  final String categoryId;
  final String monthKey;
  final Money limit;
  final int warningPercent;
  final DateTime updatedAt;

  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'category_id': categoryId,
    'month_key': monthKey,
    'limit_amount': limit.toApiString(),
    'currency': limit.currency,
    'warning_percent': warningPercent,
    'updated_at': updatedAt.toUtc().toIso8601String(),
  };

  factory CategoryBudget.fromJson(Map<String, Object?> json) => CategoryBudget(
    id: json['id']! as String,
    categoryId: json['category_id']! as String,
    monthKey: json['month_key']! as String,
    limit: Money.parse(
      json['limit_amount']! as String,
      json['currency']! as String,
    ),
    warningPercent: json['warning_percent']! as int,
    updatedAt: DateTime.parse(json['updated_at']! as String).toUtc(),
  );
}

final class QuickTransactionTemplate {
  const QuickTransactionTemplate({
    required this.id,
    required this.name,
    required this.type,
    required this.accountId,
    required this.categoryId,
    required this.amount,
    required this.counterparty,
    required this.note,
    required this.tagIds,
    required this.updatedAt,
  });

  final String id;
  final String name;
  final TransactionType type;
  final String? accountId;
  final String? categoryId;
  final Money? amount;
  final String? counterparty;
  final String? note;
  final List<String> tagIds;
  final DateTime updatedAt;

  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'name': name,
    'type': type.apiValue,
    'account_id': accountId,
    'category_id': categoryId,
    if (amount != null)
      'amount': <String, Object?>{
        'amount': amount!.toApiString(),
        'currency': amount!.currency,
      },
    'counterparty': counterparty,
    'note': note,
    'tag_ids': tagIds,
    'updated_at': updatedAt.toUtc().toIso8601String(),
  };

  factory QuickTransactionTemplate.fromJson(Map<String, Object?> json) {
    final amountPayload = json['amount'];
    final amount = amountPayload is Map
        ? Money.parse(
            amountPayload['amount']! as String,
            amountPayload['currency']! as String,
          )
        : null;
    return QuickTransactionTemplate(
      id: json['id']! as String,
      name: json['name']! as String,
      type: TransactionTypeContract.fromApi(json['type']! as String),
      accountId: json['account_id'] as String?,
      categoryId: json['category_id'] as String?,
      amount: amount,
      counterparty: json['counterparty'] as String?,
      note: json['note'] as String?,
      tagIds: (json['tag_ids'] as List? ?? const <Object>[])
          .whereType<String>()
          .toList(growable: false),
      updatedAt: DateTime.parse(json['updated_at']! as String).toUtc(),
    );
  }
}

final class LocalMonthlySummary {
  const LocalMonthlySummary({
    required this.monthKey,
    required this.currency,
    required this.spending,
    required this.income,
    required this.spendingByCategory,
    required this.pendingPostedCount,
    required this.omittedCurrencies,
  });

  final String monthKey;
  final String currency;
  final Money spending;
  final Money income;
  final Map<String, Money> spendingByCategory;
  final int pendingPostedCount;
  final Set<String> omittedCurrencies;

  Money get netIncome => income - spending;

  Money spendingFor(String categoryId) =>
      spendingByCategory[categoryId] ?? Money.zero(currency);

  bool get hasCurrencyWarning => omittedCurrencies.isNotEmpty;
}

final class CategoryBudgetProgress {
  const CategoryBudgetProgress({
    required this.budget,
    required this.spent,
  });

  final CategoryBudget budget;
  final Money spent;

  Money get remaining {
    final value = budget.limit - spent;
    return value.scaledAmount.isNegative ? Money.zero(value.currency) : value;
  }

  double get fraction {
    if (budget.limit.scaledAmount <= BigInt.zero) return 0;
    return (spent.scaledAmount.toDouble() /
            budget.limit.scaledAmount.toDouble())
        .clamp(0, 1)
        .toDouble();
  }

  int get percentUsed {
    if (budget.limit.scaledAmount <= BigInt.zero) return 0;
    return (spent.scaledAmount.toDouble() /
            budget.limit.scaledAmount.toDouble() *
            100)
        .round();
  }

  bool get isOverLimit => spent.scaledAmount > budget.limit.scaledAmount;

  bool get isNearLimit => percentUsed >= budget.warningPercent;
}

LocalMonthlySummary buildLocalMonthlySummary({
  required Iterable<LedgerTransaction> transactions,
  required String currency,
  DateTime? now,
}) {
  final reference = now ?? DateTime.now();
  final monthKey = localMonthKey(reference);
  var spending = Money.zero(currency);
  var income = Money.zero(currency);
  var pendingPostedCount = 0;
  final omittedCurrencies = <String>{};
  final spendingByCategory = <String, Money>{};

  for (final transaction in transactions) {
    if (localMonthKey(transaction.occurredAt) != monthKey ||
        !_countsAsPosted(transaction)) {
      continue;
    }
    if (transaction.amount.currency != currency) {
      omittedCurrencies.add(transaction.amount.currency);
      continue;
    }
    if (transaction.hasPendingWork) {
      pendingPostedCount += 1;
    }
    switch (transaction.type) {
      case TransactionType.expense:
      case TransactionType.transferFee:
        spending += transaction.amount;
        if (transaction.categoryId != null) {
          spendingByCategory.update(
            transaction.categoryId!,
            (value) => value + transaction.amount,
            ifAbsent: () => transaction.amount,
          );
        }
        break;
      case TransactionType.refund:
        spending -= transaction.amount;
        if (transaction.categoryId != null) {
          spendingByCategory.update(
            transaction.categoryId!,
            (value) => value - transaction.amount,
            ifAbsent: () => -transaction.amount,
          );
        }
        break;
      case TransactionType.income:
        income += transaction.amount;
        break;
      case TransactionType.transferOut:
      case TransactionType.transferIn:
      case TransactionType.loanPrincipalOut:
      case TransactionType.loanPrincipalIn:
      case TransactionType.debtRepaymentIn:
      case TransactionType.debtRepaymentOut:
      case TransactionType.reconciliationAdjustment:
      case TransactionType.reversal:
      case TransactionType.unknown:
        break;
    }
  }

  if (spending.scaledAmount.isNegative) {
    spending = Money.zero(currency);
  }
  final nonNegativeCategories = <String, Money>{
    for (final entry in spendingByCategory.entries)
      entry.key: entry.value.scaledAmount.isNegative
          ? Money.zero(currency)
          : entry.value,
  };
  return LocalMonthlySummary(
    monthKey: monthKey,
    currency: currency,
    spending: spending,
    income: income,
    spendingByCategory: nonNegativeCategories,
    pendingPostedCount: pendingPostedCount,
    omittedCurrencies: omittedCurrencies,
  );
}

bool _countsAsPosted(LedgerTransaction transaction) =>
    transaction.status == TransactionStatus.posted ||
    (transaction.status == TransactionStatus.draft &&
        transaction.pendingAction == 'POST');
