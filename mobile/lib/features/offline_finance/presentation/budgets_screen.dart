import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:planit_mobile/core/auth/application/auth_controller.dart';
import 'package:planit_mobile/core/design_system/tokens.dart';
import 'package:planit_mobile/core/money/money.dart';
import 'package:planit_mobile/features/offline_finance/application/providers.dart';
import 'package:planit_mobile/features/offline_finance/domain/offline_finance.dart';
import 'package:planit_mobile/features/transactions/application/providers.dart';
import 'package:planit_mobile/features/transactions/domain/catalog.dart';

class BudgetsScreen extends ConsumerWidget {
  const BudgetsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(authControllerProvider).session;
    final categories =
        ref.watch(transactionCategoriesProvider).value ??
        const <TransactionCategory>[];
    final budgets = ref.watch(offlineBudgetsProvider);
    final progress = ref.watch(offlineBudgetProgressProvider);
    final categoryNames = <String, String>{
      for (final category in categories) category.id: category.name,
    };
    final expenseCategories = categories
        .where(
          (category) =>
              category.active &&
              (category.kind == CategoryKind.expense ||
                  category.kind == CategoryKind.both),
        )
        .toList(growable: false);

    return Scaffold(
      appBar: AppBar(title: const Text('Monthly budgets')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: session == null || expenseCategories.isEmpty
            ? null
            : () => _editBudget(
                context: context,
                ref: ref,
                categories: expenseCategories,
                currency: session.user.baseCurrency,
              ),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Set budget'),
      ),
      body: budgets.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => const Center(
          child: Text('PlanIT could not load budgets saved on this phone.'),
        ),
        data: (items) {
          final current = items
              .where((item) => item.monthKey == localMonthKey(DateTime.now()))
              .toList(growable: false);
          if (current.isEmpty) {
            return _EmptyBudgets(
              canCreate: expenseCategories.isNotEmpty && session != null,
              onCreate: () => _editBudget(
                context: context,
                ref: ref,
                categories: expenseCategories,
                currency: session?.user.baseCurrency ?? 'MAD',
              ),
            );
          }
          final progressByBudget = <String, CategoryBudgetProgress>{
            for (final item in progress) item.budget.id: item,
          };
          return ListView(
            padding: const EdgeInsets.fromLTRB(
              PlanItSpacing.lg,
              PlanItSpacing.lg,
              PlanItSpacing.lg,
              96,
            ),
            children: <Widget>[
              const _OfflineNote(),
              const SizedBox(height: PlanItSpacing.md),
              for (final budget in current)
                _BudgetCard(
                  budget: budget,
                  progress: progressByBudget[budget.id],
                  categoryName:
                      categoryNames[budget.categoryId] ?? 'Archived category',
                  onEdit: () => _editBudget(
                    context: context,
                    ref: ref,
                    categories: expenseCategories,
                    currency:
                        session?.user.baseCurrency ?? budget.limit.currency,
                    initial: budget,
                  ),
                  onDelete: () => ref
                      .read(offlineBudgetsProvider.notifier)
                      .remove(budget.id),
                ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _editBudget({
    required BuildContext context,
    required WidgetRef ref,
    required List<TransactionCategory> categories,
    required String currency,
    CategoryBudget? initial,
  }) async {
    final result = await showDialog<_BudgetInput>(
      context: context,
      builder: (context) => _BudgetEditor(
        categories: categories,
        currency: currency,
        initial: initial,
      ),
    );
    if (result == null || !context.mounted) return;
    try {
      await ref
          .read(offlineBudgetsProvider.notifier)
          .save(
            id: initial?.id,
            categoryId: result.categoryId,
            monthKey: localMonthKey(DateTime.now()),
            amount: result.amount,
            currency: currency,
            warningPercent: result.warningPercent,
          );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              initial == null
                  ? 'Budget saved on this phone.'
                  : 'Budget updated on this phone.',
            ),
          ),
        );
      }
    } on FormatException {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Enter a positive amount with up to 4 decimals.'),
          ),
        );
      }
    }
  }
}

class _OfflineNote extends StatelessWidget {
  const _OfflineNote();

  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      leading: const Icon(Icons.phone_android_rounded),
      title: const Text('Works without internet'),
      subtitle: const Text(
        'Budgets update from transactions saved on this phone. Budget syncing between devices will be added later.',
      ),
    ),
  );
}

class _EmptyBudgets extends StatelessWidget {
  const _EmptyBudgets({required this.canCreate, required this.onCreate});

  final bool canCreate;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(PlanItSpacing.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const Icon(Icons.pie_chart_outline, size: 54),
          const SizedBox(height: PlanItSpacing.md),
          Text(
            'Set a spending limit',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: PlanItSpacing.xs),
          const Text(
            'Create a monthly budget for groceries, transport, restaurants, or another expense category.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: PlanItSpacing.lg),
          FilledButton(
            onPressed: canCreate ? onCreate : null,
            child: const Text('Set a budget'),
          ),
        ],
      ),
    ),
  );
}

class _BudgetCard extends StatelessWidget {
  const _BudgetCard({
    required this.budget,
    required this.progress,
    required this.categoryName,
    required this.onEdit,
    required this.onDelete,
  });

  final CategoryBudget budget;
  final CategoryBudgetProgress? progress;
  final String categoryName;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final calculated =
        progress ??
        CategoryBudgetProgress(
          budget: budget,
          spent: Money.zero(budget.limit.currency),
        );
    final color = calculated.isOverLimit
        ? Theme.of(context).colorScheme.error
        : calculated.isNearLimit
        ? Colors.orange.shade700
        : Theme.of(context).colorScheme.primary;
    return Card(
      margin: const EdgeInsets.only(bottom: PlanItSpacing.sm),
      child: InkWell(
        borderRadius: BorderRadius.circular(PlanItRadius.md),
        onTap: onEdit,
        child: Padding(
          padding: const EdgeInsets.all(PlanItSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      categoryName,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Delete budget',
                    onPressed: onDelete,
                    icon: const Icon(Icons.delete_outline_rounded),
                  ),
                ],
              ),
              Text(
                '${calculated.spent.toDisplayString()} of ${budget.limit.toDisplayString()}',
              ),
              const SizedBox(height: PlanItSpacing.sm),
              LinearProgressIndicator(value: calculated.fraction, color: color),
              const SizedBox(height: PlanItSpacing.xs),
              Text(
                calculated.isOverLimit
                    ? '${calculated.percentUsed}% used · limit exceeded'
                    : '${calculated.percentUsed}% used · ${calculated.remaining.toDisplayString()} remaining',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

final class _BudgetInput {
  const _BudgetInput({
    required this.categoryId,
    required this.amount,
    required this.warningPercent,
  });

  final String categoryId;
  final String amount;
  final int warningPercent;
}

class _BudgetEditor extends StatefulWidget {
  const _BudgetEditor({
    required this.categories,
    required this.currency,
    this.initial,
  });

  final List<TransactionCategory> categories;
  final String currency;
  final CategoryBudget? initial;

  @override
  State<_BudgetEditor> createState() => _BudgetEditorState();
}

class _BudgetEditorState extends State<_BudgetEditor> {
  late final TextEditingController _amount = TextEditingController(
    text: widget.initial?.limit.toApiString() ?? '',
  );
  String? _categoryId;
  late int _warningPercent = widget.initial?.warningPercent ?? 80;

  @override
  void initState() {
    super.initState();
    _categoryId =
        widget.categories
            .where((item) => item.id == widget.initial?.categoryId)
            .firstOrNull
            ?.id ??
        widget.categories.firstOrNull?.id;
  }

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.initial == null ? 'Set monthly budget' : 'Edit budget'),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          DropdownButtonFormField<String>(
            initialValue: _categoryId,
            decoration: const InputDecoration(labelText: 'Category'),
            items: widget.categories
                .map(
                  (item) => DropdownMenuItem<String>(
                    value: item.id,
                    child: Text(item.name),
                  ),
                )
                .toList(growable: false),
            onChanged: (value) => setState(() => _categoryId = value),
          ),
          const SizedBox(height: PlanItSpacing.md),
          TextField(
            controller: _amount,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: 'Monthly limit (${widget.currency})',
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: PlanItSpacing.md),
          DropdownButtonFormField<int>(
            initialValue: _warningPercent,
            decoration: const InputDecoration(labelText: 'Warning at'),
            items: const <int>[80, 90, 100]
                .map(
                  (value) => DropdownMenuItem<int>(
                    value: value,
                    child: Text('$value% used'),
                  ),
                )
                .toList(growable: false),
            onChanged: (value) => setState(() => _warningPercent = value ?? 80),
          ),
        ],
      ),
    ),
    actions: <Widget>[
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: _categoryId == null || _amount.text.trim().isEmpty
            ? null
            : () => Navigator.pop(
                context,
                _BudgetInput(
                  categoryId: _categoryId!,
                  amount: _amount.text.trim(),
                  warningPercent: _warningPercent,
                ),
              ),
        child: const Text('Save'),
      ),
    ],
  );
}
