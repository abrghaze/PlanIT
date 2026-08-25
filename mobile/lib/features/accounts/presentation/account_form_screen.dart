import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:planit_mobile/core/auth/application/auth_controller.dart';
import 'package:planit_mobile/core/design_system/tokens.dart';
import 'package:planit_mobile/core/money/money.dart';
import 'package:planit_mobile/features/accounts/application/account_controller.dart';
import 'package:planit_mobile/features/accounts/application/providers.dart';
import 'package:planit_mobile/features/accounts/domain/account.dart';
import 'package:uuid/uuid.dart';

class AccountFormScreen extends ConsumerStatefulWidget {
  const AccountFormScreen({this.accountId, super.key});

  final String? accountId;

  @override
  ConsumerState<AccountFormScreen> createState() => _AccountFormScreenState();
}

class _AccountFormScreenState extends ConsumerState<AccountFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _amountController = TextEditingController(text: '0');
  final _currencyController = TextEditingController();
  AccountType _type = AccountType.bank;
  bool _includeInTotal = true;
  bool _allowNegative = false;
  bool _initialized = false;

  bool get _editing => widget.accountId != null;

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    _currencyController.dispose();
    super.dispose();
  }

  Account? _findAccount(List<Account> accounts) {
    for (final account in accounts) {
      if (account.id == widget.accountId) {
        return account;
      }
    }
    return null;
  }

  void _initialize(Account? account, String baseCurrency) {
    if (_initialized) {
      return;
    }
    _initialized = true;
    if (account == null) {
      _currencyController.text = baseCurrency;
      return;
    }
    _nameController.text = account.name;
    _amountController.text = account.openingBalance.toApiString();
    _currencyController.text = account.currency;
    _type = account.type;
    _includeInTotal = account.includeInTotal;
    _allowNegative = account.allowNegative;
  }

  Future<void> _save(Account? account) async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    FocusScope.of(context).unfocus();
    final money = Money.parse(
      _amountController.text.trim(),
      _currencyController.text.trim().toUpperCase(),
    );
    final controller = ref.read(accountControllerProvider.notifier);
    final success = account == null
        ? await controller.create(
            draft: AccountDraft(
              id: const Uuid().v4(),
              name: _nameController.text.trim(),
              type: _type,
              openingBalance: money,
              openedAt: DateTime.now().toUtc(),
              includeInTotal: _includeInTotal,
              allowNegative: _allowNegative,
              sortOrder: 0,
            ),
            idempotencyKey: const Uuid().v4(),
          )
        : await controller.update(
            accountId: account.id,
            patch: AccountPatch(
              version: account.version,
              name: _nameController.text.trim(),
              type: _type,
              openingBalance: money,
              openedAt: account.openedAt,
              includeInTotal: _includeInTotal,
              allowNegative: _allowNegative,
              sortOrder: account.sortOrder,
            ),
          );
    if (success && mounted) {
      context.pop();
    }
  }

  Future<void> _changeStatus(Account account, AccountStatus status) async {
    final verb = switch (status) {
      AccountStatus.active => 'restore',
      AccountStatus.archived => 'archive',
      AccountStatus.closed => 'close',
    };
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${verb[0].toUpperCase()}${verb.substring(1)} account?'),
        content: Text(
          status == AccountStatus.closed
              ? 'History stays available, but new financial postings will be blocked.'
              : status == AccountStatus.archived
              ? 'The account becomes read-only and moves out of the active list.'
              : 'The account becomes active and editable again.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(verb),
          ),
        ],
      ),
    );
    if (confirmed != true) {
      return;
    }
    final success = await ref
        .read(accountControllerProvider.notifier)
        .update(
          accountId: account.id,
          patch: AccountPatch(version: account.version, status: status),
        );
    if (success && mounted) {
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final accounts = ref.watch(accountsProvider);
    final action = ref.watch(accountControllerProvider);
    final baseCurrency = ref.watch(
      authControllerProvider.select(
        (state) => state.session?.user.baseCurrency ?? 'MAD',
      ),
    );
    final account = accounts.value == null
        ? null
        : _findAccount(accounts.value!);
    _initialize(account, baseCurrency);

    if (_editing && accounts.isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_editing && account == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Account')),
        body: const Center(
          child: Text('This account is not available in the local cache.'),
        ),
      );
    }

    final editable = account == null || account.status == AccountStatus.active;
    return Scaffold(
      appBar: AppBar(
        title: Text(account == null ? 'Add account' : 'Account settings'),
      ),
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
              _FormError(message: action.errorMessage!),
              const SizedBox(height: PlanItSpacing.md),
            ],
            TextFormField(
              controller: _nameController,
              enabled: editable && !action.busy,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Account name',
                prefixIcon: Icon(Icons.account_balance_wallet_outlined),
              ),
              validator: (value) => (value?.trim().isNotEmpty ?? false)
                  ? null
                  : 'Enter an account name.',
            ),
            const SizedBox(height: PlanItSpacing.md),
            DropdownButtonFormField<AccountType>(
              initialValue: _type,
              decoration: const InputDecoration(labelText: 'Account type'),
              items: AccountType.values
                  .map(
                    (type) => DropdownMenuItem<AccountType>(
                      value: type,
                      child: Text(type.label),
                    ),
                  )
                  .toList(),
              onChanged: editable && !action.busy
                  ? (value) => setState(() => _type = value ?? _type)
                  : null,
            ),
            const SizedBox(height: PlanItSpacing.md),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    controller: _amountController,
                    enabled: editable && !action.busy,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                      signed: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Opening balance',
                    ),
                    validator: (value) {
                      final amount = value?.trim() ?? '';
                      if (!RegExp(r'^-?\d+(?:\.\d{1,4})?$').hasMatch(amount)) {
                        return 'Use up to 4 decimals.';
                      }
                      final currency = _currencyController.text
                          .trim()
                          .toUpperCase();
                      if (!RegExp(r'^[A-Z]{3}$').hasMatch(currency)) {
                        return null;
                      }
                      try {
                        Money.parse(amount, currency);
                      } on FormatException {
                        return 'Amount is outside the supported range.';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: PlanItSpacing.sm),
                Expanded(
                  child: TextFormField(
                    controller: _currencyController,
                    enabled: editable && !action.busy,
                    textCapitalization: TextCapitalization.characters,
                    maxLength: 3,
                    decoration: const InputDecoration(
                      labelText: 'Currency',
                      counterText: '',
                    ),
                    validator: (value) =>
                        RegExp(r'^[A-Za-z]{3}$').hasMatch(value?.trim() ?? '')
                        ? null
                        : 'Use 3 letters.',
                  ),
                ),
              ],
            ),
            const SizedBox(height: PlanItSpacing.md),
            Card(
              child: Column(
                children: <Widget>[
                  SwitchListTile(
                    value: _includeInTotal,
                    onChanged: editable && !action.busy
                        ? (value) => setState(() => _includeInTotal = value)
                        : null,
                    title: const Text('Include in headline total'),
                    subtitle: const Text(
                      'History remains available either way.',
                    ),
                  ),
                  const Divider(height: 1),
                  SwitchListTile(
                    value: _allowNegative,
                    onChanged: editable && !action.busy
                        ? (value) => setState(() => _allowNegative = value)
                        : null,
                    title: const Text('Allow a negative balance'),
                    subtitle: const Text(
                      'Useful for credit or overdraft accounts.',
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: PlanItSpacing.lg),
            if (editable)
              FilledButton(
                onPressed: action.busy ? null : () => _save(account),
                child: action.busy
                    ? const SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(account == null ? 'Add account' : 'Save changes'),
              ),
            if (account != null) ...<Widget>[
              const SizedBox(height: PlanItSpacing.lg),
              Text(
                'Lifecycle',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: PlanItSpacing.sm),
              if (account.status == AccountStatus.active) ...<Widget>[
                OutlinedButton.icon(
                  onPressed: action.busy
                      ? null
                      : () => _changeStatus(account, AccountStatus.archived),
                  icon: const Icon(Icons.archive_outlined),
                  label: const Text('Archive account'),
                ),
                const SizedBox(height: PlanItSpacing.xs),
                OutlinedButton.icon(
                  onPressed: action.busy
                      ? null
                      : () => _changeStatus(account, AccountStatus.closed),
                  icon: const Icon(Icons.lock_outline_rounded),
                  label: const Text('Close account'),
                ),
              ] else
                FilledButton.tonalIcon(
                  onPressed: action.busy
                      ? null
                      : () => _changeStatus(account, AccountStatus.active),
                  icon: const Icon(Icons.restore_rounded),
                  label: Text(
                    account.status == AccountStatus.closed
                        ? 'Reopen account'
                        : 'Restore account',
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _FormError extends StatelessWidget {
  const _FormError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(PlanItRadius.sm),
      ),
      child: Padding(
        padding: const EdgeInsets.all(PlanItSpacing.sm),
        child: Text(
          message,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onErrorContainer,
          ),
        ),
      ),
    );
  }
}
