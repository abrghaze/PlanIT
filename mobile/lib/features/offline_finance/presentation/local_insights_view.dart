import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:planit_mobile/core/auth/application/auth_controller.dart';
import 'package:planit_mobile/core/money/money.dart';
import 'package:planit_mobile/core/money/money_format.dart';
import 'package:planit_mobile/features/offline_finance/application/providers.dart';
import 'package:planit_mobile/features/offline_finance/domain/report_period.dart';
import 'package:planit_mobile/features/transactions/application/providers.dart';
import 'package:planit_mobile/features/transactions/domain/catalog.dart';
import 'package:planit_mobile/features/transactions/domain/transaction.dart';

class LocalInsightsView extends ConsumerWidget {
  const LocalInsightsView({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final names = <String, String>{
      for (final c
          in ref.watch(transactionCategoriesProvider).value ??
              const <TransactionCategory>[])
        c.id: c.name,
    };
    final currency =
        ref.watch(authControllerProvider).session?.user.baseCurrency ?? 'MAD';
    return ref
        .watch(transactionsProvider)
        .when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) => ListTile(
            title: const Text('Could not read saved transactions'),
            trailing: IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () => ref.invalidate(transactionsProvider),
            ),
          ),
          data: (rows) => ReportDashboard(
            rows: rows,
            names: names,
            currency: currency,
            now: ref.watch(localClockProvider),
            onEntry: (row) => context.push('/transactions/${row.id}'),
          ),
        );
  }
}

class ReportDashboard extends StatefulWidget {
  const ReportDashboard({
    required this.rows,
    required this.names,
    required this.currency,
    required this.now,
    required this.onEntry,
    this.planning,
    super.key,
  });
  final List<LedgerTransaction> rows;
  final Map<String, String> names;
  final String currency;
  final DateTime now;
  final void Function(LedgerTransaction) onEntry;
  final Widget Function(ReportPeriod, String)? planning;
  @override
  State<ReportDashboard> createState() => _ReportDashboardState();
}

class _ReportDashboardState extends State<ReportDashboard> {
  ReportSpan _span = ReportSpan.month;
  ReportPeriod? _selected;
  String? _currency;
  int _pickerRevision = 0;
  String _name(ReportSpan s) => switch (s) {
    ReportSpan.day => 'Day',
    ReportSpan.week => 'Week',
    ReportSpan.month => 'Month',
    ReportSpan.year => 'Year',
    ReportSpan.custom => 'Custom range',
  };
  Future<void> _choose(ReportSpan span) async {
    if (span == ReportSpan.custom) {
      final range = await showDateRangePicker(
        context: context,
        firstDate: DateTime(1970),
        lastDate: calendarDay(widget.now),
        initialDateRange: DateTimeRange(
          start: DateTime(widget.now.year, widget.now.month),
          end: calendarDay(widget.now),
        ),
      );
      if (!mounted) return;
      if (range == null) {
        setState(() => _pickerRevision++);
        return;
      }
      if (calendarDistance(range.start, range.end) > 3659) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Choose a range of up to ten years.')),
        );
        setState(() => _pickerRevision++);
        return;
      }
      setState(() {
        _span = span;
        _selected = ReportPeriod(
          span,
          range.start,
          DateTime(range.end.year, range.end.month, range.end.day + 1),
        );
      });
    } else {
      setState(() {
        _span = span;
        _selected = null;
      });
    }
  }

  String _label(ReportPeriod p) {
    final l = MaterialLocalizations.of(context);
    return switch (p.span) {
      ReportSpan.day => l.formatFullDate(p.start),
      ReportSpan.month => l.formatMonthYear(p.start),
      ReportSpan.year => p.start.year.toString(),
      _ =>
        '${l.formatShortDate(p.start)} – ${l.formatShortDate(DateTime(p.end.year, p.end.month, p.end.day - 1))}',
    };
  }

  @override
  Widget build(BuildContext context) {
    final period = _selected ?? ReportPeriod.at(_span, widget.now);
    final currencies = {
      widget.currency,
      for (final r in widget.rows) r.amount.currency,
    }.toList()..sort();
    final currency = currencies.contains(_currency)
        ? _currency!
        : widget.currency;
    final result = buildPeriodReport(
      transactions: widget.rows,
      currency: currency,
      period: period,
      now: widget.now,
    );
    final r = result.current;
    final difference = r.netSpending - result.previous.netSpending;
    final cats = r.categories.entries.toList()
      ..sort((a, b) => b.value.scaledAmount.compareTo(a.value.scaledAmount));
    final grossByCategory = <String, Money>{};
    for (final row in r.sources.where((t) => t.type.isSpending)) {
      grossByCategory.update(
        row.categoryId ?? '',
        (m) => m + row.amount,
        ifAbsent: () => row.amount,
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            SizedBox(
              width: 160,
              child: DropdownButtonFormField<ReportSpan>(
                isExpanded: true,
                initialValue: _span,
                key: ValueKey((_span, _pickerRevision)),
                decoration: const InputDecoration(labelText: 'Period'),
                items: ReportSpan.values
                    .map(
                      (s) => DropdownMenuItem(
                        value: s,
                        child: Text(_name(s), overflow: TextOverflow.ellipsis),
                      ),
                    )
                    .toList(),
                onChanged: (s) {
                  if (s != null) _choose(s);
                },
              ),
            ),
            SizedBox(
              width: 150,
              child: DropdownButtonFormField<String>(
                isExpanded: true,
                key: ValueKey(currency),
                initialValue: currency,
                decoration: const InputDecoration(labelText: 'Report currency'),
                items: currencies
                    .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                    .toList(),
                onChanged: (c) => setState(() => _currency = c),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            IconButton(
              tooltip: 'Previous ${_name(_span).toLowerCase()}',
              icon: const Icon(Icons.chevron_left),
              onPressed: () => setState(() => _selected = period.shift(-1)),
            ),
            Expanded(
              child: Text(
                _label(period),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            IconButton(
              tooltip: 'Next ${_name(_span).toLowerCase()}',
              icon: const Icon(Icons.chevron_right),
              onPressed: period.shift(1).start.isAfter(widget.now)
                  ? null
                  : () => setState(() => _selected = period.shift(1)),
            ),
          ],
        ),
        if (_selected != null)
          TextButton(
            onPressed: () => setState(() {
              _selected = null;
              if (_span == ReportSpan.custom) _span = ReportSpan.month;
            }),
            child: const Text('Back to current period'),
          ),
        Text(
          result.partial
              ? 'So far · compared with the same elapsed part of the previous period.'
              : 'Complete period · compared with the preceding equivalent period.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        if (_span == ReportSpan.week) const Text('Weeks run Monday–Sunday.'),
        if (r.pendingCount > 0)
          Text(
            '${r.pendingCount} pending changes included; these figures are estimates.',
          ),
        if (r.omittedCurrencies.isNotEmpty)
          Text(
            'Other currencies stay separate: ${r.omittedCurrencies.join(', ')}',
          ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _metric(
                  'Income',
                  r.income,
                  r.sources.where((t) => t.type.isIncome).toList(),
                ),
                _metric(
                  'Expenses',
                  r.grossSpending,
                  r.sources.where((t) => t.type.isSpending).toList(),
                ),
                _metric(
                  'Refunds',
                  r.refunds,
                  r.sources
                      .where((t) => t.type == TransactionType.refund)
                      .toList(),
                ),
                const Divider(),
                _metric(
                  'Spending after refunds',
                  r.netSpending,
                  r.sources.where((t) => !t.type.isIncome).toList(),
                ),
                _metric('Net cash flow', r.remainingIncome, r.sources),
                const Divider(),
                Text(
                  'Previous comparison period',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Text(
                  'Income ${result.previous.income.toDisplayString()} · Expenses ${result.previous.grossSpending.toDisplayString()}',
                ),
                Text(
                  'Refunds ${result.previous.refunds.toDisplayString()} · Net cash flow ${result.previous.remainingIncome.toDisplayString()}',
                ),
                TextButton(
                  onPressed: () => _sources(result.previous.sources),
                  child: const Text('View comparison records'),
                ),
                const SizedBox(height: 8),
                Text(
                  difference.scaledAmount == BigInt.zero
                      ? 'Spending is unchanged from the comparison period.'
                      : '${difference.scaledAmount.isNegative ? (-difference).toDisplayString() : difference.toDisplayString()}${difference.scaledAmount.isNegative ? ' less' : ' more'} spending than the comparison period.',
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Income & spending trend',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const Text(
          'Income and expenses before refunds. Tap a bar to see its records.',
        ),
        const SizedBox(height: 8),
        _trend(result),
        const SizedBox(height: 20),
        Text(
          'Where your money went',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const Text(
          'Percentages use expenses before refunds. Each amount also shows refunds and net spending.',
        ),
        if (cats.isEmpty)
          const Padding(
            padding: EdgeInsets.all(20),
            child: Text(
              'No spending in this period. Add an expense to see the breakdown.',
            ),
          ),
        for (final c in cats)
          Builder(
            builder: (context) {
              final gross = grossByCategory[c.key] ?? Money.zero(currency);
              final percent = r.grossSpending.scaledAmount == BigInt.zero
                  ? 0.0
                  : (gross.scaledAmount *
                                BigInt.from(10000) ~/
                                r.grossSpending.scaledAmount)
                            .toInt() /
                        100;
              return Card(
                child: InkWell(
                  onTap: () => _sources(
                    r.sources
                        .where(
                          (t) =>
                              !t.type.isIncome && (t.categoryId ?? '') == c.key,
                        )
                        .toList(),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 12,
                          children: [
                            Text(
                              c.key.isEmpty
                                  ? 'Uncategorized'
                                  : widget.names[c.key] ?? 'Archived category',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            Text('${percent.toStringAsFixed(1)}%'),
                          ],
                        ),
                        const SizedBox(height: 8),
                        LinearProgressIndicator(
                          value: (percent / 100).clamp(0, 1),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Expenses ${gross.toDisplayString()} · Refunds ${(gross - c.value).toDisplayString()}',
                        ),
                        Text(
                          'Net ${c.value.toDisplayString()}',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        const SizedBox(height: 16),
        Text('Largest expenses', style: Theme.of(context).textTheme.titleLarge),
        ...((r.sources.where((t) => t.type.isSpending).toList()..sort(
              (a, b) => b.amount.scaledAmount.compareTo(a.amount.scaledAmount),
            ))
            .take(5)
            .map((t) => _tile(t, () => widget.onEntry(t)))),
        if (r.sources.isNotEmpty)
          TextButton.icon(
            onPressed: () => _sources(r.sources),
            icon: const Icon(Icons.list_alt),
            label: Text('View all ${r.sources.length} source records'),
          ),
        if (widget.planning != null) widget.planning!(period, currency),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _metric(String title, Money amount, List<LedgerTransaction> rows) =>
      InkWell(
        onTap: () => _sources(rows),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(title),
              Text(
                amount.toDisplayString(),
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
            ],
          ),
        ),
      );
  Widget _tile(LedgerTransaction t, VoidCallback action) => Card(
    child: ListTile(
      title: Text(t.counterparty ?? widget.names[t.categoryId] ?? t.type.label),
      subtitle: Text(
        '${t.type.label} · ${MaterialLocalizations.of(context).formatShortDate(t.occurredAt.toLocal())}\n${t.amount.toDisplayString()}',
      ),
      isThreeLine: true,
      onTap: action,
    ),
  );
  void _sources(List<LedgerTransaction> rows) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheet) => SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(sheet).height * .75,
          child: Column(
            children: [
              Text(
                '${rows.length} source records',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              if (rows.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Text('No transactions contribute to this total.'),
                ),
              Expanded(
                child: ListView(
                  children: [
                    for (final row in rows)
                      _tile(row, () {
                        Navigator.pop(sheet);
                        widget.onEntry(row);
                      }),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _trend(PeriodReport result) {
    var peak = Money.zero(result.current.currency);
    for (final b in result.buckets) {
      for (final amount in [b.report.income, b.report.grossSpending]) {
        if (amount.scaledAmount > peak.scaledAmount) peak = amount;
      }
    }
    final max = result.buckets.fold<double>(1, (value, b) {
      final high =
          b.report.income.scaledAmount.toDouble() >
              b.report.grossSpending.scaledAmount.toDouble()
          ? b.report.income.scaledAmount.toDouble()
          : b.report.grossSpending.scaledAmount.toDouble();
      return high > value ? high : value;
    });
    String label(ReportBucket b) => _span == ReportSpan.day
        ? '${b.start.hour}:00'
        : _span == ReportSpan.year ||
              calendarDistance(result.period.start, result.period.end) > 62
        ? '${b.start.month}/${b.start.year}'
        : '${b.start.day}/${b.start.month}';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Chart peak: ${peak.toDisplayString()}. Swipe to see the whole period.',
            ),
            const Wrap(
              spacing: 16,
              children: [
                Text('● Income', style: TextStyle(color: Colors.teal)),
                Text('● Expenses', style: TextStyle(color: Colors.deepOrange)),
              ],
            ),
            SizedBox(
              height: 180,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    for (final b in result.buckets)
                      Semantics(
                        label:
                            '${label(b)}, income ${b.report.income.toDisplayString()}, expenses ${b.report.grossSpending.toDisplayString()}',
                        button: true,
                        child: InkWell(
                          onTap: () => _sources(b.report.sources),
                          child: SizedBox(
                            width: 44,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                SizedBox(
                                  height: 120,
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Container(
                                        width: 18,
                                        height:
                                            118 *
                                            b.report.income.scaledAmount
                                                .toDouble() /
                                            max,
                                        color: Colors.teal,
                                      ),
                                      const SizedBox(width: 4),
                                      Container(
                                        width: 18,
                                        height:
                                            118 *
                                            b.report.grossSpending.scaledAmount
                                                .toDouble() /
                                            max,
                                        color: Colors.deepOrange,
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  label(b),
                                  textScaler: const TextScaler.linear(1),
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                        ),
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
}
