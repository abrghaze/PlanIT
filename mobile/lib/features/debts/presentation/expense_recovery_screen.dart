import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:planit_mobile/core/design_system/tokens.dart';
import 'package:planit_mobile/core/money/money.dart';
import 'package:planit_mobile/features/accounts/application/providers.dart';
import 'package:planit_mobile/features/accounts/domain/account.dart';
import 'package:planit_mobile/features/debts/application/debt_controller.dart';
import 'package:planit_mobile/features/debts/application/providers.dart';
import 'package:planit_mobile/features/debts/domain/debt.dart';
import 'package:planit_mobile/features/transactions/application/providers.dart';
import 'package:planit_mobile/features/transactions/domain/transaction.dart';

enum ExpenseRecoveryKind { share, refund }

class ExpenseRecoveryScreen extends ConsumerStatefulWidget {
  const ExpenseRecoveryScreen({
    required this.transactionId,
    required this.kind,
    super.key,
  });
  final String transactionId;
  final ExpenseRecoveryKind kind;
  @override
  ConsumerState<ExpenseRecoveryScreen> createState() =>
      _ExpenseRecoveryScreenState();
}

class _ExpenseRecoveryScreenState extends ConsumerState<ExpenseRecoveryScreen> {
  final amount = TextEditingController();
  final note = TextEditingController();
  String? personId;
  String? accountId;
  DateTime? dueDate;
  @override
  void dispose() {
    amount.dispose();
    note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final transactions =
        ref.watch(transactionsProvider).value ?? const <LedgerTransaction>[];
    final transaction = transactions
        .where((t) => t.id == widget.transactionId)
        .firstOrNull;
    if (transaction == null) {
      return const Scaffold(
        body: Center(child: Text('Expense is not available locally.')),
      );
    }
    final people = ref.watch(peopleProvider).value ?? const <Person>[];
    final accounts = ref.watch(accountsProvider).value ?? const <Account>[];
    personId ??= people.firstOrNull?.id;
    accountId ??= accounts
        .where(
          (a) =>
              a.status == AccountStatus.active &&
              a.currency == transaction.amount.currency,
        )
        .firstOrNull
        ?.id;
    final sharing = widget.kind == ExpenseRecoveryKind.share;
    final action = ref.watch(debtControllerProvider);
    return Scaffold(
      appBar: AppBar(title: Text(sharing ? 'Share expense' : 'Record refund')),
      body: ListView(
        padding: const EdgeInsets.all(PlanItSpacing.lg),
        children: <Widget>[
          Card(
            child: ListTile(
              leading: Icon(
                sharing
                    ? Icons.group_add_outlined
                    : Icons.currency_exchange_rounded,
              ),
              title: Text(
                sharing
                    ? 'Create a reimbursement receivable'
                    : 'Link money returned to this purchase',
              ),
              subtitle: Text(
                sharing
                    ? 'The gross account outflow stays unchanged; your personal spending falls by the share.'
                    : 'The refund increases the selected account and reduces net spending.',
              ),
            ),
          ),
          const SizedBox(height: PlanItSpacing.lg),
          if (sharing)
            DropdownButtonFormField<String>(
              initialValue: personId,
              decoration: const InputDecoration(labelText: 'Person'),
              items: people
                  .map(
                    (p) => DropdownMenuItem(value: p.id, child: Text(p.name)),
                  )
                  .toList(),
              onChanged: (v) => setState(() => personId = v),
            )
          else
            DropdownButtonFormField<String>(
              initialValue: accountId,
              decoration: const InputDecoration(
                labelText: 'Destination account',
              ),
              items: accounts
                  .where(
                    (a) =>
                        a.status == AccountStatus.active &&
                        a.currency == transaction.amount.currency,
                  )
                  .map(
                    (a) => DropdownMenuItem(value: a.id, child: Text(a.name)),
                  )
                  .toList(),
              onChanged: (v) => setState(() => accountId = v),
            ),
          const SizedBox(height: PlanItSpacing.md),
          TextField(
            controller: amount,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: sharing ? 'Amount owed back' : 'Refund amount',
              suffixText: transaction.amount.currency,
            ),
          ),
          const SizedBox(height: PlanItSpacing.md),
          TextField(
            controller: note,
            maxLength: 2000,
            decoration: const InputDecoration(labelText: 'Note (optional)'),
          ),
          if (sharing)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.event_outlined),
              title: const Text('Reimbursement due date'),
              subtitle: Text(
                dueDate == null ? 'Optional' : _displayDate(dueDate!),
              ),
              trailing: dueDate == null
                  ? const Icon(Icons.chevron_right_rounded)
                  : IconButton(
                      tooltip: 'Clear due date',
                      onPressed: () => setState(() => dueDate = null),
                      icon: const Icon(Icons.close_rounded),
                    ),
              onTap: _pickDueDate,
            ),
          if (action.error != null)
            Text(
              action.error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          FilledButton.icon(
            onPressed: action.busy ? null : () => _submit(transaction),
            icon: const Icon(Icons.check_rounded),
            label: Text(sharing ? 'Queue share' : 'Queue refund'),
          ),
        ],
      ),
    );
  }

  Future<void> _submit(LedgerTransaction transaction) async {
    try {
      final money = Money.parse(
        amount.text.trim(),
        transaction.amount.currency,
      );
      final controller = ref.read(debtControllerProvider.notifier);
      final ok = widget.kind == ExpenseRecoveryKind.share
          ? await controller.queueShare(
              transactionId: transaction.id,
              personId: personId!,
              amount: money,
              dueDate: dueDate,
              note: note.text,
            )
          : await controller.queueRefund(
              transactionId: transaction.id,
              accountId: accountId!,
              amount: money,
              note: note.text,
            );
      if (ok && mounted) context.pop();
    } on Object {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Complete the form with a valid positive amount.'),
          ),
        );
      }
    }
  }

  Future<void> _pickDueDate() async {
    final today = DateUtils.dateOnly(DateTime.now());
    final selected = await showDatePicker(
      context: context,
      initialDate: dueDate ?? today,
      firstDate: today,
      lastDate: DateTime(today.year + 20, 12, 31),
      helpText: 'Select reimbursement due date',
    );
    if (selected != null && mounted) setState(() => dueDate = selected);
  }
}

String _displayDate(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
