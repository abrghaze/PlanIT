import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planit_mobile/core/database/app_database.dart';
import 'package:planit_mobile/features/analytics/domain/analytics_dashboard.dart';

void main() {
  test('dashboard contract preserves precise money and traceability', () {
    final dashboard = AnalyticsDashboard.fromJson(_dashboardJson());

    expect(dashboard.kpis.personalSpending.toApiString(), '75.2500');
    expect(dashboard.categories.single.sourceTransactionIds, <String>['tx-1']);
    expect(dashboard.spendingInsights.single.multiple, '4.50');
    expect(dashboard.products.single.normalizedUnit, 'ML');
    expect(
      dashboard.products.single.normalizedAveragePrice!.toApiString(),
      '0.0125',
    );
  });

  test('custom filter has a deterministic cache key and API dates', () {
    final filter = AnalyticsFilter(
      preset: AnalyticsPreset.custom,
      from: DateTime(2026, 8, 1),
      to: DateTime(2026, 8, 30),
    );

    expect(filter.cacheKey, 'CUSTOM:2026-08-01:2026-08-30');
    expect(filter.queryParameters['from'], '2026-08-01');
    expect(filter.queryParameters['to'], '2026-08-30');
  });

  test('analytics cache is isolated by owner and cleared on logout', () async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    await database.saveAnalyticsDashboard(
      ownerId: 'owner-a',
      cacheKey: 'THIS_MONTH',
      payloadJson: '{"owner":"a"}',
    );
    await database.saveAnalyticsDashboard(
      ownerId: 'owner-b',
      cacheKey: 'THIS_MONTH',
      payloadJson: '{"owner":"b"}',
    );

    expect(
      (await database.readAnalyticsDashboard(
        'owner-a',
        'THIS_MONTH',
      ))?.payloadJson,
      '{"owner":"a"}',
    );
    await database.clearOwnerData('owner-a');
    expect(
      await database.readAnalyticsDashboard('owner-a', 'THIS_MONTH'),
      isNull,
    );
    expect(
      await database.readAnalyticsDashboard('owner-b', 'THIS_MONTH'),
      isNotNull,
    );
  });
}

Map<String, Object?> _dashboardJson() => <String, Object?>{
  'generated_at': '2026-08-30T12:00:00Z',
  'base_currency': 'MAD',
  'period': <String, Object?>{
    'local_from': '2026-08-01',
    'local_to': '2026-08-30',
  },
  'kpis': <String, Object?>{
    'money_in_accounts': _money('1000.0000'),
    'net_receivables': _money('100.0000'),
    'personal_net_position': _money('1100.0000'),
    'gross_spending': _money('100.0000'),
    'personal_spending': _money('75.2500'),
    'income': _money('300.0000'),
    'net_income': _money('224.7500'),
    'cash_inflow': _money('300.0000'),
    'cash_outflow': _money('100.0000'),
    'reconciliation_adjustments': _money('0.0000'),
    'complete': true,
  },
  'warnings': <Object?>[],
  'spending_insights': <Object?>[
    <String, Object?>{
      'transaction_id': 'tx-1',
      'occurred_at': '2026-08-30T10:00:00Z',
      'amount': _money('225.0000'),
      'baseline': _money('50.0000'),
      'multiple': '4.50',
      'explanation': 'This expense is more than twice the median.',
    },
  ],
  'trend': <Object?>[
    <String, Object?>{
      'period_start': '2026-08-30',
      'spending': _money('75.2500'),
      'income': _money('300.0000'),
    },
  ],
  'categories': <Object?>[
    <String, Object?>{
      'entity_id': 'category-1',
      'name': 'Groceries',
      'amount': _money('75.2500'),
      'source_transaction_ids': <String>['tx-1'],
      'source_count': 1,
    },
  ],
  'merchants': <Object?>[],
  'branches': <Object?>[],
  'tags': <Object?>[],
  'products': <Object?>[
    <String, Object?>{
      'product_id': 'product-1',
      'name': 'Milk',
      'variant_label': '1 L',
      'total_quantity': '2.000000',
      'spending': _money('25.0000'),
      'average_unit_price': _money('12.5000'),
      'minimum_unit_price': _money('12.5000'),
      'maximum_unit_price': _money('12.5000'),
      'last_unit_price': _money('12.5000'),
      'normalized_unit': 'ML',
      'normalized_average_price': _money('0.0125'),
      'source_transaction_ids': <String>['tx-1'],
      'source_count': 1,
    },
  ],
  'accounts': <Object?>[],
};

Map<String, Object?> _money(String amount) => <String, Object?>{
  'amount': amount,
  'currency': 'MAD',
};
