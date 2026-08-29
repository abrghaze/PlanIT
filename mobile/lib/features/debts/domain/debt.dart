import 'package:planit_mobile/core/money/money.dart';
import 'package:planit_mobile/features/transactions/domain/transaction.dart';

enum DebtDirection { receivable, payable }

extension DebtDirectionContract on DebtDirection {
  String get apiValue => name.toUpperCase();
  String get label => this == DebtDirection.receivable ? 'Owed to me' : 'I owe';
}

enum DebtOrigin { existing, lendNow, borrowNow, sharedExpense }

extension DebtOriginContract on DebtOrigin {
  String get apiValue => switch (this) {
    DebtOrigin.existing => 'EXISTING',
    DebtOrigin.lendNow => 'LEND_NOW',
    DebtOrigin.borrowNow => 'BORROW_NOW',
    DebtOrigin.sharedExpense => 'SHARED_EXPENSE',
  };

  String get label => switch (this) {
    DebtOrigin.existing => 'Existing debt',
    DebtOrigin.lendNow => 'Lend now',
    DebtOrigin.borrowNow => 'Borrow now',
    DebtOrigin.sharedExpense => 'Shared expense',
  };
}

final class Person {
  const Person({
    required this.id,
    required this.name,
    required this.contact,
    required this.version,
  });
  final String id;
  final String name;
  final String? contact;
  final int version;

  factory Person.fromJson(Map<String, Object?> json) => Person(
    id: _string(json, 'id'),
    name: _string(json, 'name'),
    contact: json['contact'] as String?,
    version: _integer(json, 'version'),
  );
}

final class DebtPayment {
  const DebtPayment({
    required this.id,
    required this.amount,
    required this.paidAt,
    required this.transaction,
  });
  final String id;
  final Money amount;
  final DateTime paidAt;
  final LedgerTransaction transaction;
}

final class Debt {
  const Debt({
    required this.id,
    required this.personId,
    required this.direction,
    required this.origin,
    required this.originalAmount,
    required this.paidAmount,
    required this.remainingAmount,
    required this.status,
    required this.overdue,
    required this.dueDate,
    required this.note,
    required this.version,
    required this.payments,
  });
  final String id;
  final String personId;
  final DebtDirection direction;
  final DebtOrigin origin;
  final Money originalAmount;
  final Money paidAmount;
  final Money remainingAmount;
  final String status;
  final bool overdue;
  final DateTime? dueDate;
  final String? note;
  final int version;
  final List<DebtPayment> payments;

  bool get acceptsPayment => status == 'OPEN' || status == 'PARTIALLY_PAID';

  factory Debt.fromJson(Map<String, Object?> json, {required String ownerId}) {
    final rawPayments = json['payments'];
    if (rawPayments is! List) {
      throw const FormatException('Debt payments are missing.');
    }
    return Debt(
      id: _string(json, 'id'),
      personId: _string(json, 'person_id'),
      direction: switch (_string(json, 'direction')) {
        'RECEIVABLE' => DebtDirection.receivable,
        'PAYABLE' => DebtDirection.payable,
        _ => throw const FormatException('Unknown debt direction.'),
      },
      origin: switch (_string(json, 'origin_type')) {
        'EXISTING' => DebtOrigin.existing,
        'LEND_NOW' => DebtOrigin.lendNow,
        'BORROW_NOW' => DebtOrigin.borrowNow,
        'SHARED_EXPENSE' => DebtOrigin.sharedExpense,
        _ => throw const FormatException('Unknown debt origin.'),
      },
      originalAmount: _money(json, 'original_amount'),
      paidAmount: _money(json, 'paid_amount'),
      remainingAmount: _money(json, 'remaining_amount'),
      status: _string(json, 'status'),
      overdue: json['overdue'] == true,
      dueDate: json['due_date'] is String
          ? DateTime.parse(json['due_date']! as String)
          : null,
      note: json['note'] as String?,
      version: _integer(json, 'version'),
      payments: rawPayments
          .map((raw) {
            final item = Map<String, Object?>.from(raw as Map);
            return DebtPayment(
              id: _string(item, 'id'),
              amount: _money(item, 'amount'),
              paidAt: DateTime.parse(_string(item, 'paid_at')).toUtc(),
              transaction: LedgerTransaction.fromJson(
                Map<String, Object?>.from(item['transaction']! as Map),
                ownerId: ownerId,
              ),
            );
          })
          .toList(growable: false),
    );
  }
}

Money _money(Map<String, Object?> json, String key) {
  final value = Map<String, Object?>.from(json[key]! as Map);
  return Money.parse(_string(value, 'amount'), _string(value, 'currency'));
}

String _string(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is! String || value.isEmpty) {
    throw FormatException('$key is invalid.');
  }
  return value;
}

int _integer(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is! int) throw FormatException('$key is invalid.');
  return value;
}
