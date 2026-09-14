import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:planit_mobile/core/auth/application/auth_controller.dart';
import 'package:planit_mobile/core/design_system/tokens.dart';
import 'package:planit_mobile/core/money/money.dart';
import 'package:planit_mobile/core/money/money_format.dart';
import 'package:planit_mobile/features/accounts/application/providers.dart';
import 'package:planit_mobile/features/accounts/domain/account.dart';
import 'package:planit_mobile/features/offline_finance/application/providers.dart';
import 'package:planit_mobile/features/offline_finance/domain/offline_finance.dart';
import 'package:planit_mobile/features/transactions/application/providers.dart';
import 'package:planit_mobile/features/transactions/domain/catalog.dart';
import 'package:planit_mobile/features/transactions/domain/transaction.dart';
import 'package:uuid/uuid.dart';

class TemplatesScreen extends ConsumerWidget {
  const TemplatesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final templates = ref.watch(offlineTemplatesProvider);
    final accounts = ref.watch(accountsProvider).value ?? const <Account>[];
    final categories =
        ref.watch(transactionCategoriesProvider).value ??
        const <TransactionCategory>[];
    final session = ref.watch(authControllerProvider).session;
    return Scaffold(
      appBar: AppBar(title: const Text('Quick entry templates')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: session == null || accounts.isEmpty
            ? null
            : () => _editTemplate(
                context: context,
                ref: ref,
                accounts: accounts,
                categories: categories,
              ),
        icon: const Icon(Icons.add_rounded),
        label: const Text('New template'),
      ),
      body: templates.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => const Center(
          child: Text('PlanIT could not load templates saved on this phone.'),
        ),
        data: (items) => items.isEmpty
            ? _EmptyTemplates(
                canCreate: session != null && accounts.isNotEmpty,
                onCreate: () => _editTemplate(
                  context: context,
                  ref: ref,
                  accounts: accounts,
                  categories: categories,
                ),
              )
            : ListView(
                padding: const EdgeInsets.fromLTRB(
                  PlanItSpacing.lg,
                  PlanItSpacing.lg,
                  PlanItSpacing.lg,
                  96,
                ),
                children: <Widget>[
                  const Card(
                    child: ListTile(
                      leading: Icon(Icons.phone_android_rounded),
                      title: Text('Available without internet'),
                      subtitle: Text(
                        'Use templates from the Add transaction screen.',
                      ),
                    ),
                  ),
                  const SizedBox(height: PlanItSpacing.md),
                  for (final template in items)
                    _TemplateCard(
                      template: template,
                      accountName: _accountName(accounts, template.accountId),
                      categoryName: _categoryName(
                        categories,
                        template.categoryId,
                      ),
                      onEdit: () => _editTemplate(
                        context: context,
                        ref: ref,
                        accounts: accounts,
                        categories: categories,
                        initial: template,
                      ),
                      onDelete: () => ref
                          .read(offlineTemplatesProvider.notifier)
                          .remove(template.id),
                    ),
                ],
              ),
      ),
    );
  }

  Future<void> _editTemplate({
    required BuildContext context,
    required WidgetRef ref,
    required List<Account> accounts,
    required List<TransactionCategory> categories,
    QuickTransactionTemplate? initial,
  }) async {
    final template = await showDialog<QuickTransactionTemplate>(
      context: context,
      builder: (context) => _TemplateEditor(
        accounts: accounts,
        categories: categories,
        initial: initial,
      ),
    );
    if (template == null || !context.mounted) return;
    await ref.read(offlineTemplatesProvider.notifier).save(template);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            initial == null
                ? 'Template saved on this phone.'
                : 'Template updated.',
          ),
        ),
      );
    }
  }

  static String _accountName(List<Account> accounts, String? id) {
    for (final account in accounts) {
      if (account.id == id) return account.name;
    }
    return 'Choose when used';
  }

  static String _categoryName(
    List<TransactionCategory> categories,
    String? id,
  ) {
    for (final category in categories) {
      if (category.id == id) return category.name;
    }
    return 'No category';
  }
}

class _EmptyTemplates extends StatelessWidget {
  const _EmptyTemplates({required this.canCreate, required this.onCreate});

  final bool canCreate;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(PlanItSpacing.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const Icon(Icons.bolt_outlined, size: 54),
          const SizedBox(height: PlanItSpacing.md),
          Text(
            'Make repeated expenses faster',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: PlanItSpacing.xs),
          const Text(
            'Save a starting point for transport, coffee, rent, or another repeated transaction.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: PlanItSpacing.lg),
          FilledButton(
            onPressed: canCreate ? onCreate : null,
            child: const Text('Create a template'),
          ),
        ],
      ),
    ),
  );
}

class _TemplateCard extends StatelessWidget {
  const _TemplateCard({
    required this.template,
    required this.accountName,
    required this.categoryName,
    required this.onEdit,
    required this.onDelete,
  });

  final QuickTransactionTemplate template;
  final String accountName;
  final String categoryName;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(bottom: PlanItSpacing.sm),
    child: ListTile(
      leading: CircleAvatar(
        child: Icon(
          template.type == TransactionType.expense
              ? Icons.arrow_upward_rounded
              : Icons.arrow_downward_rounded,
        ),
      ),
      title: Text(template.name),
      subtitle: Text(
        '${template.amount?.toDisplayString() ?? 'Amount chosen each time'} · '
        '$accountName · $categoryName',
      ),
      onTap: onEdit,
      trailing: IconButton(
        tooltip: 'Delete template',
        onPressed: onDelete,
        icon: const Icon(Icons.delete_outline_rounded),
      ),
    ),
  );
}

class _TemplateEditor extends StatefulWidget {
  const _TemplateEditor({
    required this.accounts,
    required this.categories,
    this.initial,
  });

  final List<Account> accounts;
  final List<TransactionCategory> categories;
  final QuickTransactionTemplate? initial;

  @override
  State<_TemplateEditor> createState() => _TemplateEditorState();
}

class _TemplateEditorState extends State<_TemplateEditor> {
  late final TextEditingController _name = TextEditingController(
    text: widget.initial?.name ?? '',
  );
  late final TextEditingController _amount = TextEditingController(
    text: widget.initial?.amount?.toApiString() ?? '',
  );
  late final TextEditingController _note = TextEditingController(
    text: widget.initial?.note ?? '',
  );
  late TransactionType _type = widget.initial?.type ?? TransactionType.expense;
  String? _accountId;
  String? _categoryId;

  @override
  void initState() {
    super.initState();
    _accountId =
        widget.accounts
            .where((account) => account.id == widget.initial?.accountId)
            .firstOrNull
            ?.id ??
        widget.accounts
            .where((item) => item.status == AccountStatus.active)
            .firstOrNull
            ?.id;
    _categoryId = widget.categories
        .where((category) => category.id == widget.initial?.categoryId)
        .firstOrNull
        ?.id;
  }

  @override
  void dispose() {
    _name.dispose();
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  List<TransactionCategory> get _matchingCategories => widget.categories
      .where(
        (category) =>
            category.active &&
            (category.kind == CategoryKind.both ||
                (_type == TransactionType.expense &&
                    category.kind == CategoryKind.expense) ||
                (_type == TransactionType.income &&
                    category.kind == CategoryKind.income)),
      )
      .toList(growable: false);

  @override
  Widget build(BuildContext context) {
    final activeAccounts = widget.accounts
        .where((account) => account.status == AccountStatus.active)
        .toList(growable: false);
    final selectedAccount = activeAccounts
        .where((account) => account.id == _accountId)
        .firstOrNull;
    final categories = _matchingCategories;
    final categoryId = categories.any((item) => item.id == _categoryId)
        ? _categoryId
        : null;
    return AlertDialog(
      title: Text(
        widget.initial == null ? 'New quick template' : 'Edit template',
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            TextField(
              controller: _name,
              autofocus: true,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Template name'),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: PlanItSpacing.md),
            SegmentedButton<TransactionType>(
              segments: const <ButtonSegment<TransactionType>>[
                ButtonSegment<TransactionType>(
                  value: TransactionType.expense,
                  label: Text('Expense'),
                ),
                ButtonSegment<TransactionType>(
                  value: TransactionType.income,
                  label: Text('Income'),
                ),
              ],
              selected: <TransactionType>{_type},
              onSelectionChanged: (value) => setState(() {
                _type = value.single;
                _categoryId = null;
              }),
            ),
            const SizedBox(height: PlanItSpacing.md),
            DropdownButtonFormField<String>(
              initialValue: selectedAccount?.id,
              decoration: const InputDecoration(labelText: 'Account'),
              items: activeAccounts
                  .map(
                    (account) => DropdownMenuItem<String>(
                      value: account.id,
                      child: Text('${account.name} · ${account.currency}'),
                    ),
                  )
                  .toList(growable: false),
              onChanged: (value) => setState(() => _accountId = value),
            ),
            const SizedBox(height: PlanItSpacing.md),
            DropdownButtonFormField<String>(
              initialValue: categoryId,
              decoration: const InputDecoration(
                labelText: 'Category (optional)',
              ),
              items: categories
                  .map(
                    (category) => DropdownMenuItem<String>(
                      value: category.id,
                      child: Text(category.name),
                    ),
                  )
                  .toList(growable: false),
              onChanged: (value) => setState(() => _categoryId = value),
            ),
            const SizedBox(height: PlanItSpacing.md),
            TextField(
              controller: _amount,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                labelText:
                    'Amount (${selectedAccount?.currency ?? 'choose account'})',
                helperText: 'Leave empty to enter an amount each time.',
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: PlanItSpacing.md),
            TextField(
              controller: _note,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Note (optional)'),
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
          onPressed: _name.text.trim().isEmpty || selectedAccount == null
              ? null
              : () {
                  Money? amount;
                  final amountText = _amount.text.trim();
                  if (amountText.isNotEmpty) {
                    try {
                      final parsed = Money.parse(
                        amountText,
                        selectedAccount.currency,
                      );
                      if (parsed.scaledAmount <= BigInt.zero) {
                        throw const FormatException('Amount must be positive.');
                      }
                      amount = parsed;
                    } on FormatException {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Enter a valid amount.')),
                      );
                      return;
                    }
                  }
                  Navigator.pop(
                    context,
                    QuickTransactionTemplate(
                      id: widget.initial?.id ?? const Uuid().v4(),
                      name: _name.text.trim(),
                      type: _type,
                      accountId: selectedAccount.id,
                      categoryId: categoryId,
                      amount: amount,
                      counterparty: null,
                      note: _note.text.trim().isEmpty
                          ? null
                          : _note.text.trim(),
                      tagIds: widget.initial?.tagIds ?? const <String>[],
                      updatedAt: DateTime.now().toUtc(),
                    ),
                  );
                },
          child: const Text('Save'),
        ),
      ],
    );
  }
}
