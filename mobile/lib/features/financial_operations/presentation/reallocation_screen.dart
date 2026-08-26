import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:planit_mobile/core/auth/application/auth_controller.dart';
import 'package:planit_mobile/core/design_system/tokens.dart';
import 'package:planit_mobile/core/money/money.dart';
import 'package:planit_mobile/core/money/money_format.dart';
import 'package:planit_mobile/features/accounts/application/providers.dart';
import 'package:planit_mobile/features/accounts/domain/account.dart';
import 'package:planit_mobile/features/financial_operations/application/financial_operation_controller.dart';
import 'package:planit_mobile/features/financial_operations/domain/financial_operation.dart';

class ReallocationScreen extends ConsumerStatefulWidget {
  const ReallocationScreen({super.key});

  @override
  ConsumerState<ReallocationScreen> createState() => _ReallocationScreenState();
}

class _ReallocationScreenState extends ConsumerState<ReallocationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _targetControllers = <String, TextEditingController>{};
  final _noteController = TextEditingController();
  final _selectedIds = <String>{};
  String? _currency;
  String? _balancingAccountId;
  DateTime _occurredAt = DateTime.now().toUtc();
  ReallocationPreviewRequest? _previewedRequest;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(financialOperationControllerProvider.notifier).reset();
    });
  }

  @override
  void dispose() {
    for (final controller in _targetControllers.values) {
      controller.dispose();
    }
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final active = (ref.watch(accountsProvider).value ?? const <Account>[])
        .where((account) => account.status == AccountStatus.active)
        .toList(growable: false);
    final currencies =
        active.map((account) => account.currency).toSet().toList()..sort();
    _initialize(active, currencies);
    final currencyAccounts = active
        .where((account) => account.currency == _currency)
        .toList(growable: false);
    final selected = currencyAccounts
        .where((account) => _selectedIds.contains(account.id))
        .toList(growable: false);
    final fixedTotal = _sumBalances(selected, _currency);
    final action = ref.watch(financialOperationControllerProvider);
    final preview = action.reallocationPreview;
    final offline = ref.watch(authControllerProvider).offline;
    final hasChanges =
        preview?.lines.any((line) => line.delta.scaledAmount != BigInt.zero) ??
        false;

    return Scaffold(
      appBar: AppBar(title: const Text('Keep Total Fixed')),
      body: active.length < 2
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(PlanItSpacing.xl),
                child: Text(
                  'Add at least two active accounts before reallocating balances.',
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  PlanItSpacing.lg,
                  PlanItSpacing.md,
                  PlanItSpacing.lg,
                  PlanItSpacing.xxl,
                ),
                children: <Widget>[
                  const _ReallocationInfo(
                    message:
                        'Set target balances while the selected total stays unchanged. The server derives the balancing account and commits linked internal transfers atomically.',
                  ),
                  if (offline) ...<Widget>[
                    const SizedBox(height: PlanItSpacing.sm),
                    const _ReallocationInfo(
                      message:
                          'Connect to obtain a fresh server preview. Cached balances are never changed speculatively.',
                    ),
                  ],
                  if (action.errorMessage != null) ...<Widget>[
                    const SizedBox(height: PlanItSpacing.sm),
                    _ReallocationInfo(
                      message: action.errorMessage!,
                      error: true,
                    ),
                  ],
                  const SizedBox(height: PlanItSpacing.lg),
                  DropdownButtonFormField<String>(
                    initialValue: _currency,
                    decoration: const InputDecoration(
                      labelText: 'Currency group',
                      prefixIcon: Icon(Icons.currency_exchange),
                    ),
                    items: currencies
                        .map(
                          (value) => DropdownMenuItem<String>(
                            value: value,
                            child: Text(value),
                          ),
                        )
                        .toList(growable: false),
                    onChanged: action.busy
                        ? null
                        : (value) => _selectCurrency(active, value),
                  ),
                  const SizedBox(height: PlanItSpacing.md),
                  Text(
                    'Participating accounts',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: PlanItSpacing.xs),
                  for (final account in currencyAccounts)
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      value: _selectedIds.contains(account.id),
                      title: Text(account.name),
                      subtitle: Text(
                        account.calculatedBalance.toDisplayString(),
                      ),
                      onChanged: action.busy
                          ? null
                          : (value) => _toggleAccount(account, value ?? false),
                    ),
                  if (selected.length < 2)
                    Text(
                      'Select at least two same-currency accounts.',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  const SizedBox(height: PlanItSpacing.md),
                  DropdownButtonFormField<String>(
                    key: ValueKey<String?>(_balancingAccountId),
                    initialValue:
                        selected.any(
                          (account) => account.id == _balancingAccountId,
                        )
                        ? _balancingAccountId
                        : null,
                    decoration: const InputDecoration(
                      labelText: 'Balancing account',
                      helperText:
                          'Its target is derived from the remaining total.',
                      prefixIcon: Icon(Icons.balance_rounded),
                    ),
                    items: selected
                        .map(
                          (account) => DropdownMenuItem<String>(
                            value: account.id,
                            child: Text(account.name),
                          ),
                        )
                        .toList(growable: false),
                    onChanged: action.busy
                        ? null
                        : (value) => setState(() {
                            _balancingAccountId = value;
                            _invalidatePreview();
                          }),
                    validator: (value) => selected.length >= 2 && value == null
                        ? 'Choose the balancing account.'
                        : null,
                  ),
                  const SizedBox(height: PlanItSpacing.lg),
                  if (fixedTotal != null)
                    Card(
                      child: ListTile(
                        leading: const CircleAvatar(
                          child: Icon(Icons.lock_outline_rounded),
                        ),
                        title: const Text('Fixed total'),
                        subtitle: const Text('Captured from cached balances'),
                        trailing: Text(
                          fixedTotal.toDisplayString(),
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                    ),
                  const SizedBox(height: PlanItSpacing.md),
                  Text(
                    'Target balances',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: PlanItSpacing.sm),
                  for (final account in selected) ...<Widget>[
                    if (account.id == _balancingAccountId)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.auto_fix_high_outlined),
                        title: Text(account.name),
                        subtitle: const Text('Derived by the server'),
                      )
                    else
                      TextFormField(
                        controller: _controllerFor(account),
                        enabled: !action.busy,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                          signed: true,
                        ),
                        decoration: InputDecoration(
                          labelText: '${account.name} target',
                          suffixText: account.currency,
                        ),
                        onChanged: (_) => _invalidatePreview(),
                        validator: (value) {
                          try {
                            final target = Money.parse(
                              value?.trim() ?? '',
                              account.currency,
                            );
                            if (target.scaledAmount.isNegative &&
                                !account.allowNegative) {
                              return 'This account cannot be negative.';
                            }
                            return null;
                          } on FormatException {
                            return 'Use an amount with up to 4 decimals.';
                          }
                        },
                      ),
                    const SizedBox(height: PlanItSpacing.sm),
                  ],
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.event_outlined),
                    title: const Text('Reallocation date'),
                    subtitle: Text(_formatDate(_occurredAt)),
                    trailing: const Icon(Icons.edit_calendar_outlined),
                    onTap: action.busy ? null : _pickDate,
                  ),
                  const SizedBox(height: PlanItSpacing.sm),
                  TextFormField(
                    controller: _noteController,
                    enabled: !action.busy,
                    maxLength: 2000,
                    minLines: 2,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: 'Note (optional)',
                      alignLabelWithHint: true,
                    ),
                  ),
                  if (preview != null) ...<Widget>[
                    const SizedBox(height: PlanItSpacing.md),
                    _ReallocationPreviewCard(
                      preview: preview,
                      accounts: selected,
                    ),
                  ],
                  const SizedBox(height: PlanItSpacing.md),
                  OutlinedButton.icon(
                    onPressed:
                        action.busy ||
                            offline ||
                            selected.length < 2 ||
                            fixedTotal == null
                        ? null
                        : () => _preview(selected, fixedTotal),
                    icon: action.busy
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.fact_check_outlined),
                    label: const Text('Preview residual & transfers'),
                  ),
                  const SizedBox(height: PlanItSpacing.sm),
                  FilledButton.icon(
                    onPressed:
                        action.busy ||
                            preview == null ||
                            !hasChanges ||
                            _previewedRequest == null
                        ? null
                        : _commit,
                    icon: const Icon(Icons.balance_rounded),
                    label: Text(
                      preview != null && !hasChanges
                          ? 'No balance changes'
                          : 'Confirm fixed-total reallocation',
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  void _initialize(List<Account> accounts, List<String> currencies) {
    if (_currency != null || currencies.isEmpty) {
      return;
    }
    _currency = currencies.first;
    final matching = accounts
        .where((account) => account.currency == _currency)
        .take(50)
        .toList(growable: false);
    _selectedIds.addAll(matching.map((account) => account.id));
    _balancingAccountId = matching.lastOrNull?.id;
    for (final account in matching) {
      _controllerFor(account);
    }
  }

  void _selectCurrency(List<Account> accounts, String? currency) {
    if (currency == null) {
      return;
    }
    final matching = accounts
        .where((account) => account.currency == currency)
        .take(50)
        .toList(growable: false);
    setState(() {
      _currency = currency;
      _selectedIds
        ..clear()
        ..addAll(matching.map((account) => account.id));
      _balancingAccountId = matching.lastOrNull?.id;
      for (final account in matching) {
        _controllerFor(account).text = account.calculatedBalance.toApiString();
      }
      _invalidatePreview();
    });
  }

  void _toggleAccount(Account account, bool selected) {
    if (selected && _selectedIds.length >= 50) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('A reallocation supports up to 50 accounts.'),
        ),
      );
      return;
    }
    setState(() {
      if (selected) {
        _selectedIds.add(account.id);
        _controllerFor(account).text = account.calculatedBalance.toApiString();
        _balancingAccountId ??= account.id;
      } else {
        _selectedIds.remove(account.id);
        if (_balancingAccountId == account.id) {
          _balancingAccountId = _selectedIds.lastOrNull;
        }
      }
      _invalidatePreview();
    });
  }

  TextEditingController _controllerFor(Account account) {
    return _targetControllers.putIfAbsent(
      account.id,
      () =>
          TextEditingController(text: account.calculatedBalance.toApiString()),
    );
  }

  Future<void> _preview(List<Account> selected, Money fixedTotal) async {
    if (!_formKey.currentState!.validate() ||
        _balancingAccountId == null ||
        selected.length < 2) {
      return;
    }
    final request = ReallocationPreviewRequest(
      accountIds: selected.map((account) => account.id).toList(growable: false),
      fixedTotal: fixedTotal,
      balancingAccountId: _balancingAccountId!,
      requestedBalances: <String, Money>{
        for (final account in selected)
          if (account.id != _balancingAccountId)
            account.id: Money.parse(
              _controllerFor(account).text.trim(),
              account.currency,
            ),
      },
      occurredAt: _occurredAt,
    );
    final success = await ref
        .read(financialOperationControllerProvider.notifier)
        .previewReallocation(request);
    if (success && mounted) {
      setState(() => _previewedRequest = request);
    }
  }

  Future<void> _commit() async {
    final request = _previewedRequest;
    if (request == null) {
      return;
    }
    final success = await ref
        .read(financialOperationControllerProvider.notifier)
        .queueReallocation(request: request, note: _noteController.text);
    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Reallocation queued. The selected total remains server-controlled.',
          ),
        ),
      );
      Navigator.of(context).pop();
    }
  }

  Future<void> _pickDate() async {
    final current = _occurredAt.toLocal();
    final selected = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (selected == null || !mounted) {
      return;
    }
    final now = DateTime.now();
    setState(() {
      _occurredAt = DateTime(
        selected.year,
        selected.month,
        selected.day,
        now.hour,
        now.minute,
      ).toUtc();
      _invalidatePreview();
    });
  }

  void _invalidatePreview() {
    _previewedRequest = null;
    ref.read(financialOperationControllerProvider.notifier).invalidatePreview();
  }

  static Money? _sumBalances(List<Account> accounts, String? currency) {
    if (currency == null || accounts.isEmpty) {
      return null;
    }
    try {
      var total = Money.zero(currency);
      for (final account in accounts) {
        total += account.calculatedBalance;
      }
      return total;
    } on RangeError {
      return null;
    }
  }

  static String _formatDate(DateTime value) {
    final local = value.toLocal();
    return '${local.year}-${local.month.toString().padLeft(2, '0')}-'
        '${local.day.toString().padLeft(2, '0')}';
  }
}

class _ReallocationPreviewCard extends StatelessWidget {
  const _ReallocationPreviewCard({
    required this.preview,
    required this.accounts,
  });

  final ReallocationPreview preview;
  final List<Account> accounts;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Theme.of(context).colorScheme.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(PlanItSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Authoritative preview',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: PlanItSpacing.xs),
            for (final line in preview.lines)
              Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: PlanItSpacing.xxs,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      _nameFor(line.accountId),
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    Text(
                      '${line.beforeBalance.toDisplayString()} → ${line.requestedBalance.toDisplayString()}  (${line.delta.toDisplayString()})',
                    ),
                  ],
                ),
              ),
            const Divider(),
            Text('Fixed total: ${preview.fixedTotal.toDisplayString()}'),
          ],
        ),
      ),
    );
  }

  String _nameFor(String id) {
    return accounts.where((account) => account.id == id).firstOrNull?.name ??
        'Account';
  }
}

class _ReallocationInfo extends StatelessWidget {
  const _ReallocationInfo({required this.message, this.error = false});

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
        child: Row(
          children: <Widget>[
            Icon(error ? Icons.error_outline : Icons.info_outline),
            const SizedBox(width: PlanItSpacing.sm),
            Expanded(child: Text(message)),
          ],
        ),
      ),
    );
  }
}
