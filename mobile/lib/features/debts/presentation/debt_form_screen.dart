import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:planit_mobile/core/auth/application/auth_controller.dart';
import 'package:planit_mobile/core/design_system/tokens.dart';
import 'package:planit_mobile/core/money/money.dart';
import 'package:planit_mobile/features/accounts/application/providers.dart';
import 'package:planit_mobile/features/accounts/domain/account.dart';
import 'package:planit_mobile/features/debts/application/debt_controller.dart';
import 'package:planit_mobile/features/debts/application/providers.dart';
import 'package:planit_mobile/features/debts/domain/debt.dart';

class DebtFormScreen extends ConsumerStatefulWidget {
  const DebtFormScreen({super.key});
  @override
  ConsumerState<DebtFormScreen> createState() => _DebtFormScreenState();
}

class _DebtFormScreenState extends ConsumerState<DebtFormScreen> {
  final amount = TextEditingController();
  final note = TextEditingController();
  DebtOrigin origin = DebtOrigin.existing;
  DebtDirection direction = DebtDirection.receivable;
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
    final people = ref.watch(peopleProvider).value ?? const <Person>[];
    final accounts = ref.watch(accountsProvider).value ?? const <Account>[];
    final action = ref.watch(debtControllerProvider);
    final cash = origin == DebtOrigin.lendNow || origin == DebtOrigin.borrowNow;
    personId ??= people.firstOrNull?.id;
    accountId ??= accounts
        .where((a) => a.status == AccountStatus.active)
        .firstOrNull
        ?.id;
    return Scaffold(
      appBar: AppBar(title: const Text('Add debt')),
      body: ListView(
        padding: const EdgeInsets.all(PlanItSpacing.lg),
        children: <Widget>[
          SegmentedButton<DebtOrigin>(
            segments: DebtOrigin.values
                .where((v) => v != DebtOrigin.sharedExpense)
                .map((v) => ButtonSegment(value: v, label: Text(v.label)))
                .toList(),
            selected: <DebtOrigin>{origin},
            onSelectionChanged: (v) => setState(() {
              origin = v.single;
              if (origin == DebtOrigin.lendNow) {
                direction = DebtDirection.receivable;
              }
              if (origin == DebtOrigin.borrowNow) {
                direction = DebtDirection.payable;
              }
            }),
          ),
          const SizedBox(height: PlanItSpacing.lg),
          DropdownButtonFormField<String>(
            initialValue: personId,
            decoration: const InputDecoration(labelText: 'Person'),
            items: people
                .map((p) => DropdownMenuItem(value: p.id, child: Text(p.name)))
                .toList(),
            onChanged: (v) => setState(() => personId = v),
          ),
          const SizedBox(height: PlanItSpacing.md),
          if (origin == DebtOrigin.existing)
            DropdownButtonFormField<DebtDirection>(
              initialValue: direction,
              decoration: const InputDecoration(labelText: 'Direction'),
              items: DebtDirection.values
                  .map((v) => DropdownMenuItem(value: v, child: Text(v.label)))
                  .toList(),
              onChanged: (v) => setState(() => direction = v!),
            )
          else
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(direction.label),
              subtitle: Text(
                origin == DebtOrigin.lendNow
                    ? 'Money leaves your account; this is not spending.'
                    : 'Money enters your account; this is not income.',
              ),
            ),
          if (cash) ...<Widget>[
            const SizedBox(height: PlanItSpacing.md),
            DropdownButtonFormField<String>(
              initialValue: accountId,
              decoration: const InputDecoration(labelText: 'Account'),
              items: accounts
                  .where((a) => a.status == AccountStatus.active)
                  .map(
                    (a) => DropdownMenuItem(
                      value: a.id,
                      child: Text('${a.name} · ${a.currency}'),
                    ),
                  )
                  .toList(),
              onChanged: (v) => setState(() => accountId = v),
            ),
          ],
          const SizedBox(height: PlanItSpacing.md),
          TextField(
            controller: amount,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: 'Amount',
              suffixText: _currency(accounts, cash),
            ),
          ),
          const SizedBox(height: PlanItSpacing.md),
          TextField(
            controller: note,
            maxLength: 2000,
            decoration: const InputDecoration(labelText: 'Note (optional)'),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.event_outlined),
            title: const Text('Due date'),
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
            Padding(
              padding: const EdgeInsets.only(bottom: PlanItSpacing.sm),
              child: Text(
                action.error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          FilledButton.icon(
            onPressed: action.busy ? null : () => _submit(accounts, cash),
            icon: action.busy
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.check_rounded),
            label: const Text('Queue debt'),
          ),
        ],
      ),
    );
  }

  String _currency(List<Account> accounts, bool cash) {
    if (cash) {
      return accounts.where((a) => a.id == accountId).firstOrNull?.currency ??
          '';
    }
    return ref.read(authControllerProvider).session?.user.baseCurrency ?? 'MAD';
  }

  Future<void> _submit(List<Account> accounts, bool cash) async {
    if (personId == null || (cash && accountId == null)) return;
    try {
      final money = Money.parse(amount.text.trim(), _currency(accounts, cash));
      final ok = await ref
          .read(debtControllerProvider.notifier)
          .queueDebt(
            personId: personId!,
            origin: origin,
            direction: direction,
            amount: money,
            accountId: accountId,
            dueDate: dueDate,
            note: note.text,
          );
      if (ok && mounted) context.go('/debts');
    } on Object {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Enter a valid positive amount.')),
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
      helpText: 'Select debt due date',
    );
    if (selected != null && mounted) setState(() => dueDate = selected);
  }
}

String _displayDate(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
