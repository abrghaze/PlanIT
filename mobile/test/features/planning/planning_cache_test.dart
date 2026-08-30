import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planit_mobile/core/database/app_database.dart';
import 'package:planit_mobile/features/planning/domain/planning.dart';

void main() {
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
}
