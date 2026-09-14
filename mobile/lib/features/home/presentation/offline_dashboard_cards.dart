import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:planit_mobile/core/design_system/tokens.dart';
import 'package:planit_mobile/core/money/money_format.dart';
import 'package:planit_mobile/features/offline_finance/domain/offline_finance.dart';
import 'package:planit_mobile/features/transactions/domain/catalog.dart';

class LocalMonthlyHealthCard extends StatelessWidget {
  const LocalMonthlyHealthCard({required this.summary, super.key});

  final LocalMonthlySummary summary;

  @override
  Widget build(BuildContext context) {
    final net = summary.netIncome;
    final headline = net.scaledAmount.isNegative
        ? 'Spent ${(-net).toDisplayString()} more than income'
        : net.scaledAmount == BigInt.zero
        ? 'Income and spending are even'
        : 'Kept ${net.toDisplayString()} this month';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(PlanItSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                const CircleAvatar(child: Icon(Icons.phone_android_rounded)),
                const SizedBox(width: PlanItSpacing.md),
                Expanded(
                  child: Text(
                    headline,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: PlanItSpacing.md),
            Text(
              'Recorded on this phone · Spent ${summary.spending.toDisplayString()} '
              '· Income ${summary.income.toDisplayString()}',
            ),
            if (summary.pendingPostedCount > 0) ...<Widget>[
              const SizedBox(height: PlanItSpacing.xs),
              Text(
                '${summary.pendingPostedCount} posted ${summary.pendingPostedCount == 1 ? 'change is' : 'changes are'} waiting to synchronize.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            if (summary.hasCurrencyWarning) ...<Widget>[
              const SizedBox(height: PlanItSpacing.xs),
              Text(
                'Amounts in ${summary.omittedCurrencies.join(', ')} are shown in their accounts but are not added to this ${summary.currency} summary.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class BudgetOverview extends StatelessWidget {
  const BudgetOverview({
    required this.progress,
    required this.categories,
    super.key,
  });

  final List<CategoryBudgetProgress> progress;
  final List<TransactionCategory> categories;

  @override
  Widget build(BuildContext context) {
    if (progress.isEmpty) {
      return Card(
        child: ListTile(
          leading: const CircleAvatar(child: Icon(Icons.pie_chart_outline)),
          title: const Text('Give your spending a limit'),
          subtitle: const Text('Set a monthly limit for groceries, transport, or any category.'),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: () => context.push('/budgets'),
        ),
      );
    }
    final visible = progress.take(3).toList(growable: false);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(PlanItSpacing.lg),
        child: Column(
          children: <Widget>[
            for (final item in visible) ...<Widget>[
              _BudgetRow(
                progress: item,
                categoryName: _categoryName(item.budget.categoryId),
              ),
              if (item != visible.last) const Divider(height: PlanItSpacing.lg),
            ],
          ],
        ),
      ),
    );
  }

  String _categoryName(String id) {
    for (final category in categories) {
      if (category.id == id) return category.name;
    }
    return 'Archived category';
  }
}

class _BudgetRow extends StatelessWidget {
  const _BudgetRow({required this.progress, required this.categoryName});

  final CategoryBudgetProgress progress;
  final String categoryName;

  @override
  Widget build(BuildContext context) {
    final color = progress.isOverLimit
        ? Theme.of(context).colorScheme.error
        : progress.isNearLimit
        ? Colors.orange.shade700
        : Theme.of(context).colorScheme.primary;
    final label = progress.isOverLimit
        ? '${progress.percentUsed}% used · ${progress.spent.toDisplayString()} over ${progress.budget.limit.toDisplayString()}'
        : '${progress.percentUsed}% used · ${progress.remaining.toDisplayString()} left';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                categoryName,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            Text(progress.spent.toDisplayString()),
          ],
        ),
        const SizedBox(height: PlanItSpacing.xs),
        LinearProgressIndicator(value: progress.fraction, color: color),
        const SizedBox(height: PlanItSpacing.xxs),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}
