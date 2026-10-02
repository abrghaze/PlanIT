import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planit_mobile/core/database/app_database.dart';
import 'package:planit_mobile/core/money/money.dart';
import 'package:planit_mobile/features/planning/domain/planning.dart';

void main() {
  test(
    'linked goals follow local balances without changing manual goals or currencies',
    () {
      final goal = SavingsGoal(
        id: 'goal',
        name: 'Emergency fund',
        target: Money.parse('1000', 'MAD'),
        progress: Money.parse('100', 'MAD'),
        remaining: Money.parse('900', 'MAD'),
        percent: 10,
        targetDate: null,
        linkedAccountId: 'savings',
        status: 'ACTIVE',
        version: 1,
      );
      final local = goal.withLocalBalance(Money.parse('625.1234', 'MAD'));
      expect(local.progress, Money.parse('625.1234', 'MAD'));
      expect(local.remaining, Money.parse('374.8766', 'MAD'));
      expect(
        goal.withLocalBalance(Money.parse('-1', 'MAD')).progress,
        Money.zero('MAD'),
      );
      expect(
        goal.withLocalBalance(Money.parse('1200', 'MAD')).remaining,
        Money.zero('MAD'),
      );
      expect(goal.withLocalBalance(Money.parse('50', 'EUR')), same(goal));
      final manual = SavingsGoal(
        id: 'manual',
        name: 'Trip',
        target: goal.target,
        progress: goal.progress,
        remaining: goal.remaining,
        percent: 10,
        targetDate: null,
        linkedAccountId: null,
        status: 'ACTIVE',
        version: 1,
      );
      expect(manual.withLocalBalance(Money.parse('500', 'MAD')), same(manual));
    },
  );
  test(
    'planning cache preserves exact projections and owner isolation',
    () async {
      final database = AppDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      final payload = <String, Object?>{
        'rules': <Object?>[
          <String, Object?>{
            'id': 'rule-1',
            'name': 'Rent',
            'kind': 'EXPENSE',
            'account_id': 'account-1',
            'amount': <String, Object?>{
              'amount': '3000.0000',
              'currency': 'MAD',
            },
            'frequency': 'MONTHLY',
            'next_due_at': '2026-09-01T08:00:00Z',
            'mode': 'REMINDER',
            'status': 'ACTIVE',
            'monthly_equivalent': <String, Object?>{
              'amount': '3000.0000',
              'currency': 'MAD',
            },
            'annual_equivalent': <String, Object?>{
              'amount': '36000.0000',
              'currency': 'MAD',
            },
            'version': 1,
          },
        ],
        'totals': <Object?>[],
        'goals': <Object?>[],
      };
      await database.savePlanningSnapshot(
        ownerId: 'owner-a',
        payloadJson: jsonEncode(payload),
      );
      final cached = await database.readPlanningSnapshot('owner-a');
      expect(cached, isNotNull);
      final dashboard = PlanningDashboard.fromJson(
        Map<String, Object?>.from(jsonDecode(cached!.payloadJson) as Map),
        cachedAt: cached.updatedAt,
      );
      expect(dashboard.offline, isTrue);
      expect(
        dashboard.rules.single.annualEquivalent.toApiString(),
        '36000.0000',
      );
      expect(await database.readPlanningSnapshot('owner-b'), isNull);
      await database.clearOwnerData('owner-a');
      expect(await database.readPlanningSnapshot('owner-a'), isNull);
    },
  );

  test('goal pace reports exact remaining time and monthly requirement', () {
    final goal = SavingsGoal(
      id: 'goal-1',
      name: 'Emergency fund',
      target: Money.parse('10000.0000', 'MAD'),
      progress: Money.parse('4000.0000', 'MAD'),
      remaining: Money.parse('6000.0000', 'MAD'),
      percent: 40,
      targetDate: DateTime(2026, 12, 30),
      linkedAccountId: null,
      status: 'ACTIVE',
      version: 1,
    );

    final pace = GoalPace.fromGoal(goal, asOf: DateTime(2026, 8, 31));

    expect(pace.overdue, isFalse);
    expect(pace.daysRemaining, 121);
    expect(pace.monthlyRequired?.toApiString(), '1200.0000');
  });
}
