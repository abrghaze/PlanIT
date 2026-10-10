import 'package:planit_mobile/core/money/money.dart';
import 'package:planit_mobile/features/transactions/domain/transaction.dart';

const walletCurrencies = [
  'MAD',
  'USD',
  'EUR',
  'GBP',
  'CAD',
  'CHF',
  'JPY',
  'AUD',
  'INR',
  'AED',
];
String walletText(Object? value, {int max = 160}) {
  if (value is! String || value.trim().isEmpty || value.length > max) {
    throw const FormatException('Invalid or missing text.');
  }
  return value;
}

String walletCurrency(Object? value) {
  final code = walletText(value, max: 3);
  if (!RegExp(r'^[A-Z]{3}$').hasMatch(code)) {
    throw const FormatException('Invalid currency.');
  }
  return code;
}

Map<String, Object?> walletMap(Object? value) {
  if (value is! Map) throw const FormatException('Invalid backup record.');
  return Map<String, Object?>.from(value);
}

final class WalletAccount {
  const WalletAccount({
    required this.id,
    required this.name,
    required this.opening,
  });
  final String id, name;
  final Money opening;
  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'currency': opening.currency,
    'opening': opening.toApiString(),
  };
  factory WalletAccount.fromJson(Map<String, Object?> j) => WalletAccount(
    id: walletText(j['id']),
    name: walletText(j['name'], max: 120),
    opening: Money.parse(
      walletText(j['opening']),
      walletCurrency(j['currency']),
    ),
  );
}

final class WalletEntry {
  const WalletEntry({
    required this.id,
    required this.accountId,
    required this.type,
    required this.amount,
    required this.date,
    required this.categoryId,
    required this.note,
    this.deleted = false,
    this.transferId,
  });
  final String id, accountId, note;
  final TransactionType type;
  final Money amount;
  final DateTime date;
  final String? categoryId, transferId;
  final bool deleted;
  bool get inflow => [
    TransactionType.income,
    TransactionType.refund,
    TransactionType.transferIn,
  ].contains(type);
  WalletEntry withDeleted(bool value) => WalletEntry(
    id: id,
    accountId: accountId,
    type: type,
    amount: amount,
    date: date,
    categoryId: categoryId,
    note: note,
    deleted: value,
    transferId: transferId,
  );
  Map<String, Object?> toJson() => {
    'id': id,
    'account_id': accountId,
    'type': type.apiValue,
    'amount': amount.toApiString(),
    'currency': amount.currency,
    'date': date.toUtc().toIso8601String(),
    'category_id': categoryId,
    'note': note,
    'deleted': deleted,
    'transfer_id': transferId,
  };
  factory WalletEntry.fromJson(Map<String, Object?> j) {
    final type = TransactionTypeContract.fromApi(walletText(j['type']));
    final amount = Money.parse(
      walletText(j['amount']),
      walletCurrency(j['currency']),
    );
    if (![
          TransactionType.income,
          TransactionType.expense,
          TransactionType.refund,
          TransactionType.transferIn,
          TransactionType.transferOut,
        ].contains(type) ||
        amount.scaledAmount <= BigInt.zero ||
        j['deleted'] is! bool ||
        j['note'] is! String ||
        (j['note'] as String).length > 1000) {
      throw const FormatException('Invalid transaction.');
    }
    return WalletEntry(
      id: walletText(j['id']),
      accountId: walletText(j['account_id']),
      type: type,
      amount: amount,
      date: DateTime.parse(walletText(j['date'])).toUtc(),
      categoryId: j['category_id'] == null
          ? null
          : walletText(j['category_id']),
      note: j['note'] as String,
      deleted: j['deleted'] as bool,
      transferId: j['transfer_id'] == null
          ? null
          : walletText(j['transfer_id']),
    );
  }
  LedgerTransaction toLedger() => LedgerTransaction(
    id: id,
    ownerId: 'personal-wallet',
    accountId: accountId,
    type: type,
    effect: inflow ? TransactionEffect.inflow : TransactionEffect.outflow,
    amount: amount,
    occurredAt: date,
    status: deleted ? TransactionStatus.voided : TransactionStatus.posted,
    categoryId: categoryId,
    counterparty: note.isEmpty ? null : note,
    note: note,
    tagIds: const [],
    parentTransactionId: null,
    reversalOfId: null,
    clientOperationId: id,
    version: 1,
    createdAt: date,
    updatedAt: date,
    syncState: LocalTransactionSyncState.synced,
    pendingAction: null,
    lastSyncError: null,
  );
}

final class WalletBudget {
  const WalletBudget({
    required this.id,
    required this.categoryId,
    required this.month,
    required this.limit,
  });
  final String id, categoryId, month;
  final Money limit;
  Map<String, Object?> toJson() => {
    'id': id,
    'category_id': categoryId,
    'month': month,
    'amount': limit.toApiString(),
    'currency': limit.currency,
  };
  factory WalletBudget.fromJson(Map<String, Object?> j) {
    final month = walletText(j['month']);
    final limit = Money.parse(
      walletText(j['amount']),
      walletCurrency(j['currency']),
    );
    if (!RegExp(r'^\d{4}-(0[1-9]|1[0-2])$').hasMatch(month) ||
        limit.scaledAmount <= BigInt.zero) {
      throw const FormatException('Invalid budget.');
    }
    return WalletBudget(
      id: walletText(j['id']),
      categoryId: walletText(j['category_id']),
      month: month,
      limit: limit,
    );
  }
}

final class WalletGoal {
  const WalletGoal({
    required this.id,
    required this.name,
    required this.target,
    required this.saved,
    this.accountId,
  });
  final String id, name;
  final Money target, saved;
  final String? accountId;
  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'target': target.toApiString(),
    'saved': saved.toApiString(),
    'currency': target.currency,
    'account_id': accountId,
  };
  factory WalletGoal.fromJson(Map<String, Object?> j) {
    final currency = walletCurrency(j['currency']);
    final target = Money.parse(walletText(j['target']), currency),
        saved = Money.parse(walletText(j['saved']), currency);
    if (target.scaledAmount <= BigInt.zero || saved.scaledAmount.isNegative) {
      throw const FormatException('Invalid savings goal.');
    }
    return WalletGoal(
      id: walletText(j['id']),
      name: walletText(j['name']),
      target: target,
      saved: saved,
      accountId: j['account_id'] == null ? null : walletText(j['account_id']),
    );
  }
}

final class Wallet {
  const Wallet({
    required this.currency,
    required this.accounts,
    required this.entries,
    required this.categories,
    required this.budgets,
    required this.goals,
  });
  factory Wallet.empty() => const Wallet(
    currency: 'MAD',
    accounts: [],
    entries: [],
    categories: {
      'food': 'Food & groceries',
      'transport': 'Transport',
      'home': 'Home & bills',
      'shopping': 'Shopping',
      'health': 'Health',
      'leisure': 'Leisure',
      'salary': 'Salary',
      'other': 'Other',
    },
    budgets: [],
    goals: [],
  );
  final String currency;
  final List<WalletAccount> accounts;
  final List<WalletEntry> entries;
  final Map<String, String> categories;
  final List<WalletBudget> budgets;
  final List<WalletGoal> goals;
  Wallet copyWith({
    String? currency,
    List<WalletAccount>? accounts,
    List<WalletEntry>? entries,
    Map<String, String>? categories,
    List<WalletBudget>? budgets,
    List<WalletGoal>? goals,
  }) => Wallet(
    currency: currency ?? this.currency,
    accounts: accounts ?? this.accounts,
    entries: entries ?? this.entries,
    categories: categories ?? this.categories,
    budgets: budgets ?? this.budgets,
    goals: goals ?? this.goals,
  );
  Map<String, Object?> toJson() => {
    'format': 'planit-local-wallet',
    'version': 1,
    'currency': currency,
    'accounts': accounts.map((v) => v.toJson()).toList(),
    'entries': entries.map((v) => v.toJson()).toList(),
    'categories': categories,
    'budgets': budgets.map((v) => v.toJson()).toList(),
    'goals': goals.map((v) => v.toJson()).toList(),
  };
  factory Wallet.fromJson(Map<String, Object?> j) {
    if (j['format'] != 'planit-local-wallet' || j['version'] != 1) {
      throw const FormatException('Unsupported PlanIT local backup.');
    }
    List<T> records<T>(String key, T Function(Map<String, Object?>) read) {
      final values = j[key];
      if (values is! List || values.length > 50000) {
        throw const FormatException('Invalid backup size.');
      }
      return List.unmodifiable(values.map((v) => read(walletMap(v))));
    }

    final cats = walletMap(j['categories']);
    if (cats.length > 1000) throw const FormatException('Too many categories.');
    final wallet = Wallet(
      currency: walletCurrency(j['currency']),
      accounts: records('accounts', WalletAccount.fromJson),
      entries: records('entries', WalletEntry.fromJson),
      categories: Map.unmodifiable(
        cats.map((k, v) => MapEntry(walletText(k), walletText(v))),
      ),
      budgets: records('budgets', WalletBudget.fromJson),
      goals: records('goals', WalletGoal.fromJson),
    );
    wallet.validate();
    return wallet;
  }
  void validate() {
    final byId = {for (final a in accounts) a.id: a};
    if (byId.length != accounts.length ||
        entries.map((e) => e.id).toSet().length != entries.length ||
        budgets.map((b) => b.id).toSet().length != budgets.length ||
        goals.map((g) => g.id).toSet().length != goals.length) {
      throw const FormatException('Duplicate IDs in backup.');
    }
    final transfers = <String, List<WalletEntry>>{};
    for (final e in entries) {
      if (byId[e.accountId]?.opening.currency != e.amount.currency ||
          (e.categoryId != null && !categories.containsKey(e.categoryId))) {
        throw const FormatException(
          'Missing account/category or mismatched currency.',
        );
      }
      if (e.type.isTransfer) {
        if (e.transferId == null) {
          throw const FormatException('Incomplete transfer.');
        }
        transfers.putIfAbsent(e.transferId!, () => []).add(e);
      } else if (e.transferId != null) {
        throw const FormatException('Invalid transfer link.');
      }
    }
    for (final pair in transfers.values) {
      if (pair.length != 2 ||
          pair[0].accountId == pair[1].accountId ||
          pair[0].amount != pair[1].amount ||
          pair[0].deleted != pair[1].deleted ||
          pair[0].date != pair[1].date ||
          pair.map((e) => e.type).toSet().length != 2) {
        throw const FormatException('Incomplete transfer pair.');
      }
    }
    final keys = <String>{};
    for (final b in budgets) {
      if (!categories.containsKey(b.categoryId) ||
          !keys.add('${b.categoryId}/${b.month}/${b.limit.currency}')) {
        throw const FormatException('Invalid or duplicate category budget.');
      }
    }
    for (final g in goals) {
      if (g.accountId != null &&
          byId[g.accountId]?.opening.currency != g.target.currency) {
        throw const FormatException('Invalid linked savings account.');
      }
    }
    // Reject values whose otherwise valid individual amounts would overflow
    // balances or reporting totals. A failed save/restore leaves old data intact.
    try {
      final movements = <String, Money>{};
      final totals = <String, Money>{};
      for (final e in entries.where((e) => !e.deleted)) {
        final key = '${e.amount.currency}/${e.inflow}';
        movements.update(key, (v) => v + e.amount, ifAbsent: () => e.amount);
      }
      for (final a in accounts) {
        final value = balance(a);
        totals.update(value.currency, (v) => v + value, ifAbsent: () => value);
      }
    } on RangeError {
      throw const FormatException(
        'Combined amounts exceed the supported money range.',
      );
    }
  }

  Money balance(WalletAccount account, {DateTime? now}) => entries
      .where(
        (e) =>
            e.accountId == account.id &&
            !e.deleted &&
            !e.date.isAfter(now ?? DateTime.now()),
      )
      .fold(
        account.opening,
        (sum, e) => sum + (e.inflow ? e.amount : -e.amount),
      );
  Money goalSaved(WalletGoal goal) {
    if (goal.accountId == null) return goal.saved;
    final value = balance(accounts.firstWhere((a) => a.id == goal.accountId));
    return value.scaledAmount.isNegative ? Money.zero(value.currency) : value;
  }
}
