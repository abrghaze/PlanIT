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

class TransferScreen extends ConsumerStatefulWidget {
  const TransferScreen({super.key});

  @override
  ConsumerState<TransferScreen> createState() => _TransferScreenState();
}

class _TransferScreenState extends ConsumerState<TransferScreen> {
  final _formKey = GlobalKey<FormState>();
  final _sourceAmountController = TextEditingController();
  final _destinationAmountController = TextEditingController();
  final _fxRateController = TextEditingController();
  final _feeAmountController = TextEditingController();
  final _noteController = TextEditingController();
  String? _sourceAccountId;
  String? _destinationAccountId;
  String? _feeAccountId;
  bool _includeFee = false;
  DateTime _occurredAt = DateTime.now().toUtc();
  TransferPreviewRequest? _previewedRequest;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(financialOperationControllerProvider.notifier).reset();
    });
  }

  @override
  void dispose() {
    _sourceAmountController.dispose();
    _destinationAmountController.dispose();
    _fxRateController.dispose();
    _feeAmountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accounts = ref.watch(accountsProvider).value ?? const <Account>[];
    final active = accounts
        .where((account) => account.status == AccountStatus.active)
        .toList(growable: false);
    _initializeAccounts(active);
    final source = _account(active, _sourceAccountId);
    final destination = _account(active, _destinationAccountId);
    final sameCurrency =
        source != null &&
        destination != null &&
        source.currency == destination.currency;
    final action = ref.watch(financialOperationControllerProvider);
    final offline = ref.watch(authControllerProvider).offline;

    return Scaffold(
      appBar: AppBar(title: const Text('Transfer money')),
      body: active.length < 2
          ? const _TransferUnavailable()
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
                  const _InfoCard(
                    icon: Icons.shield_outlined,
                    message:
                        'A transfer posts one linked outflow and inflow atomically. It is neutral to income and spending; an optional fee is separate spending.',
                  ),
                  if (offline) ...<Widget>[
                    const SizedBox(height: PlanItSpacing.sm),
                    const _InfoCard(
                      icon: Icons.cloud_off_outlined,
                      message:
                          'A server preview is required. Existing queued work remains safe while offline.',
                    ),
                  ],
                  if (action.errorMessage != null) ...<Widget>[
                    const SizedBox(height: PlanItSpacing.sm),
                    _InfoCard(
                      icon: Icons.error_outline,
                      message: action.errorMessage!,
                      error: true,
                    ),
                  ],
                  const SizedBox(height: PlanItSpacing.lg),
                  DropdownButtonFormField<String>(
                    initialValue: _sourceAccountId,
                    decoration: const InputDecoration(
                      labelText: 'From account',
                      prefixIcon: Icon(Icons.arrow_upward_rounded),
                    ),
                    items: active
                        .map(
                          (account) => DropdownMenuItem<String>(
                            value: account.id,
                            child: Text(
                              '${account.name} · ${account.currency}',
                            ),
                          ),
                        )
                        .toList(growable: false),
                    onChanged: action.busy
                        ? null
                        : (value) {
                            setState(() {
                              _sourceAccountId = value;
                              if (_destinationAccountId == value) {
                                _destinationAccountId = active
                                    .where((item) => item.id != value)
                                    .firstOrNull
                                    ?.id;
                              }
                              _feeAccountId ??= value;
                              _invalidatePreview();
                            });
                          },
                  ),
                  const SizedBox(height: PlanItSpacing.md),
                  DropdownButtonFormField<String>(
                    key: ValueKey<String?>(_destinationAccountId),
                    initialValue: _destinationAccountId,
                    decoration: const InputDecoration(
                      labelText: 'To account',
                      prefixIcon: Icon(Icons.arrow_downward_rounded),
                    ),
                    items: active
                        .where((account) => account.id != _sourceAccountId)
                        .map(
                          (account) => DropdownMenuItem<String>(
                            value: account.id,
                            child: Text(
                              '${account.name} · ${account.currency}',
                            ),
                          ),
                        )
                        .toList(growable: false),
                    onChanged: action.busy
                        ? null
                        : (value) => setState(() {
                            _destinationAccountId = value;
                            _invalidatePreview();
                          }),
                  ),
                  const SizedBox(height: PlanItSpacing.md),
                  TextFormField(
                    controller: _sourceAmountController,
                    enabled: !action.busy,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      labelText: 'Amount sent',
                      prefixIcon: const Icon(Icons.payments_outlined),
                      suffixText: source?.currency,
                    ),
                    onChanged: (_) => _invalidatePreview(),
                    validator: (value) =>
                        _validatePositiveMoney(value, source?.currency),
                  ),
                  if (!sameCurrency) ...<Widget>[
                    const SizedBox(height: PlanItSpacing.md),
                    TextFormField(
                      controller: _destinationAmountController,
                      enabled: !action.busy,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: InputDecoration(
                        labelText: 'Amount received',
                        prefixIcon: const Icon(Icons.currency_exchange),
                        suffixText: destination?.currency,
                      ),
                      onChanged: (_) => _invalidatePreview(),
                      validator: (value) =>
                          _validatePositiveMoney(value, destination?.currency),
                    ),
                    const SizedBox(height: PlanItSpacing.md),
                    TextFormField(
                      controller: _fxRateController,
                      enabled: !action.busy,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: InputDecoration(
                        labelText: 'FX rate',
                        helperText: source == null || destination == null
                            ? null
                            : '1 ${source.currency} = rate × ${destination.currency}',
                        prefixIcon: const Icon(Icons.calculate_outlined),
                      ),
                      onChanged: (_) => _invalidatePreview(),
                      validator: _validateFxRate,
                    ),
                  ],
                  const SizedBox(height: PlanItSpacing.sm),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Include a transfer fee'),
                    subtitle: const Text(
                      'The fee is posted separately and counts as spending.',
                    ),
                    value: _includeFee,
                    onChanged: action.busy
                        ? null
                        : (value) => setState(() {
                            _includeFee = value;
                            _feeAccountId ??= _sourceAccountId;
                            _invalidatePreview();
                          }),
                  ),
                  if (_includeFee) ...<Widget>[
                    DropdownButtonFormField<String>(
                      initialValue: _feeAccountId,
                      decoration: const InputDecoration(
                        labelText: 'Fee account',
                        prefixIcon: Icon(Icons.account_balance_wallet_outlined),
                      ),
                      items: active
                          .map(
                            (account) => DropdownMenuItem<String>(
                              value: account.id,
                              child: Text(
                                '${account.name} · ${account.currency}',
                              ),
                            ),
                          )
                          .toList(growable: false),
                      onChanged: action.busy
                          ? null
                          : (value) => setState(() {
                              _feeAccountId = value;
                              _invalidatePreview();
                            }),
                    ),
                    const SizedBox(height: PlanItSpacing.md),
                    TextFormField(
                      controller: _feeAmountController,
                      enabled: !action.busy,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: InputDecoration(
                        labelText: 'Fee amount',
                        prefixIcon: const Icon(Icons.receipt_long_outlined),
                        suffixText: _account(active, _feeAccountId)?.currency,
                      ),
                      onChanged: (_) => _invalidatePreview(),
                      validator: (value) => _includeFee
                          ? _validatePositiveMoney(
                              value,
                              _account(active, _feeAccountId)?.currency,
                            )
                          : null,
                    ),
                  ],
                  const SizedBox(height: PlanItSpacing.sm),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.event_outlined),
                    title: const Text('Transfer date'),
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
                  const SizedBox(height: PlanItSpacing.md),
                  if (action.transferPreview case final preview?) ...<Widget>[
                    _TransferPreviewCard(preview: preview, accounts: active),
                    const SizedBox(height: PlanItSpacing.md),
                  ],
                  OutlinedButton.icon(
                    onPressed: action.busy || offline
                        ? null
                        : () => _preview(active),
                    icon: action.busy
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.fact_check_outlined),
                    label: const Text('Preview balance impact'),
                  ),
                  const SizedBox(height: PlanItSpacing.sm),
                  FilledButton.icon(
                    onPressed:
                        action.busy ||
                            action.transferPreview == null ||
                            _previewedRequest == null
                        ? null
                        : _commit,
                    icon: const Icon(Icons.swap_horiz_rounded),
                    label: const Text('Confirm transfer'),
                  ),
                ],
              ),
            ),
    );
  }

  void _initializeAccounts(List<Account> accounts) {
    if (accounts.length < 2) {
      return;
    }
    _sourceAccountId ??= accounts.first.id;
    _destinationAccountId ??= accounts
        .where((account) => account.id != _sourceAccountId)
        .first
        .id;
    _feeAccountId ??= _sourceAccountId;
  }

  Future<void> _preview(List<Account> accounts) async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    final request = _buildRequest(accounts);
    if (request == null) {
      return;
    }
    final success = await ref
        .read(financialOperationControllerProvider.notifier)
        .previewTransfer(request);
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
        .queueTransfer(request: request, note: _noteController.text);
    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Transfer queued. Balances update after server acknowledgment.',
          ),
        ),
      );
      Navigator.of(context).pop();
    }
  }

  TransferPreviewRequest? _buildRequest(List<Account> accounts) {
    final source = _account(accounts, _sourceAccountId);
    final destination = _account(accounts, _destinationAccountId);
    if (source == null || destination == null) {
      return null;
    }
    final sameCurrency = source.currency == destination.currency;
    final feeAccount = _includeFee ? _account(accounts, _feeAccountId) : null;
    if (_includeFee && feeAccount == null) {
      return null;
    }
    return TransferPreviewRequest(
      sourceAccountId: source.id,
      destinationAccountId: destination.id,
      sourceAmount: Money.parse(
        _sourceAmountController.text.trim(),
        source.currency,
      ),
      destinationAmount: sameCurrency
          ? null
          : Money.parse(
              _destinationAmountController.text.trim(),
              destination.currency,
            ),
      fxRate: sameCurrency ? null : _fxRateController.text.trim(),
      fee: feeAccount == null
          ? null
          : TransferFeeInput(
              accountId: feeAccount.id,
              amount: Money.parse(
                _feeAmountController.text.trim(),
                feeAccount.currency,
              ),
            ),
      occurredAt: _occurredAt,
    );
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

  static Account? _account(List<Account> values, String? id) {
    return values.where((value) => value.id == id).firstOrNull;
  }

  static String? _validatePositiveMoney(String? value, String? currency) {
    if (currency == null) {
      return 'Select an account first.';
    }
    try {
      return Money.parse(value?.trim() ?? '', currency).scaledAmount >
              BigInt.zero
          ? null
          : 'Amount must be greater than zero.';
    } on FormatException {
      return 'Use a positive amount with up to 4 decimals.';
    }
  }

  static String? _validateFxRate(String? value) {
    final normalized = value?.trim() ?? '';
    if (!RegExp(r'^\d+(?:\.\d{1,12})?$').hasMatch(normalized)) {
      return 'Use a positive decimal with up to 12 places.';
    }
    final significant = normalized.replaceAll('.', '').replaceAll('0', '');
    return significant.isEmpty ? 'FX rate must be greater than zero.' : null;
  }

  static String _formatDate(DateTime value) {
    final local = value.toLocal();
    return '${local.year}-${local.month.toString().padLeft(2, '0')}-'
        '${local.day.toString().padLeft(2, '0')}';
  }
}

class _TransferPreviewCard extends StatelessWidget {
  const _TransferPreviewCard({required this.preview, required this.accounts});

  final TransferPreview preview;
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
            for (final impact in preview.impacts)
              Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: PlanItSpacing.xxs,
                ),
                child: Row(
                  children: <Widget>[
                    Expanded(child: Text(_nameFor(impact.accountId))),
                    Text(
                      '${impact.before.toDisplayString()} → ${impact.after.toDisplayString()}',
                      textAlign: TextAlign.end,
                    ),
                  ],
                ),
              ),
            if (preview.fxRate != null) ...<Widget>[
              const Divider(),
              Text('Stored FX rate: ${preview.fxRate}'),
            ],
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

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.icon,
    required this.message,
    this.error = false,
  });

  final IconData icon;
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
            Icon(icon),
            const SizedBox(width: PlanItSpacing.sm),
            Expanded(child: Text(message)),
          ],
        ),
      ),
    );
  }
}

class _TransferUnavailable extends StatelessWidget {
  const _TransferUnavailable();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(PlanItSpacing.xl),
        child: Text(
          'Add at least two active accounts before creating a transfer.',
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
