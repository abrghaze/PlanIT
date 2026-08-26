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

class ReconciliationScreen extends ConsumerStatefulWidget {
  const ReconciliationScreen({this.initialAccountId, super.key});

  final String? initialAccountId;

  @override
  ConsumerState<ReconciliationScreen> createState() =>
      _ReconciliationScreenState();
}

class _ReconciliationScreenState extends ConsumerState<ReconciliationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _actualBalanceController = TextEditingController();
  final _reasonController = TextEditingController();
  String? _accountId;
  DateTime _effectiveAt = DateTime.now().toUtc();
  ReconciliationPreviewRequest? _previewedRequest;

  @override
  void initState() {
    super.initState();
    _accountId = widget.initialAccountId;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(financialOperationControllerProvider.notifier).reset();
    });
  }

  @override
  void dispose() {
    _actualBalanceController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final active = (ref.watch(accountsProvider).value ?? const <Account>[])
        .where((account) => account.status == AccountStatus.active)
        .toList(growable: false);
    if (_accountId == null && active.isNotEmpty) {
      _accountId = active.first.id;
    }
    if (!active.any((account) => account.id == _accountId)) {
      _accountId = active.firstOrNull?.id;
    }
    final account = active.where((value) => value.id == _accountId).firstOrNull;
    final action = ref.watch(financialOperationControllerProvider);
    final preview = action.reconciliationPreview;
    final offline = ref.watch(authControllerProvider).offline;

    return Scaffold(
      appBar: AppBar(title: const Text('Reconcile balance')),
      body: active.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(PlanItSpacing.xl),
                child: Text(
                  'Add an active account before reconciling a balance.',
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
                  const _ReconciliationInfo(
                    message:
                        'Enter the real balance from your statement. PlanIT records one neutral adjustment and preserves the original ledger history.',
                  ),
                  if (offline) ...<Widget>[
                    const SizedBox(height: PlanItSpacing.sm),
                    const _ReconciliationInfo(
                      message:
                          'Connect to preview the server-calculated balance before confirming.',
                    ),
                  ],
                  if (action.errorMessage != null) ...<Widget>[
                    const SizedBox(height: PlanItSpacing.sm),
                    _ReconciliationInfo(
                      message: action.errorMessage!,
                      error: true,
                    ),
                  ],
                  const SizedBox(height: PlanItSpacing.lg),
                  DropdownButtonFormField<String>(
                    initialValue: _accountId,
                    decoration: const InputDecoration(
                      labelText: 'Account',
                      prefixIcon: Icon(Icons.account_balance_wallet_outlined),
                    ),
                    items: active
                        .map(
                          (value) => DropdownMenuItem<String>(
                            value: value.id,
                            child: Text('${value.name} · ${value.currency}'),
                          ),
                        )
                        .toList(growable: false),
                    onChanged: action.busy
                        ? null
                        : (value) => setState(() {
                            _accountId = value;
                            _actualBalanceController.clear();
                            _invalidatePreview();
                          }),
                  ),
                  if (account != null) ...<Widget>[
                    const SizedBox(height: PlanItSpacing.xs),
                    Text(
                      'Cached balance: ${account.calculatedBalance.toDisplayString()}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                  const SizedBox(height: PlanItSpacing.md),
                  TextFormField(
                    controller: _actualBalanceController,
                    enabled: !action.busy,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                      signed: true,
                    ),
                    decoration: InputDecoration(
                      labelText: 'Actual balance',
                      prefixIcon: const Icon(Icons.fact_check_outlined),
                      suffixText: account?.currency,
                    ),
                    onChanged: (_) => _invalidatePreview(),
                    validator: (value) {
                      if (account == null) {
                        return 'Select an account.';
                      }
                      try {
                        final parsed = Money.parse(
                          value?.trim() ?? '',
                          account.currency,
                        );
                        if (parsed.scaledAmount.isNegative &&
                            !account.allowNegative) {
                          return 'This account does not allow a negative balance.';
                        }
                        return null;
                      } on FormatException {
                        return 'Use an amount with up to 4 decimals.';
                      }
                    },
                  ),
                  const SizedBox(height: PlanItSpacing.sm),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.event_outlined),
                    title: const Text('Effective date'),
                    subtitle: Text(_formatDate(_effectiveAt)),
                    trailing: const Icon(Icons.edit_calendar_outlined),
                    onTap: action.busy ? null : _pickDate,
                  ),
                  const SizedBox(height: PlanItSpacing.sm),
                  TextFormField(
                    controller: _reasonController,
                    enabled: !action.busy,
                    maxLength: 2000,
                    minLines: 2,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: 'Reason (optional)',
                      hintText: 'For example: monthly bank statement',
                      alignLabelWithHint: true,
                    ),
                  ),
                  const SizedBox(height: PlanItSpacing.md),
                  if (preview != null) ...<Widget>[
                    Card(
                      color: Theme.of(context).colorScheme.secondaryContainer,
                      child: Padding(
                        padding: const EdgeInsets.all(PlanItSpacing.md),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              'Authoritative preview',
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w800),
                            ),
                            const SizedBox(height: PlanItSpacing.sm),
                            _PreviewRow(
                              label: 'Calculated',
                              value: preview.calculatedBalance
                                  .toDisplayString(),
                            ),
                            _PreviewRow(
                              label: 'Actual',
                              value: preview.actualBalance.toDisplayString(),
                            ),
                            _PreviewRow(
                              label: 'Neutral adjustment',
                              value: preview.delta.toDisplayString(),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: PlanItSpacing.md),
                  ],
                  OutlinedButton.icon(
                    onPressed: action.busy || offline ? null : _preview,
                    icon: action.busy
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.calculate_outlined),
                    label: const Text('Preview adjustment'),
                  ),
                  const SizedBox(height: PlanItSpacing.sm),
                  FilledButton.icon(
                    onPressed:
                        action.busy ||
                            preview == null ||
                            preview.delta.scaledAmount == BigInt.zero ||
                            _previewedRequest == null
                        ? null
                        : _commit,
                    icon: const Icon(Icons.balance_rounded),
                    label: Text(
                      preview?.delta.scaledAmount == BigInt.zero
                          ? 'Balance already matches'
                          : 'Confirm reconciliation',
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Future<void> _preview() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    final account = (ref.read(accountsProvider).value ?? const <Account>[])
        .where((value) => value.id == _accountId)
        .firstOrNull;
    if (account == null) {
      return;
    }
    final request = ReconciliationPreviewRequest(
      accountId: account.id,
      actualBalance: Money.parse(
        _actualBalanceController.text.trim(),
        account.currency,
      ),
      effectiveAt: _effectiveAt,
    );
    final success = await ref
        .read(financialOperationControllerProvider.notifier)
        .previewReconciliation(request);
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
        .queueReconciliation(request: request, reason: _reasonController.text);
    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Reconciliation queued. The cached balance changes only after acknowledgment.',
          ),
        ),
      );
      Navigator.of(context).pop();
    }
  }

  Future<void> _pickDate() async {
    final current = _effectiveAt.toLocal();
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
      _effectiveAt = DateTime(
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

  static String _formatDate(DateTime value) {
    final local = value.toLocal();
    return '${local.year}-${local.month.toString().padLeft(2, '0')}-'
        '${local.day.toString().padLeft(2, '0')}';
  }
}

class _PreviewRow extends StatelessWidget {
  const _PreviewRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: PlanItSpacing.xxs),
      child: Row(
        children: <Widget>[
          Expanded(child: Text(label)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _ReconciliationInfo extends StatelessWidget {
  const _ReconciliationInfo({required this.message, this.error = false});

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
