import 'package:planit_mobile/core/money/money.dart';

enum AnalyticsPreset {
  today('TODAY', 'Today'),
  yesterday('YESTERDAY', 'Yesterday'),
  thisWeek('THIS_WEEK', 'This week'),
  last7Days('LAST_7_DAYS', 'Last 7 days'),
  thisMonth('THIS_MONTH', 'This month'),
  lastMonth('LAST_MONTH', 'Last month'),
  last30Days('LAST_30_DAYS', 'Last 30 days'),
  thisYear('THIS_YEAR', 'This year'),
  custom('CUSTOM', 'Custom');

  const AnalyticsPreset(this.apiValue, this.label);
  final String apiValue;
  final String label;
}

final class AnalyticsFilter {
  const AnalyticsFilter({
    this.preset = AnalyticsPreset.thisMonth,
    this.from,
    this.to,
  }) : assert(
         preset != AnalyticsPreset.custom || (from != null && to != null),
         'Custom analytics requires both dates.',
       );

  final AnalyticsPreset preset;
  final DateTime? from;
  final DateTime? to;

  String get cacheKey => <String>[
    preset.apiValue,
    if (from != null) _date(from!),
    if (to != null) _date(to!),
  ].join(':');

  Map<String, Object?> get queryParameters => <String, Object?>{
    'preset': preset.apiValue,
    if (preset == AnalyticsPreset.custom) 'from': _date(from!),
    if (preset == AnalyticsPreset.custom) 'to': _date(to!),
  };

  static String _date(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';
}

final class AnalyticsWarning {
  const AnalyticsWarning({
    required this.code,
    required this.message,
    required this.currencies,
  });
  final String code;
  final String message;
  final List<String> currencies;

  factory AnalyticsWarning.fromJson(Map<String, Object?> json) =>
      AnalyticsWarning(
        code: json['code']! as String,
        message: json['message']! as String,
        currencies: _strings(json['currencies']),
      );
}

final class AnalyticsKpis {
  const AnalyticsKpis({
    required this.moneyInAccounts,
    required this.netReceivables,
    required this.personalNetPosition,
    required this.grossSpending,
    required this.personalSpending,
    required this.income,
    required this.netIncome,
    required this.cashInflow,
    required this.cashOutflow,
    required this.reconciliationAdjustments,
    required this.complete,
  });

  final Money moneyInAccounts;
  final Money netReceivables;
  final Money personalNetPosition;
  final Money grossSpending;
  final Money personalSpending;
  final Money income;
  final Money netIncome;
  final Money cashInflow;
  final Money cashOutflow;
  final Money reconciliationAdjustments;
  final bool complete;

  factory AnalyticsKpis.fromJson(Map<String, Object?> json) => AnalyticsKpis(
    moneyInAccounts: _money(json['money_in_accounts']),
    netReceivables: _money(json['net_receivables']),
    personalNetPosition: _money(json['personal_net_position']),
    grossSpending: _money(json['gross_spending']),
    personalSpending: _money(json['personal_spending']),
    income: _money(json['income']),
    netIncome: _money(json['net_income']),
    cashInflow: _money(json['cash_inflow']),
    cashOutflow: _money(json['cash_outflow']),
    reconciliationAdjustments: _money(json['reconciliation_adjustments']),
    complete: json['complete']! as bool,
  );
}

final class TrendPoint {
  const TrendPoint({
    required this.periodStart,
    required this.spending,
    required this.income,
  });
  final DateTime periodStart;
  final Money spending;
  final Money income;

  factory TrendPoint.fromJson(Map<String, Object?> json) => TrendPoint(
    periodStart: DateTime.parse(json['period_start']! as String),
    spending: _money(json['spending']),
    income: _money(json['income']),
  );
}

final class BreakdownRow {
  const BreakdownRow({
    required this.entityId,
    required this.name,
    required this.amount,
    required this.sourceTransactionIds,
    required this.sourceCount,
  });
  final String? entityId;
  final String name;
  final Money amount;
  final List<String> sourceTransactionIds;
  final int sourceCount;

  factory BreakdownRow.fromJson(Map<String, Object?> json) => BreakdownRow(
    entityId: json['entity_id'] as String?,
    name: json['name']! as String,
    amount: _money(json['amount']),
    sourceTransactionIds: _strings(json['source_transaction_ids']),
    sourceCount: json['source_count']! as int,
  );
}

final class AccountFlowRow {
  const AccountFlowRow({
    required this.accountId,
    required this.name,
    required this.inflow,
    required this.outflow,
    required this.sourceTransactionIds,
  });
  final String accountId;
  final String name;
  final Money inflow;
  final Money outflow;
  final List<String> sourceTransactionIds;

  factory AccountFlowRow.fromJson(Map<String, Object?> json) => AccountFlowRow(
    accountId: json['account_id']! as String,
    name: json['name']! as String,
    inflow: _money(json['inflow']),
    outflow: _money(json['outflow']),
    sourceTransactionIds: _strings(json['source_transaction_ids']),
  );
}

final class ProductAnalyticsRow {
  const ProductAnalyticsRow({
    required this.productId,
    required this.name,
    required this.variantLabel,
    required this.totalQuantity,
    required this.spending,
    required this.averageUnitPrice,
    required this.minimumUnitPrice,
    required this.maximumUnitPrice,
    required this.lastUnitPrice,
    required this.normalizedUnit,
    required this.normalizedAveragePrice,
    required this.sourceTransactionIds,
  });
  final String productId;
  final String name;
  final String? variantLabel;
  final String totalQuantity;
  final Money spending;
  final Money? averageUnitPrice;
  final Money? minimumUnitPrice;
  final Money? maximumUnitPrice;
  final Money? lastUnitPrice;
  final String? normalizedUnit;
  final Money? normalizedAveragePrice;
  final List<String> sourceTransactionIds;

  factory ProductAnalyticsRow.fromJson(Map<String, Object?> json) =>
      ProductAnalyticsRow(
        productId: json['product_id']! as String,
        name: json['name']! as String,
        variantLabel: json['variant_label'] as String?,
        totalQuantity: json['total_quantity'].toString(),
        spending: _money(json['spending']),
        averageUnitPrice: _optionalMoney(json['average_unit_price']),
        minimumUnitPrice: _optionalMoney(json['minimum_unit_price']),
        maximumUnitPrice: _optionalMoney(json['maximum_unit_price']),
        lastUnitPrice: _optionalMoney(json['last_unit_price']),
        normalizedUnit: json['normalized_unit'] as String?,
        normalizedAveragePrice: _optionalMoney(
          json['normalized_average_price'],
        ),
        sourceTransactionIds: _strings(json['source_transaction_ids']),
      );
}

final class AnalyticsDashboard {
  const AnalyticsDashboard({
    required this.generatedAt,
    required this.baseCurrency,
    required this.periodLabel,
    required this.kpis,
    required this.warnings,
    required this.trend,
    required this.categories,
    required this.merchants,
    required this.branches,
    required this.tags,
    required this.products,
    required this.accounts,
    required this.cachedAt,
    required this.isOffline,
  });

  final DateTime generatedAt;
  final String baseCurrency;
  final String periodLabel;
  final AnalyticsKpis kpis;
  final List<AnalyticsWarning> warnings;
  final List<TrendPoint> trend;
  final List<BreakdownRow> categories;
  final List<BreakdownRow> merchants;
  final List<BreakdownRow> branches;
  final List<BreakdownRow> tags;
  final List<ProductAnalyticsRow> products;
  final List<AccountFlowRow> accounts;
  final DateTime? cachedAt;
  final bool isOffline;

  AnalyticsDashboard asCached(DateTime at) => AnalyticsDashboard(
    generatedAt: generatedAt,
    baseCurrency: baseCurrency,
    periodLabel: periodLabel,
    kpis: kpis,
    warnings: warnings,
    trend: trend,
    categories: categories,
    merchants: merchants,
    branches: branches,
    tags: tags,
    products: products,
    accounts: accounts,
    cachedAt: at,
    isOffline: true,
  );

  factory AnalyticsDashboard.fromJson(Map<String, Object?> json) {
    final period = _map(json['period']);
    return AnalyticsDashboard(
      generatedAt: DateTime.parse(json['generated_at']! as String).toUtc(),
      baseCurrency: json['base_currency']! as String,
      periodLabel: '${period['local_from']} – ${period['local_to']}',
      kpis: AnalyticsKpis.fromJson(_map(json['kpis'])),
      warnings: _list(json['warnings'], AnalyticsWarning.fromJson),
      trend: _list(json['trend'], TrendPoint.fromJson),
      categories: _list(json['categories'], BreakdownRow.fromJson),
      merchants: _list(json['merchants'], BreakdownRow.fromJson),
      branches: _list(json['branches'], BreakdownRow.fromJson),
      tags: _list(json['tags'], BreakdownRow.fromJson),
      products: _list(json['products'], ProductAnalyticsRow.fromJson),
      accounts: _list(json['accounts'], AccountFlowRow.fromJson),
      cachedAt: null,
      isOffline: false,
    );
  }
}

Money _money(Object? value) {
  final json = _map(value);
  return Money.parse(json['amount']! as String, json['currency']! as String);
}

Money? _optionalMoney(Object? value) => value == null ? null : _money(value);
Map<String, Object?> _map(Object? value) =>
    Map<String, Object?>.from(value! as Map);
List<String> _strings(Object? value) =>
    (value! as List).map((item) => item.toString()).toList(growable: false);
List<T> _list<T>(Object? value, T Function(Map<String, Object?>) parser) =>
    (value! as List).map((item) => parser(_map(item))).toList(growable: false);
