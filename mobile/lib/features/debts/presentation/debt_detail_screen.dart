import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:planit_mobile/core/design_system/tokens.dart';
import 'package:planit_mobile/core/money/money.dart';
import 'package:planit_mobile/core/money/money_format.dart';
import 'package:planit_mobile/features/accounts/application/providers.dart';
import 'package:planit_mobile/features/accounts/domain/account.dart';
import 'package:planit_mobile/features/debts/application/debt_controller.dart';
import 'package:planit_mobile/features/debts/application/providers.dart';
import 'package:planit_mobile/features/debts/domain/debt.dart';

class DebtDetailScreen extends ConsumerWidget {
  const DebtDetailScreen({required this.debtId, super.key});
  final String debtId;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final debts = ref.watch(debtsProvider).value ?? const <Debt>[];
    final debt = debts.where((d) => d.id == debtId).firstOrNull;
    if (debt == null) {
      return const Scaffold(
        body: Center(child: Text('Debt is not available.')),
      );
    }
    final people = ref.watch(peopleProvider).value ?? const <Person>[];
    final name =
        people.where((p) => p.id == debt.personId).firstOrNull?.name ??
        'Unknown person';
    return Scaffold(
      appBar: AppBar(title: Text(name)),
      body: ListView(
        padding: const EdgeInsets.all(PlanItSpacing.lg),
        children: <Widget>[
          Card(
            child: Padding(
              padding: const EdgeInsets.all(PlanItSpacing.lg),
              child: Column(
                children: <Widget>[
                  Text(debt.direction.label),
                  Text(
                    debt.remainingAmount.toDisplayString(),
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Text(
                    '${debt.origin.label} · ${debt.status.replaceAll('_', ' ').toLowerCase()}',
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: PlanItSpacing.md),
          ListTile(
            title: const Text('Original'),
            trailing: Text(debt.originalAmount.toDisplayString()),
          ),
          ListTile(
            title: const Text('Paid'),
            trailing: Text(debt.paidAmount.toDisplayString()),
          ),
          if (debt.dueDate != null)
            ListTile(
              title: const Text('Due date'),
              trailing: Text(
                '${debt.dueDate!.year.toString().padLeft(4, '0')}-${debt.dueDate!.month.toString().padLeft(2, '0')}-${debt.dueDate!.day.toString().padLeft(2, '0')}',
              ),
            ),
          if (debt.note != null)
            ListTile(title: const Text('Note'), subtitle: Text(debt.note!)),
          if (debt.acceptsPayment)
            FilledButton.icon(
              onPressed: () => _payment(context, ref, debt),
              icon: const Icon(Icons.payments_outlined),
              label: Text(
                debt.direction == DebtDirection.receivable
                    ? 'Record money received'
                    : 'Record payment sent',
              ),
            ),
          const SizedBox(height: PlanItSpacing.lg),
          Text(
            'Payment history',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          for (final payment in debt.payments)
            ListTile(
              leading: const Icon(Icons.check_circle_outline),
              title: Text(payment.amount.toDisplayString()),
              subtitle: Text(
                payment.paidAt.toLocal().toString().split('.').first,
              ),
            ),
        ],
      ),
    );
  }

  static Future<void> _payment(
    BuildContext context,
    WidgetRef ref,
    Debt debt,
  ) async {
    final accounts = ref.read(accountsProvider).value ?? const <Account>[];
    String? accountId = accounts
        .where(
          (a) =>
              a.status == AccountStatus.active &&
              a.currency == debt.remainingAmount.currency,
        )
        .firstOrNull
        ?.id;
    final amount = TextEditingController(
      text: debt.remainingAmount.toApiString(),
    );
    final submitted = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Record repayment'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              DropdownButtonFormField<String>(
                initialValue: accountId,
                decoration: const InputDecoration(labelText: 'Account'),
                items: accounts
                    .where(
                      (a) =>
                          a.status == AccountStatus.active &&
                          a.currency == debt.remainingAmount.currency,
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
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: 'Amount',
                  suffixText: debt.remainingAmount.currency,
                ),
              ),
            ],
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Queue'),
            ),
          ],
        ),
      ),
    );
    if (submitted == true && accountId != null) {
      try {
        final money = Money.parse(
          amount.text.trim(),
          debt.remainingAmount.currency,
        );
        await ref
            .read(debtControllerProvider.notifier)
            .queuePayment(debt: debt, accountId: accountId!, amount: money);
      } on Object {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Enter a valid repayment amount.')),
          );
        }
      }
    }
    amount.dispose();
  }
}
