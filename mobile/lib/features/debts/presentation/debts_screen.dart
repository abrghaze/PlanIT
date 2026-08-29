import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:planit_mobile/core/design_system/tokens.dart';
import 'package:planit_mobile/core/money/money_format.dart';
import 'package:planit_mobile/features/debts/application/debt_controller.dart';
import 'package:planit_mobile/features/debts/application/providers.dart';
import 'package:planit_mobile/features/debts/domain/debt.dart';

class DebtsScreen extends ConsumerWidget {
  const DebtsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final people = ref.watch(peopleProvider);
    final debts = ref.watch(debtsProvider);
    final action = ref.watch(debtControllerProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('People & debts'),
        actions: <Widget>[
          IconButton(
            tooltip: 'Add person',
            onPressed: action.busy ? null : () => _addPerson(context, ref),
            icon: const Icon(Icons.person_add_alt_1_outlined),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/debts/new'),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add debt'),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(peopleProvider);
          ref.invalidate(debtsProvider);
          await Future.wait(<Future<Object?>>[
            ref.read(peopleProvider.future),
            ref.read(debtsProvider.future),
          ]);
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(
            PlanItSpacing.lg,
            PlanItSpacing.md,
            PlanItSpacing.lg,
            104,
          ),
          children: <Widget>[
            if (action.error != null) _Notice(action.error!, error: true),
            if (action.notice != null) _Notice(action.notice!),
            _Summary(debts: debts.value ?? const <Debt>[]),
            const SizedBox(height: PlanItSpacing.lg),
            Text('Outstanding', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: PlanItSpacing.sm),
            debts.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, _) =>
                  const _Notice('Debts could not be loaded.', error: true),
              data: (items) {
                final visible = items
                    .where((item) => item.acceptsPayment)
                    .toList(growable: false);
                if (visible.isEmpty) {
                  return const _Empty('No outstanding debts yet.');
                }
                final peopleById = <String, Person>{
                  for (final person in people.value ?? const <Person>[])
                    person.id: person,
                };
                return Column(
                  children: visible
                      .map(
                        (debt) => Card(
                          child: ListTile(
                            leading: CircleAvatar(
                              child: Icon(
                                debt.direction == DebtDirection.receivable
                                    ? Icons.south_west_rounded
                                    : Icons.north_east_rounded,
                              ),
                            ),
                            title: Text(
                              peopleById[debt.personId]?.name ??
                                  'Unknown person',
                            ),
                            subtitle: Text(
                              '${debt.direction.label} · ${debt.origin.label}${debt.overdue ? ' · Overdue' : ''}',
                            ),
                            trailing: Text(
                              debt.remainingAmount.toDisplayString(),
                              style: Theme.of(context).textTheme.titleSmall
                                  ?.copyWith(fontWeight: FontWeight.w800),
                            ),
                            onTap: () => context.push('/debts/${debt.id}'),
                          ),
                        ),
                      )
                      .toList(growable: false),
                );
              },
            ),
            const SizedBox(height: PlanItSpacing.lg),
            Text('People', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: PlanItSpacing.sm),
            people.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, _) =>
                  const _Notice('People could not be loaded.', error: true),
              data: (items) => items.isEmpty
                  ? const _Empty('Add a person to start tracking money owed.')
                  : Card(
                      child: Column(
                        children: items
                            .map(
                              (person) => ListTile(
                                leading: CircleAvatar(
                                  child: Text(person.name[0].toUpperCase()),
                                ),
                                title: Text(person.name),
                                subtitle: person.contact == null
                                    ? null
                                    : Text(person.contact!),
                              ),
                            )
                            .toList(growable: false),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  static Future<void> _addPerson(BuildContext context, WidgetRef ref) async {
    final name = TextEditingController();
    final contact = TextEditingController();
    final submitted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add person'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            TextField(
              controller: name,
              autofocus: true,
              maxLength: 120,
              decoration: const InputDecoration(labelText: 'Name'),
            ),
            TextField(
              controller: contact,
              maxLength: 240,
              decoration: const InputDecoration(
                labelText: 'Contact (optional)',
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
            child: const Text('Add'),
          ),
        ],
      ),
    );
    if (submitted == true && name.text.trim().isNotEmpty) {
      await ref
          .read(debtControllerProvider.notifier)
          .createPerson(name: name.text, contact: contact.text);
    }
    name.dispose();
    contact.dispose();
  }
}

class _Summary extends StatelessWidget {
  const _Summary({required this.debts});
  final List<Debt> debts;
  @override
  Widget build(BuildContext context) {
    final open = debts
        .where((item) => item.acceptsPayment)
        .toList(growable: false);
    final receivables = open
        .where((item) => item.direction == DebtDirection.receivable)
        .length;
    final payables = open.length - receivables;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(PlanItSpacing.lg),
        child: Row(
          children: <Widget>[
            Expanded(
              child: _Metric(label: 'Receivables', value: '$receivables'),
            ),
            Expanded(
              child: _Metric(label: 'Payables', value: '$payables'),
            ),
            Expanded(
              child: _Metric(
                label: 'Overdue',
                value: '${open.where((item) => item.overdue).length}',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Column(
    children: <Widget>[
      Text(
        value,
        style: Theme.of(
          context,
        ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
      ),
      Text(label),
    ],
  );
}

class _Empty extends StatelessWidget {
  const _Empty(this.message);
  final String message;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(PlanItSpacing.lg),
    child: Center(child: Text(message)),
  );
}

class _Notice extends StatelessWidget {
  const _Notice(this.message, {this.error = false});
  final String message;
  final bool error;
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: PlanItSpacing.sm),
      padding: const EdgeInsets.all(PlanItSpacing.sm),
      decoration: BoxDecoration(
        color: error ? colors.errorContainer : colors.secondaryContainer,
        borderRadius: BorderRadius.circular(PlanItRadius.sm),
      ),
      child: Text(message),
    );
  }
}
