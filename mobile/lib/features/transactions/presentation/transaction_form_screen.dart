import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:planit_mobile/core/design_system/tokens.dart';
import 'package:planit_mobile/core/money/money.dart';
import 'package:planit_mobile/features/accounts/application/providers.dart';
import 'package:planit_mobile/features/accounts/domain/account.dart';
import 'package:planit_mobile/features/transactions/application/providers.dart';
import 'package:planit_mobile/features/transactions/application/transaction_controller.dart';
import 'package:planit_mobile/features/transactions/domain/catalog.dart';
import 'package:planit_mobile/features/transactions/domain/transaction.dart';
import 'package:uuid/uuid.dart';

class TransactionFormScreen extends ConsumerStatefulWidget {
  const TransactionFormScreen({
    this.transactionId,
    this.initialType = TransactionType.expense,
    super.key,
  });

  final String? transactionId;
  final TransactionType initialType;

  @override
  ConsumerState<TransactionFormScreen> createState() =>
      _TransactionFormScreenState();
}

class _TransactionFormScreenState extends ConsumerState<TransactionFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _counterpartyController = TextEditingController();
  final _noteController = TextEditingController();
  late TransactionType _type = widget.initialType;
  String? _accountId;
  String? _categoryId;
  DateTime _occurredAt = DateTime.now().toUtc();
  final Set<String> _tagIds = <String>{};
  bool _initialized = false;
  bool _categoryRequired = false;

  bool get _editing => widget.transactionId != null;

  @override
  void dispose() {
    _amountController.dispose();
    _counterpartyController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  LedgerTransaction? _findTransaction(List<LedgerTransaction> values) {
    for (final value in values) {
      if (value.id == widget.transactionId) {
        return value;
      }
    }
    return null;
  }

  void _initialize(
    LedgerTransaction? transaction,
    List<Account> accounts,
    List<TransactionCategory> categories,
  ) {
    if (_editing && (_initialized || transaction == null)) {
      return;
    }
    if (transaction != null) {
      _initialized = true;
      _type = transaction.type;
      _accountId = transaction.accountId;
      _categoryId = transaction.categoryId;
      _occurredAt = transaction.occurredAt;
      _amountController.text = transaction.amount.toApiString();
      _counterpartyController.text = transaction.counterparty ?? '';
      _noteController.text = transaction.note ?? '';
      _tagIds.addAll(transaction.tagIds);
      return;
    }
    final activeAccounts = accounts
        .where((account) => account.status == AccountStatus.active)
        .toList(growable: false);
    _accountId ??= activeAccounts.firstOrNull?.id;
    _categoryId ??= _matchingCategories(categories).firstOrNull?.id;
  }

  List<TransactionCategory> _matchingCategories(
    List<TransactionCategory> categories,
  ) {
    return categories
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
  }

  Future<void> _pickDate() async {
    final local = _occurredAt.toLocal();
    final selected = await showDatePicker(
      context: context,
      initialDate: local,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (selected == null || !mounted) {
      return;
    }
    setState(() {
      _occurredAt = DateTime(
        selected.year,
        selected.month,
        selected.day,
        local.hour,
        local.minute,
      ).toUtc();
    });
  }

  Future<void> _save({
    required LedgerTransaction? current,
    required List<Account> accounts,
    required List<TransactionCategory> categories,
    required List<TransactionTag> tags,
    required bool post,
  }) async {
    setState(() => _categoryRequired = post);
    if (!_formKey.currentState!.validate()) {
      return;
    }
    final account = accounts.firstWhere((value) => value.id == _accountId);
    final money = Money.parse(_amountController.text.trim(), account.currency);
    final counterparty = _counterpartyController.text.trim();
    final note = _noteController.text.trim();
    final categoryId = categories.any((value) => value.id == _categoryId)
        ? _categoryId
        : null;
    final activeTagIds = tags.map((value) => value.id).toSet();
    final selectedTagIds = _tagIds
        .where(activeTagIds.contains)
        .toList(growable: false);
    final controller = ref.read(transactionControllerProvider.notifier);
    final success = current == null
        ? await controller.create(
            draft: TransactionDraft(
              id: const Uuid().v4(),
              clientOperationId: const Uuid().v4(),
              accountId: account.id,
              type: _type,
              amount: money,
              occurredAt: _occurredAt,
              categoryId: categoryId,
              counterparty: counterparty.isEmpty ? null : counterparty,
              note: note.isEmpty ? null : note,
              tagIds: selectedTagIds,
            ),
            postAfterCreate: post,
            postOperationId: post ? const Uuid().v4() : null,
          )
        : await controller.update(
            current: current,
            edit: TransactionEdit(
              version: current.version,
              accountId: account.id,
              type: _type,
              amount: money,
              occurredAt: _occurredAt,
              categoryId: categoryId,
              counterparty: counterparty.isEmpty ? null : counterparty,
              note: note.isEmpty ? null : note,
              tagIds: selectedTagIds,
            ),
            operationId: const Uuid().v4(),
          );
    if (success && mounted) {
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(ledgerBootstrapProvider);
    final accountsAsync = ref.watch(accountsProvider);
    final categoriesAsync = ref.watch(transactionCategoriesProvider);
    final tagsAsync = ref.watch(transactionTagsProvider);
    final transactionsAsync = ref.watch(transactionsProvider);
    final action = ref.watch(transactionControllerProvider);
    final accounts = accountsAsync.value ?? const <Account>[];
    final categories = categoriesAsync.value ?? const <TransactionCategory>[];
    final tags = tagsAsync.value ?? const <TransactionTag>[];
    final transactions = transactionsAsync.value ?? const <LedgerTransaction>[];
    final current = _findTransaction(transactions);
    _initialize(current, accounts, categories);

    if (_editing && transactionsAsync.isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_editing && current == null) {
      return const Scaffold(
        body: Center(child: Text('This transaction is not available locally.')),
      );
    }
    final activeAccounts = accounts
        .where((account) => account.status == AccountStatus.active)
        .toList(growable: false);
    final matchingCategories = _matchingCategories(categories);
    final activeTags = tags.where((tag) => tag.active).toList(growable: false);
    final canEdit =
        current == null ||
        (current.status == TransactionStatus.draft &&
            current.syncState == LocalTransactionSyncState.synced);

    return Scaffold(
      appBar: AppBar(title: Text(_editing ? 'Edit draft' : 'Add transaction')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            PlanItSpacing.lg,
            PlanItSpacing.md,
            PlanItSpacing.lg,
            PlanItSpacing.xxl,
          ),
          children: <Widget>[
            if (action.errorMessage != null) ...<Widget>[
              _MessageCard(message: action.errorMessage!, error: true),
              const SizedBox(height: PlanItSpacing.md),
            ],
            if (!canEdit) ...<Widget>[
              const _MessageCard(
                message:
                    'This draft has pending synchronization and cannot be edited yet.',
              ),
              const SizedBox(height: PlanItSpacing.md),
            ],
            SegmentedButton<TransactionType>(
              segments: const <ButtonSegment<TransactionType>>[
                ButtonSegment<TransactionType>(
                  value: TransactionType.expense,
                  icon: Icon(Icons.arrow_upward_rounded),
                  label: Text('Expense'),
                ),
                ButtonSegment<TransactionType>(
                  value: TransactionType.income,
                  icon: Icon(Icons.arrow_downward_rounded),
                  label: Text('Income'),
                ),
              ],
              selected: <TransactionType>{_type},
              onSelectionChanged: !canEdit || action.busy
                  ? null
                  : (selection) {
                      setState(() {
                        _type = selection.single;
                        _categoryId = null;
                      });
                    },
            ),
            const SizedBox(height: PlanItSpacing.md),
            DropdownButtonFormField<String>(
              initialValue:
                  activeAccounts.any((value) => value.id == _accountId)
                  ? _accountId
                  : null,
              decoration: const InputDecoration(
                labelText: 'Account',
                prefixIcon: Icon(Icons.account_balance_wallet_outlined),
              ),
              items: activeAccounts
                  .map(
                    (account) => DropdownMenuItem<String>(
                      value: account.id,
                      child: Text('${account.name} · ${account.currency}'),
                    ),
                  )
                  .toList(growable: false),
              onChanged: !canEdit || action.busy
                  ? null
                  : (value) => setState(() => _accountId = value),
              validator: (value) =>
                  value == null ? 'Add or select an account.' : null,
            ),
            const SizedBox(height: PlanItSpacing.md),
            TextFormField(
              controller: _amountController,
              enabled: canEdit && !action.busy,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                labelText: 'Amount',
                prefixIcon: const Icon(Icons.payments_outlined),
                suffixText: activeAccounts
                    .where((value) => value.id == _accountId)
                    .firstOrNull
                    ?.currency,
              ),
              validator: (value) {
                if (_accountId == null) {
                  return null;
                }
                final account = activeAccounts.firstWhere(
                  (item) => item.id == _accountId,
                );
                try {
                  final money = Money.parse(
                    value?.trim() ?? '',
                    account.currency,
                  );
                  return money.scaledAmount > BigInt.zero
                      ? null
                      : 'Amount must be greater than zero.';
                } on FormatException {
                  return 'Use a positive amount with up to 4 decimals.';
                }
              },
            ),
            const SizedBox(height: PlanItSpacing.md),
            DropdownButtonFormField<String>(
              key: ValueKey<String>('category-${_type.apiValue}-$_categoryId'),
              initialValue:
                  matchingCategories.any((value) => value.id == _categoryId)
                  ? _categoryId
                  : null,
              decoration: const InputDecoration(
                labelText: 'Category',
                prefixIcon: Icon(Icons.category_outlined),
              ),
              items: matchingCategories
                  .map(
                    (category) => DropdownMenuItem<String>(
                      value: category.id,
                      child: Text(category.name),
                    ),
                  )
                  .toList(growable: false),
              onChanged: !canEdit || action.busy
                  ? null
                  : (value) => setState(() => _categoryId = value),
              validator: (value) => _categoryRequired && value == null
                  ? 'Choose a category before posting.'
                  : null,
            ),
            const SizedBox(height: PlanItSpacing.md),
            TextFormField(
              controller: _counterpartyController,
              enabled: canEdit && !action.busy,
              maxLength: 160,
              decoration: InputDecoration(
                labelText: _type == TransactionType.expense
                    ? 'Merchant (optional)'
                    : 'Source (optional)',
                prefixIcon: const Icon(Icons.storefront_outlined),
              ),
            ),
            const SizedBox(height: PlanItSpacing.sm),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.event_outlined),
              title: const Text('Date'),
              subtitle: Text(_formatDate(_occurredAt)),
              trailing: const Icon(Icons.edit_calendar_outlined),
              onTap: canEdit && !action.busy ? _pickDate : null,
            ),
            const SizedBox(height: PlanItSpacing.sm),
            TextFormField(
              controller: _noteController,
              enabled: canEdit && !action.busy,
              maxLength: 2000,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Note (optional)',
                alignLabelWithHint: true,
              ),
            ),
            if (activeTags.isNotEmpty) ...<Widget>[
              const SizedBox(height: PlanItSpacing.sm),
              Text('Tags', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: PlanItSpacing.xs),
              Wrap(
                spacing: PlanItSpacing.xs,
                runSpacing: PlanItSpacing.xs,
                children: activeTags
                    .map(
                      (tag) => FilterChip(
                        label: Text(tag.name),
                        selected: _tagIds.contains(tag.id),
                        onSelected: !canEdit || action.busy
                            ? null
                            : (selected) {
                                setState(() {
                                  selected
                                      ? _tagIds.add(tag.id)
                                      : _tagIds.remove(tag.id);
                                });
                              },
                      ),
                    )
                    .toList(growable: false),
              ),
            ],
            const SizedBox(height: PlanItSpacing.lg),
            if (canEdit)
              OutlinedButton(
                onPressed: action.busy
                    ? null
                    : () => _save(
                        current: current,
                        accounts: activeAccounts,
                        categories: matchingCategories,
                        tags: activeTags,
                        post: false,
                      ),
                child: const Text('Save draft'),
              ),
            if (canEdit && current == null) ...<Widget>[
              const SizedBox(height: PlanItSpacing.sm),
              FilledButton.icon(
                onPressed: action.busy
                    ? null
                    : () => _save(
                        current: null,
                        accounts: activeAccounts,
                        categories: matchingCategories,
                        tags: activeTags,
                        post: true,
                      ),
                icon: const Icon(Icons.check_circle_outline),
                label: const Text('Save & post'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  static String _formatDate(DateTime value) {
    final local = value.toLocal();
    return '${local.year.toString().padLeft(4, '0')}-'
        '${local.month.toString().padLeft(2, '0')}-'
        '${local.day.toString().padLeft(2, '0')}';
  }
}

class _MessageCard extends StatelessWidget {
  const _MessageCard({required this.message, this.error = false});

  final String message;
  final bool error;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: error ? scheme.errorContainer : scheme.secondaryContainer,
        borderRadius: BorderRadius.circular(PlanItRadius.sm),
      ),
      child: Padding(
        padding: const EdgeInsets.all(PlanItSpacing.sm),
        child: Text(
          message,
          style: TextStyle(
            color: error
                ? scheme.onErrorContainer
                : scheme.onSecondaryContainer,
          ),
        ),
      ),
    );
  }
}
