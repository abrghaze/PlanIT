import 'package:planit_mobile/core/money/money.dart';

final class RecurringRule {
  const RecurringRule({
    required this.id,
    required this.name,
    required this.kind,
    required this.accountId,
    required this.amount,
    required this.frequency,
    required this.nextDueAt,
    required this.mode,
    required this.status,
    required this.monthlyEquivalent,
    required this.annualEquivalent,
    required this.version,
  });
  final String id;
  final String name;
  final String kind;
  final String accountId;
  final Money amount;
  final String frequency;
  final DateTime nextDueAt;
  final String mode;
  final String status;
  final Money monthlyEquivalent;
  final Money annualEquivalent;
  final int version;

  bool get isDue =>
      status == 'ACTIVE' && !nextDueAt.isAfter(DateTime.now().toUtc());

  factory RecurringRule.fromJson(Map<String, Object?> json) => RecurringRule(
    id: json['id']! as String,
    name: json['name']! as String,
    kind: json['kind']! as String,
    accountId: json['account_id']! as String,
    amount: _money(json['amount']),
    frequency: json['frequency']! as String,
    nextDueAt: DateTime.parse(json['next_due_at']! as String).toUtc(),
    mode: json['mode']! as String,
    status: json['status']! as String,
    monthlyEquivalent: _money(json['monthly_equivalent']),
    annualEquivalent: _money(json['annual_equivalent']),
    version: json['version']! as int,
  );
}

final class RecurringTotal {
  const RecurringTotal({
    required this.currency,
    required this.expenseMonthly,
    required this.expenseAnnual,
    required this.incomeMonthly,
    required this.incomeAnnual,
  });
  final String currency;
  final Money expenseMonthly;
  final Money expenseAnnual;
  final Money incomeMonthly;
  final Money incomeAnnual;
  factory RecurringTotal.fromJson(Map<String, Object?> json) => RecurringTotal(
    currency: json['currency']! as String,
    expenseMonthly: _money(json['expense_monthly']),
    expenseAnnual: _money(json['expense_annual']),
    incomeMonthly: _money(json['income_monthly']),
    incomeAnnual: _money(json['income_annual']),
  );
}

final class SavingsGoal {
  const SavingsGoal({
    required this.id,
    required this.name,
    required this.target,
    required this.progress,
    required this.remaining,
    required this.percent,
    required this.targetDate,
    required this.linkedAccountId,
    required this.status,
    required this.version,
  });
  final String id;
  final String name;
  final Money target;
  final Money progress;
  final Money remaining;
  final double percent;
  final DateTime? targetDate;
  final String? linkedAccountId;
  final String status;
  final int version;
  bool get manual => linkedAccountId == null;

  factory SavingsGoal.fromJson(Map<String, Object?> json) => SavingsGoal(
    id: json['id']! as String,
    name: json['name']! as String,
    target: _money(json['target_amount']),
    progress: _money(json['progress']),
    remaining: _money(json['remaining']),
    percent: double.parse(json['progress_percent']! as String),
    targetDate: json['target_date'] == null
        ? null
        : DateTime.parse(json['target_date']! as String),
    linkedAccountId: json['linked_account_id'] as String?,
    status: json['status']! as String,
    version: json['version']! as int,
  );
}

final class GoalPace {
  const GoalPace({
    required this.daysRemaining,
    required this.monthlyRequired,
    required this.overdue,
  });

  final int? daysRemaining;
  final Money? monthlyRequired;
  final bool overdue;

  factory GoalPace.fromGoal(SavingsGoal goal, {DateTime? asOf}) {
    final target = goal.targetDate;
    if (target == null || goal.remaining.scaledAmount == BigInt.zero) {
      return const GoalPace(
        daysRemaining: null,
        monthlyRequired: null,
        overdue: false,
      );
    }
    final now = asOf ?? DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final deadline = DateTime(target.year, target.month, target.day);
    final days = deadline.difference(today).inDays;
    if (days < 0) {
      return GoalPace(
        daysRemaining: days,
        monthlyRequired: goal.remaining,
        overdue: true,
      );
    }
    final months = ((days == 0 ? 1 : days) / 30).ceil().clamp(1, 240);
    final scaled =
        (goal.remaining.scaledAmount + BigInt.from(months - 1)) ~/
        BigInt.from(months);
    return GoalPace(
      daysRemaining: days,
      monthlyRequired: Money.parse(
        _scaledMoneyString(scaled),
        goal.remaining.currency,
      ),
      overdue: false,
    );
  }
}

final class PlanningDashboard {
  const PlanningDashboard({
    required this.rules,
    required this.totals,
    required this.goals,
    required this.cachedAt,
  });
  final List<RecurringRule> rules;
  final List<RecurringTotal> totals;
  final List<SavingsGoal> goals;
  final DateTime? cachedAt;
  bool get offline => cachedAt != null;

  factory PlanningDashboard.fromJson(
    Map<String, Object?> json, {
    DateTime? cachedAt,
  }) => PlanningDashboard(
    rules: _items(json['rules'], RecurringRule.fromJson),
    totals: _items(json['totals'], RecurringTotal.fromJson),
    goals: _items(json['goals'], SavingsGoal.fromJson),
    cachedAt: cachedAt,
  );
}

Money _money(Object? raw) {
  final value = Map<String, Object?>.from(raw! as Map);
  return Money.parse(value['amount']! as String, value['currency']! as String);
}

List<T> _items<T>(Object? raw, T Function(Map<String, Object?>) parser) =>
    (raw! as List)
        .map((item) => parser(Map<String, Object?>.from(item as Map)))
        .toList(growable: false);

String _scaledMoneyString(BigInt value) {
  final absolute = value.abs();
  final factor = BigInt.from(10000);
  final whole = absolute ~/ factor;
  final fraction = (absolute % factor).toString().padLeft(4, '0');
  return '${value.isNegative ? '-' : ''}$whole.$fraction';
}
