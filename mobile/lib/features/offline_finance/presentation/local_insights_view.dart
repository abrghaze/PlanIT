import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:planit_mobile/core/auth/application/auth_controller.dart';
import 'package:planit_mobile/core/money/money.dart';
import 'package:planit_mobile/core/money/money_format.dart';
import 'package:planit_mobile/features/offline_finance/application/providers.dart';
import 'package:planit_mobile/features/offline_finance/domain/local_report.dart';
import 'package:planit_mobile/features/transactions/application/providers.dart';
import 'package:planit_mobile/features/transactions/domain/catalog.dart';
import 'package:planit_mobile/features/transactions/domain/transaction.dart';

class LocalInsightsView extends ConsumerStatefulWidget {
  const LocalInsightsView({super.key});
  @override
  ConsumerState<LocalInsightsView> createState() => _LocalInsightsViewState();
}

class _LocalInsightsViewState extends ConsumerState<LocalInsightsView> {
  DateTime? _selectedMonth;
  String? _currency;

  @override
  Widget build(BuildContext context) {
    final now = ref.watch(localClockProvider);
    final month = _selectedMonth ?? DateTime(now.year, now.month);
    final base =
        ref.watch(authControllerProvider).session?.user.baseCurrency ?? 'MAD';
    final state = ref.watch(transactionsProvider);
    final names = {
      for (final c
          in ref.watch(transactionCategoriesProvider).value ??
              const <TransactionCategory>[])
        c.id: c.name,
    };
    return state.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(32),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (_, _) => Card(
        child: ListTile(
          title: const Text('Could not read transactions on this phone'),
          trailing: IconButton(
            tooltip: 'Try again',
            onPressed: () => ref.invalidate(transactionsProvider),
            icon: const Icon(Icons.refresh),
          ),
        ),
      ),
      data: (transactions) {
        final currencies = {
          base,
          for (final t in transactions) t.amount.currency,
        }.toList()..sort();
        final currency = currencies.contains(_currency) ? _currency! : base;
        final report = buildLocalReport(
          transactions: transactions,
          currency: currency,
          month: month,
          asOf: now,
        );
        final categories = report.categories.entries.toList()
          ..sort(
            (a, b) => b.value.scaledAmount.compareTo(a.value.scaledAmount),
          );
        final previous = buildLocalReport(
          transactions: transactions,
          currency: currency,
          month: DateTime(month.year, month.month - 1),
        );
        final difference = report.netSpending - previous.netSpending;
        final positiveTotal = categories
            .where((e) => e.value.scaledAmount > BigInt.zero)
            .fold<BigInt>(BigInt.zero, (sum, e) => sum + e.value.scaledAmount);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                IconButton(
                  tooltip: 'Previous month',
                  onPressed: () => setState(
                    () =>
                        _selectedMonth = DateTime(month.year, month.month - 1),
                  ),
                  icon: const Icon(Icons.chevron_left),
                ),
                Expanded(
                  child: Text(
                    MaterialLocalizations.of(context).formatMonthYear(month),
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                IconButton(
                  tooltip: 'Next month',
                  onPressed: month.year == now.year && month.month == now.month
                      ? null
                      : () => setState(
                          () => _selectedMonth = DateTime(
                            month.year,
                            month.month + 1,
                          ),
                        ),
                  icon: const Icon(Icons.chevron_right),
                ),
              ],
            ),
            DropdownButtonFormField<String>(
              key: ValueKey(currency),
              initialValue: currency,
              decoration: const InputDecoration(labelText: 'Report currency'),
              items: currencies
                  .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                  .toList(),
              onChanged: (value) => setState(() => _currency = value),
            ),
            const SizedBox(height: 12),
            Text(
              'Calculated from records saved on this phone, using its time zone. Transfers and loan principal are not spending. Shared expenses show their full cost.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (report.pendingCount > 0)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  '${report.pendingCount} local changes await confirmation; these totals are estimates.',
                ),
              ),
            if (report.omittedCurrencies.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Also recorded in ${report.omittedCurrencies.join(', ')}. Select a currency above to view it separately.',
                ),
              ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _Metric('Income', report.income),
                    _Metric('Expenses', report.grossSpending),
                    _Metric('Refunds', report.refunds),
                    const Divider(),
                    _Metric('Spending after refunds', report.netSpending),
                    _Metric('Income less spending', report.remainingIncome),
                    const SizedBox(height: 8),
                    Text(
                      '${difference.scaledAmount.isNegative ? (-difference).toDisplayString() : difference.toDisplayString()} '
                      '${difference.scaledAmount.isNegative ? 'less' : 'more'} spending than the full previous month.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Where your money went',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            if (categories.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: Text(
                    'No expenses recorded for this month and currency. Add an expense to see the breakdown.',
                  ),
                ),
              ),
            for (final entry in categories)
              Card(
                child: ListTile(
                  title: Text(
                    entry.key.isEmpty
                        ? 'Uncategorized'
                        : names[entry.key] ?? 'Archived category',
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: LinearProgressIndicator(
                      value: positiveTotal == BigInt.zero
                          ? 0
                          : (entry.value.scaledAmount.toDouble() /
                                    positiveTotal.toDouble())
                                .clamp(0, 1),
                    ),
                  ),
                  trailing: Text(entry.value.toDisplayString()),
                  onTap: () => _showSources(
                    context,
                    report.sources
                        .where(
                          (t) =>
                              !t.type.isIncome &&
                              (t.categoryId ?? '') == entry.key,
                        )
                        .toList(),
                  ),
                ),
              ),
            const SizedBox(height: 16),
            Text(
              'Largest expenses',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            ..._largest(report.sources).map(
              (t) => Card(
                child: ListTile(
                  leading: const Icon(Icons.receipt_long_outlined),
                  title: Text(
                    t.counterparty ?? names[t.categoryId] ?? t.type.label,
                  ),
                  subtitle: Text(
                    MaterialLocalizations.of(
                      context,
                    ).formatShortDate(t.occurredAt.toLocal()),
                  ),
                  trailing: Text(t.amount.toDisplayString()),
                  onTap: () => context.push('/transactions/${t.id}'),
                ),
              ),
            ),
            if (report.sources.isNotEmpty)
              TextButton.icon(
                onPressed: () => _showSources(context, report.sources),
                icon: const Icon(Icons.list_alt),
                label: Text('View all ${report.sources.length} source records'),
              ),
          ],
        );
      },
    );
  }

  List<LedgerTransaction> _largest(List<LedgerTransaction> rows) =>
      (rows.where((t) => t.type.isSpending).toList()..sort(
            (a, b) => b.amount.scaledAmount.compareTo(a.amount.scaledAmount),
          ))
          .take(5)
          .toList();

  void _showSources(BuildContext context, List<LedgerTransaction> rows) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(sheetContext).height * .65,
          child: Column(
            children: [
              Text(
                '${rows.length} source records',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: rows.length,
                  itemBuilder: (_, index) {
                    final t = rows[index];
                    return ListTile(
                      title: Text(t.counterparty ?? t.type.label),
                      subtitle: Text(
                        '${t.type.label} · ${MaterialLocalizations.of(context).formatShortDate(t.occurredAt.toLocal())}',
                      ),
                      trailing: Text(t.amount.toDisplayString()),
                      onTap: () {
                        Navigator.pop(sheetContext);
                        context.push('/transactions/${t.id}');
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric(this.label, this.money);
  final String label;
  final Money money;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Wrap(
      alignment: WrapAlignment.spaceBetween,
      spacing: 16,
      runSpacing: 4,
      children: [
        Text(label),
        Text(
          money.toDisplayString(),
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ],
    ),
  );
}
