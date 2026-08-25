import 'package:planit_mobile/core/money/money.dart';

enum AccountType { bank, cash, savings, card, prepaid, investment, other }

extension AccountTypeContract on AccountType {
  String get apiValue => name.toUpperCase();

  String get label => switch (this) {
    AccountType.bank => 'Bank account',
    AccountType.cash => 'Cash',
    AccountType.savings => 'Savings',
    AccountType.card => 'Card',
    AccountType.prepaid => 'Prepaid',
    AccountType.investment => 'Investment',
    AccountType.other => 'Other',
  };

  static AccountType fromApi(String value) {
    return AccountType.values.firstWhere(
      (type) => type.apiValue == value,
      orElse: () => AccountType.other,
    );
  }
}

enum AccountStatus { active, archived, closed }

extension AccountStatusContract on AccountStatus {
  String get apiValue => name.toUpperCase();

  String get label => switch (this) {
    AccountStatus.active => 'Active',
    AccountStatus.archived => 'Archived',
    AccountStatus.closed => 'Closed',
  };

  static AccountStatus fromApi(String value) {
    return AccountStatus.values.firstWhere(
      (status) => status.apiValue == value,
      orElse: () => AccountStatus.closed,
    );
  }
}

final class Account {
  const Account({
    required this.id,
    required this.ownerId,
    required this.name,
    required this.type,
    required this.currency,
    required this.openingBalance,
    required this.calculatedBalance,
    required this.balanceAsOf,
    required this.openedAt,
    required this.includeInTotal,
    required this.allowNegative,
    required this.status,
    required this.sortOrder,
    required this.archivedAt,
    required this.closedAt,
    required this.version,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String ownerId;
  final String name;
  final AccountType type;
  final String currency;
  final Money openingBalance;
  final Money calculatedBalance;
  final DateTime balanceAsOf;
  final DateTime openedAt;
  final bool includeInTotal;
  final bool allowNegative;
  final AccountStatus status;
  final int sortOrder;
  final DateTime? archivedAt;
  final DateTime? closedAt;
  final int version;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory Account.fromJson(
    Map<String, Object?> json, {
    required String ownerId,
  }) {
    final currency = json['currency']! as String;
    final opening = Map<String, Object?>.from(json['opening_balance']! as Map);
    final calculated = Map<String, Object?>.from(
      json['calculated_balance']! as Map,
    );
    return Account(
      id: json['id']! as String,
      ownerId: ownerId,
      name: json['name']! as String,
      type: AccountTypeContract.fromApi(json['type']! as String),
      currency: currency,
      openingBalance: Money.parse(opening['amount']! as String, currency),
      calculatedBalance: Money.parse(calculated['amount']! as String, currency),
      balanceAsOf: DateTime.parse(json['balance_as_of']! as String).toUtc(),
      openedAt: DateTime.parse(json['opened_at']! as String).toUtc(),
      includeInTotal: json['include_in_total']! as bool,
      allowNegative: json['allow_negative']! as bool,
      status: AccountStatusContract.fromApi(json['status']! as String),
      sortOrder: json['sort_order']! as int,
      archivedAt: _optionalDate(json['archived_at']),
      closedAt: _optionalDate(json['closed_at']),
      version: json['version']! as int,
      createdAt: DateTime.parse(json['created_at']! as String).toUtc(),
      updatedAt: DateTime.parse(json['updated_at']! as String).toUtc(),
    );
  }

  static DateTime? _optionalDate(Object? value) {
    return value == null ? null : DateTime.parse(value as String).toUtc();
  }
}

final class AccountDraft {
  const AccountDraft({
    required this.id,
    required this.name,
    required this.type,
    required this.openingBalance,
    required this.openedAt,
    required this.includeInTotal,
    required this.allowNegative,
    required this.sortOrder,
  });

  final String id;
  final String name;
  final AccountType type;
  final Money openingBalance;
  final DateTime openedAt;
  final bool includeInTotal;
  final bool allowNegative;
  final int sortOrder;

  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'name': name,
    'type': type.apiValue,
    'opening_balance': <String, Object?>{
      'amount': openingBalance.toApiString(),
      'currency': openingBalance.currency,
    },
    'opened_at': openedAt.toUtc().toIso8601String(),
    'include_in_total': includeInTotal,
    'allow_negative': allowNegative,
    'sort_order': sortOrder,
  };
}

final class AccountPatch {
  const AccountPatch({
    required this.version,
    this.name,
    this.type,
    this.openingBalance,
    this.openedAt,
    this.includeInTotal,
    this.allowNegative,
    this.status,
    this.sortOrder,
  });

  final int version;
  final String? name;
  final AccountType? type;
  final Money? openingBalance;
  final DateTime? openedAt;
  final bool? includeInTotal;
  final bool? allowNegative;
  final AccountStatus? status;
  final int? sortOrder;

  Map<String, Object?> toJson() => <String, Object?>{
    'version': version,
    if (name != null) 'name': name,
    if (type != null) 'type': type!.apiValue,
    if (openingBalance != null)
      'opening_balance': <String, Object?>{
        'amount': openingBalance!.toApiString(),
        'currency': openingBalance!.currency,
      },
    if (openedAt != null) 'opened_at': openedAt!.toUtc().toIso8601String(),
    if (includeInTotal != null) 'include_in_total': includeInTotal,
    if (allowNegative != null) 'allow_negative': allowNegative,
    if (status != null) 'status': status!.apiValue,
    if (sortOrder != null) 'sort_order': sortOrder,
  };
}
