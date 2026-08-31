import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:planit_mobile/core/auth/application/auth_controller.dart';
import 'package:planit_mobile/core/design_system/tokens.dart';
import 'package:planit_mobile/core/money/money.dart';
import 'package:planit_mobile/core/money/money_format.dart';
import 'package:planit_mobile/features/analytics/application/providers.dart';
import 'package:planit_mobile/features/analytics/domain/analytics_dashboard.dart';
import 'package:uuid/uuid.dart';

class AnalyticsScreen extends ConsumerStatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  ConsumerState<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends ConsumerState<AnalyticsScreen> {
  AnalyticsFilter _filter = const AnalyticsFilter();
  var _breakdown = 0;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(analyticsDashboardProvider(_filter));
    return RefreshIndicator(
      onRefresh: () => ref.refresh(analyticsDashboardProvider(_filter).future),
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: <Widget>[
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              PlanItSpacing.lg,
              PlanItSpacing.lg,
              PlanItSpacing.lg,
              112,
            ),
            sliver: SliverList.list(
              children: <Widget>[
                Text(
                  'Analytics',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: PlanItSpacing.xxs),
                Text(
                  'Traceable insights from posted financial facts.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: PlanItSpacing.md),
                _PeriodPicker(filter: _filter, onChanged: _setFilter),
                const SizedBox(height: PlanItSpacing.lg),
                state.when(
                  loading: () => const SizedBox(
                    height: 360,
                    child: Center(child: CircularProgressIndicator()),
                  ),
                  error: (error, stackTrace) => _ErrorCard(
                    onRetry: () =>
                        ref.invalidate(analyticsDashboardProvider(_filter)),
                  ),
                  data: (dashboard) => _DashboardBody(
                    dashboard: dashboard,
                    breakdown: _breakdown,
                    onBreakdownChanged: (value) =>
                        setState(() => _breakdown = value),
                    onSources: _showSources,
                    onAddRate: (currency) =>
                        _addRate(dashboard.baseCurrency, currency),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _setFilter(AnalyticsPreset preset) async {
    if (preset != AnalyticsPreset.custom) {
      setState(() => _filter = AnalyticsFilter(preset: preset));
      return;
    }
    final now = DateTime.now();
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 5),
      lastDate: now,
      initialDateRange: DateTimeRange(
        start: DateTime(now.year, now.month),
        end: now,
      ),
    );
    if (range != null) {
      setState(
        () => _filter = AnalyticsFilter(
          preset: preset,
          from: range.start,
          to: range.end,
        ),
      );
    }
  }

  void _showSources(String title, List<String> ids) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            PlanItSpacing.lg,
            0,
            PlanItSpacing.lg,
            PlanItSpacing.lg,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                title,
                style: Theme.of(
                  sheetContext,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: PlanItSpacing.xs),
              Text(
                '${ids.length} linked source '
                '${ids.length == 1 ? 'transaction' : 'transactions'}',
              ),
              const SizedBox(height: PlanItSpacing.md),
              if (ids.isEmpty)
                const Text(
                  'No source transaction is available for this aggregate.',
                ),
              ...ids
                  .take(12)
                  .map(
                    (id) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.receipt_long_outlined),
                      title: Text('Transaction ${id.substring(0, 8)}'),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () {
                        Navigator.pop(sheetContext);
                        context.push('/transactions/$id');
                      },
                    ),
                  ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _addRate(String baseCurrency, String sourceCurrency) async {
    final controller = TextEditingController();
    final rate = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('$sourceCurrency → $baseCurrency rate'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: '1 $sourceCurrency equals',
            suffixText: baseCurrency,
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(dialogContext, controller.text.trim()),
            child: const Text('Save rate'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (rate == null || rate.isEmpty) return;
    final session = ref.read(authControllerProvider).session;
    if (session == null) return;
    try {
      await ref
          .read(analyticsRepositoryProvider)
          .api
          .addExchangeRate(
            accessToken: session.accessToken,
            id: const Uuid().v4(),
            baseCurrency: sourceCurrency,
            quoteCurrency: baseCurrency,
            rate: rate,
            effectiveAt: DateTime.now(),
          );
      ref.invalidate(analyticsDashboardProvider(_filter));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('The exchange rate could not be saved.'),
          ),
        );
      }
    }
  }
}

class _PeriodPicker extends StatelessWidget {
  const _PeriodPicker({required this.filter, required this.onChanged});
  final AnalyticsFilter filter;
  final ValueChanged<AnalyticsPreset> onChanged;

  @override
  Widget build(BuildContext context) =>
      DropdownButtonFormField<AnalyticsPreset>(
        initialValue: filter.preset,
        decoration: const InputDecoration(
          prefixIcon: Icon(Icons.date_range_outlined),
          labelText: 'Reporting period',
        ),
        items: AnalyticsPreset.values
            .map(
              (preset) => DropdownMenuItem<AnalyticsPreset>(
                value: preset,
                child: Text(preset.label),
              ),
            )
            .toList(growable: false),
        onChanged: (value) {
          if (value != null) onChanged(value);
        },
      );
}

class _DashboardBody extends StatelessWidget {
  const _DashboardBody({
    required this.dashboard,
    required this.breakdown,
    required this.onBreakdownChanged,
    required this.onSources,
    required this.onAddRate,
  });
  final AnalyticsDashboard dashboard;
  final int breakdown;
  final ValueChanged<int> onBreakdownChanged;
  final void Function(String, List<String>) onSources;
  final ValueChanged<String> onAddRate;

  @override
  Widget build(BuildContext context) {
    final rows = <List<BreakdownRow>>[
      dashboard.categories,
      dashboard.merchants,
      dashboard.branches,
      dashboard.tags,
    ][breakdown];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                dashboard.periodLabel,
                style: Theme.of(context).textTheme.labelLarge,
              ),
            ),
            if (dashboard.isOffline)
              const Chip(
                avatar: Icon(Icons.cloud_off_outlined, size: 18),
                label: Text('Cached'),
              ),
          ],
        ),
        if (dashboard.warnings.isNotEmpty) ...<Widget>[
          const SizedBox(height: PlanItSpacing.sm),
          ...dashboard.warnings.map(
            (warning) => _WarningCard(warning: warning, onAddRate: onAddRate),
          ),
        ],
        const SizedBox(height: PlanItSpacing.md),
        _FinancialHealthCard(dashboard: dashboard),
        const SizedBox(height: PlanItSpacing.lg),
        const _SectionTitle(
          title: 'Your key numbers',
          subtitle: 'Balances, spending, income, and money owed to you',
        ),
        const SizedBox(height: PlanItSpacing.sm),
        _KpiGrid(dashboard: dashboard),
        if (dashboard.spendingInsights.isNotEmpty) ...<Widget>[
          const SizedBox(height: PlanItSpacing.lg),
          const _SectionTitle(
            title: 'Spending checks',
            subtitle: 'Explainable comparisons with your median expense',
          ),
          const SizedBox(height: PlanItSpacing.sm),
          ...dashboard.spendingInsights.map(
            (insight) => Card(
              child: ListTile(
                leading: const CircleAvatar(
                  child: Icon(Icons.manage_search_rounded),
                ),
                title: Text(
                  '${insight.amount.toDisplayString()} · ${insight.multiple}× usual',
                ),
                subtitle: Text(
                  '${insight.explanation} Median: ${insight.baseline.toDisplayString()}.',
                ),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => onSources('Spending check', <String>[
                  insight.transactionId,
                ]),
              ),
            ),
          ),
        ],
        const SizedBox(height: PlanItSpacing.lg),
        const _SectionTitle(
          title: 'Spending and income',
          subtitle: 'Personal spending after active shares and refunds',
        ),
        const SizedBox(height: PlanItSpacing.sm),
        _TrendChart(points: dashboard.trend),
        const SizedBox(height: PlanItSpacing.lg),
        const _SectionTitle(
          title: 'Where money went',
          subtitle: 'Tap a row to inspect source transactions',
        ),
        const SizedBox(height: PlanItSpacing.sm),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SegmentedButton<int>(
            segments: const <ButtonSegment<int>>[
              ButtonSegment<int>(value: 0, label: Text('Category')),
              ButtonSegment<int>(value: 1, label: Text('Shop')),
              ButtonSegment<int>(value: 2, label: Text('Branch')),
              ButtonSegment<int>(value: 3, label: Text('Tag')),
            ],
            selected: <int>{breakdown},
            onSelectionChanged: (values) => onBreakdownChanged(values.first),
            showSelectedIcon: false,
          ),
        ),
        const SizedBox(height: PlanItSpacing.sm),
        _BreakdownList(rows: rows, onSources: onSources),
        if (dashboard.products.isNotEmpty) ...<Widget>[
          const SizedBox(height: PlanItSpacing.lg),
          const _SectionTitle(
            title: 'Product intelligence',
            subtitle:
                'Variants stay separate; compatible pack sizes are normalized',
          ),
          const SizedBox(height: PlanItSpacing.sm),
          ...dashboard.products
              .take(8)
              .map(
                (row) => _ProductCard(
                  row: row,
                  onTap: () => onSources(row.name, row.sourceTransactionIds),
                ),
              ),
        ],
        if (dashboard.accounts.isNotEmpty) ...<Widget>[
          const SizedBox(height: PlanItSpacing.lg),
          const _SectionTitle(
            title: 'Account flow',
            subtitle: 'Cash movement by account for this period',
          ),
          const SizedBox(height: PlanItSpacing.sm),
          ...dashboard.accounts.map(
            (row) => Card(
              child: ListTile(
                leading: const CircleAvatar(
                  child: Icon(Icons.account_balance_wallet_outlined),
                ),
                title: Text(row.name),
                subtitle: Text(
                  'In ${row.inflow.toDisplayString()}  •  '
                  'Out ${row.outflow.toDisplayString()}',
                ),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => onSources(row.name, row.sourceTransactionIds),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _FinancialHealthCard extends StatelessWidget {
  const _FinancialHealthCard({required this.dashboard});

  final AnalyticsDashboard dashboard;

  @override
  Widget build(BuildContext context) {
    final summary = FinancialPeriodSummary.fromDashboard(dashboard);
    final result = summary.result;
    final hasMovement = result.scaledAmount != BigInt.zero;
    final resultLabel = !hasMovement
        ? 'Income and spending are even'
        : summary.isDeficit
        ? 'Spent ${(-result).toDisplayString()} more than income'
        : 'Kept ${result.toDisplayString()} after spending';
    final top = summary.largestSpendingArea;
    return Card(
      color: Theme.of(context).colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(PlanItSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                CircleAvatar(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Theme.of(context).colorScheme.onPrimary,
                  child: Icon(
                    summary.isDeficit
                        ? Icons.trending_down_rounded
                        : Icons.trending_up_rounded,
                  ),
                ),
                const SizedBox(width: PlanItSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'Period health check',
                        style: Theme.of(context).textTheme.labelLarge,
                      ),
                      const SizedBox(height: PlanItSpacing.xxs),
                      Text(
                        resultLabel,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (summary.spendingToIncomePercent case final spending?) ...[
              const SizedBox(height: PlanItSpacing.md),
              Wrap(
                spacing: PlanItSpacing.sm,
                runSpacing: PlanItSpacing.xs,
                children: <Widget>[
                  Chip(
                    avatar: const Icon(Icons.payments_outlined, size: 18),
                    label: Text('${_percentage(spending)}% of income spent'),
                  ),
                  if (summary.retainedIncomePercent case final retained?)
                    Chip(
                      avatar: const Icon(Icons.savings_outlined, size: 18),
                      label: Text(
                        retained >= 0
                            ? '${_percentage(retained)}% of income retained'
                            : '${_percentage(retained.abs())}% income shortfall',
                      ),
                    ),
                ],
              ),
            ] else ...<Widget>[
              const SizedBox(height: PlanItSpacing.sm),
              const Text(
                'Add posted income to compare spending against what you earned.',
              ),
            ],
            if (top != null) ...<Widget>[
              const Divider(height: PlanItSpacing.xl),
              Text(
                'Largest spending area',
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const SizedBox(height: PlanItSpacing.xxs),
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      top.name,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  Text(
                    '${top.amount.toDisplayString()}'
                    '${summary.largestSpendingSharePercent == null ? '' : ' · ${_percentage(summary.largestSpendingSharePercent!)}%'}',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  static String _percentage(double value) => value.toStringAsFixed(
    value.abs() >= 100 || value == value.roundToDouble() ? 0 : 1,
  );
}

class _KpiGrid extends StatelessWidget {
  const _KpiGrid({required this.dashboard});
  final AnalyticsDashboard dashboard;

  @override
  Widget build(BuildContext context) {
    final kpis = dashboard.kpis;
    final values = <(String, Money, IconData, Color)>[
      (
        'Personal net position',
        kpis.personalNetPosition,
        Icons.account_balance_outlined,
        PlanItColors.primary,
      ),
      (
        'Money in accounts',
        kpis.moneyInAccounts,
        Icons.wallet_outlined,
        PlanItColors.accent,
      ),
      (
        'Personal spending',
        kpis.personalSpending,
        Icons.south_east_rounded,
        PlanItColors.negative,
      ),
      ('Income', kpis.income, Icons.north_east_rounded, PlanItColors.positive),
      (
        'Net receivables',
        kpis.netReceivables,
        Icons.handshake_outlined,
        PlanItColors.warning,
      ),
      (
        'Net income',
        kpis.netIncome,
        Icons.insights_outlined,
        PlanItColors.primary,
      ),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = (constraints.maxWidth - PlanItSpacing.sm) / 2;
        return Wrap(
          spacing: PlanItSpacing.sm,
          runSpacing: PlanItSpacing.sm,
          children: values
              .map(
                (item) => SizedBox(
                  width: width,
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(PlanItSpacing.md),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Icon(item.$3, color: item.$4),
                          const SizedBox(height: PlanItSpacing.sm),
                          Text(
                            item.$1,
                            style: Theme.of(context).textTheme.labelMedium,
                          ),
                          const SizedBox(height: PlanItSpacing.xxs),
                          FittedBox(
                            child: Text(
                              item.$2.toDisplayString(),
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w800),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              )
              .toList(growable: false),
        );
      },
    );
  }
}

class _TrendChart extends StatelessWidget {
  const _TrendChart({required this.points});
  final List<TrendPoint> points;

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(PlanItSpacing.lg),
          child: Text('No posted activity in this period.'),
        ),
      );
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          PlanItSpacing.sm,
          PlanItSpacing.lg,
          PlanItSpacing.lg,
          PlanItSpacing.sm,
        ),
        child: Column(
          children: <Widget>[
            const Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: <Widget>[
                _ChartLegend(color: PlanItColors.negative, label: 'Spending'),
                SizedBox(width: PlanItSpacing.md),
                _ChartLegend(color: PlanItColors.positive, label: 'Income'),
              ],
            ),
            const SizedBox(height: PlanItSpacing.sm),
            SizedBox(
              height: 220,
              child: LineChart(
                LineChartData(
                  gridData: const FlGridData(
                    show: true,
                    drawVerticalLine: false,
                  ),
                  borderData: FlBorderData(show: false),
                  titlesData: const FlTitlesData(
                    topTitles: AxisTitles(),
                    rightTitles: AxisTitles(),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 42,
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                  ),
                  lineBarsData: <LineChartBarData>[
                    LineChartBarData(
                      spots: _spots(points, (point) => point.spending),
                      color: PlanItColors.negative,
                      barWidth: 3,
                      dotData: const FlDotData(show: false),
                      belowBarData: BarAreaData(
                        show: true,
                        color: PlanItColors.negative.withValues(alpha: .08),
                      ),
                    ),
                    LineChartBarData(
                      spots: _spots(points, (point) => point.income),
                      color: PlanItColors.positive,
                      barWidth: 3,
                      dotData: const FlDotData(show: false),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static List<FlSpot> _spots(
    List<TrendPoint> values,
    Money Function(TrendPoint) pick,
  ) => List<FlSpot>.generate(
    values.length,
    (index) => FlSpot(
      index.toDouble(),
      pick(values[index]).scaledAmount.toDouble() / 10000,
    ),
  );
}

class _ChartLegend extends StatelessWidget {
  const _ChartLegend({required this.color, required this.label});
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: <Widget>[
      Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
      const SizedBox(width: PlanItSpacing.xxs),
      Text(label, style: Theme.of(context).textTheme.labelMedium),
    ],
  );
}

class _BreakdownList extends StatelessWidget {
  const _BreakdownList({required this.rows, required this.onSources});
  final List<BreakdownRow> rows;
  final void Function(String, List<String>) onSources;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(PlanItSpacing.lg),
          child: Text('No spending to break down in this period.'),
        ),
      );
    }
    final maximum = rows
        .map((row) => row.amount.scaledAmount.abs())
        .reduce((a, b) => a > b ? a : b);
    return Card(
      child: Column(
        children: rows
            .take(10)
            .map(
              (row) => InkWell(
                onTap: () => onSources(row.name, row.sourceTransactionIds),
                child: Padding(
                  padding: const EdgeInsets.all(PlanItSpacing.md),
                  child: Column(
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: Text(
                              row.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          Text(row.amount.toDisplayString()),
                        ],
                      ),
                      const SizedBox(height: PlanItSpacing.xs),
                      LinearProgressIndicator(
                        value: maximum == BigInt.zero
                            ? 0
                            : row.amount.scaledAmount.abs().toDouble() /
                                  maximum.toDouble(),
                        minHeight: 6,
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ],
                  ),
                ),
              ),
            )
            .toList(growable: false),
      ),
    );
  }
}

class _ProductCard extends StatelessWidget {
  const _ProductCard({required this.row, required this.onTap});
  final ProductAnalyticsRow row;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      onTap: onTap,
      leading: const CircleAvatar(child: Icon(Icons.inventory_2_outlined)),
      title: Text(
        row.variantLabel == null
            ? row.name
            : '${row.name} · ${row.variantLabel}',
      ),
      subtitle: Text(
        <String>[
          'Qty ${row.totalQuantity}',
          if (row.averageUnitPrice != null)
            'avg ${row.averageUnitPrice!.toDisplayString()}',
          if (row.normalizedAveragePrice != null)
            '${row.normalizedAveragePrice!.toDisplayString()} / '
                '${row.normalizedUnit}',
        ].join('  •  '),
      ),
      trailing: Text(
        row.spending.toDisplayString(),
        style: const TextStyle(fontWeight: FontWeight.w800),
      ),
    ),
  );
}

class _WarningCard extends StatelessWidget {
  const _WarningCard({required this.warning, required this.onAddRate});
  final AnalyticsWarning warning;
  final ValueChanged<String> onAddRate;

  @override
  Widget build(BuildContext context) => Card(
    color: Theme.of(context).colorScheme.errorContainer,
    child: Padding(
      padding: const EdgeInsets.all(PlanItSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Icon(Icons.warning_amber_rounded),
              const SizedBox(width: PlanItSpacing.xs),
              Expanded(child: Text(warning.message)),
            ],
          ),
          if (warning.currencies.isNotEmpty)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () => onAddRate(warning.currencies.first),
                icon: const Icon(Icons.add_rounded),
                label: Text('Add ${warning.currencies.first} rate'),
              ),
            ),
        ],
      ),
    ),
  );
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, required this.subtitle});
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: <Widget>[
      Text(
        title,
        style: Theme.of(
          context,
        ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
      ),
      const SizedBox(height: PlanItSpacing.xxs),
      Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
    ],
  );
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.onRetry});
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(PlanItSpacing.lg),
      child: Column(
        children: <Widget>[
          const Icon(Icons.cloud_off_outlined, size: 40),
          const SizedBox(height: PlanItSpacing.sm),
          const Text(
            'Analytics could not be loaded and no cached dashboard is available.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: PlanItSpacing.md),
          FilledButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Try again'),
          ),
        ],
      ),
    ),
  );
}
