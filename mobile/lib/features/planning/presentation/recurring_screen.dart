import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:planit_mobile/core/auth/application/auth_controller.dart';
import 'package:planit_mobile/core/design_system/tokens.dart';
import 'package:planit_mobile/core/money/exact_decimal.dart';
import 'package:planit_mobile/core/money/money_format.dart';
import 'package:planit_mobile/features/accounts/application/providers.dart';
import 'package:planit_mobile/features/accounts/domain/account.dart';
import 'package:planit_mobile/features/planning/application/providers.dart';
import 'package:planit_mobile/features/planning/domain/planning.dart';
import 'package:uuid/uuid.dart';

class RecurringScreen extends ConsumerStatefulWidget {
  const RecurringScreen({super.key});

  @override
  ConsumerState<RecurringScreen> createState() => _RecurringScreenState();
}

class _RecurringScreenState extends ConsumerState<RecurringScreen> {
  var _busy = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(_refresh);
  }

  @override
  Widget build(BuildContext context) {
    final dashboard = ref.watch(planningDashboardProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Recurring commitments')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _busy ? null : _create,
        icon: const Icon(Icons.add),
        label: const Text('Add recurring'),
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: dashboard.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => ListView(
            children: const <Widget>[
              SizedBox(height: 240),
              Center(child: Text('Recurring commitments could not be loaded.')),
            ],
          ),
          data: (value) => ListView(
            padding: const EdgeInsets.fromLTRB(
              PlanItSpacing.md,
              PlanItSpacing.md,
              PlanItSpacing.md,
              104,
            ),
            children: <Widget>[
              if (value.offline)
                const Card(
                  child: ListTile(
                    leading: Icon(Icons.cloud_off_outlined),
                    title: Text('Showing saved planning data'),
                    subtitle: Text(
                      'Due dates remain visible while you are offline.',
                    ),
                  ),
                ),
              const _SafetyCard(),
              for (final total in value.totals) _TotalCard(total: total),
              const SizedBox(height: PlanItSpacing.sm),
              Text(
                'Next due',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: PlanItSpacing.sm),
              if (value.rules.isEmpty)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(PlanItSpacing.lg),
                    child: Text(
                      'Add rent, salary, subscriptions, or regular bills.',
                    ),
                  ),
                ),
              for (final rule in value.rules)
                _RuleCard(rule: rule, busy: _busy, onStatus: _setStatus),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _refresh() async {
    try {
      final session = await ref
          .read(authControllerProvider.notifier)
          .requireFreshSession();
      await ref
          .read(planningApiProvider)
          .processDue(session.accessToken, const Uuid().v4());
    } catch (_) {
      // Loading below falls back to the owner-scoped local planning cache.
    }
    ref.invalidate(planningDashboardProvider);
    try {
      await ref.read(planningDashboardProvider.future);
    } catch (_) {
      // The provider exposes this error in the screen when no cache exists.
    }
  }

  Future<void> _create() async {
    final accounts = await ref.read(accountsProvider.future);
    if (!mounted) return;
    final active = accounts
        .where((account) => account.status == AccountStatus.active)
        .toList(growable: false);
    if (active.isEmpty) {
      _message(
        'Create an active account before adding a recurring commitment.',
      );
      return;
    }
    final session = ref.read(authControllerProvider).session;
    if (session == null) return;
    final payload = await showDialog<Map<String, Object?>>(
      context: context,
      builder: (_) =>
          _RecurringDialog(accounts: active, timezone: session.user.timezone),
    );
    if (payload == null) return;
    await _run(() async {
      final fresh = await ref
          .read(authControllerProvider.notifier)
          .requireFreshSession();
      await ref
          .read(planningApiProvider)
          .createRule(fresh.accessToken, const Uuid().v4(), payload);
    }, success: 'Recurring commitment added.');
  }

  Future<void> _setStatus(RecurringRule rule, String status) => _run(
    () async {
      final session = await ref
          .read(authControllerProvider.notifier)
          .requireFreshSession();
      await ref.read(planningApiProvider).updateRule(
        session.accessToken,
        const Uuid().v4(),
        rule.id,
        <String, Object?>{'version': rule.version, 'status': status},
      );
    },
    success: status == 'PAUSED'
        ? 'Recurring rule paused.'
        : 'Recurring rule updated.',
  );

  Future<void> _run(
    Future<void> Function() action, {
    required String success,
  }) async {
    setState(() => _busy = true);
    try {
      await action();
      ref.invalidate(planningDashboardProvider);
      _message(success);
    } catch (error) {
      _message('$error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _message(String text) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
    }
  }
}

class _SafetyCard extends StatelessWidget {
  const _SafetyCard();
  @override
  Widget build(BuildContext context) => const Card(
    child: ListTile(
      leading: Icon(Icons.fact_check_outlined),
      title: Text('You stay in control'),
      subtitle: Text(
        'Reminders never change balances. Automatic rules create drafts for review—not posted spending.',
      ),
    ),
  );
}

class _TotalCard extends StatelessWidget {
  const _TotalCard({required this.total});
  final RecurringTotal total;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(PlanItSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            '${total.currency} commitments',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: PlanItSpacing.sm),
          Row(
            children: <Widget>[
              Expanded(
                child: _Metric(
                  'Monthly out',
                  total.expenseMonthly.toDisplayString(),
                ),
              ),
              Expanded(
                child: _Metric(
                  'Annual out',
                  total.expenseAnnual.toDisplayString(),
                ),
              ),
            ],
          ),
          const SizedBox(height: PlanItSpacing.sm),
          Text(
            'Expected monthly income: ${total.incomeMonthly.toDisplayString()}',
          ),
        ],
      ),
    ),
  );
}

class _Metric extends StatelessWidget {
  const _Metric(this.label, this.value);
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: <Widget>[
      Text(label),
      Text(value, style: Theme.of(context).textTheme.titleMedium),
    ],
  );
}

class _RuleCard extends StatelessWidget {
  const _RuleCard({
    required this.rule,
    required this.busy,
    required this.onStatus,
  });
  final RecurringRule rule;
  final bool busy;
  final Future<void> Function(RecurringRule, String) onStatus;
  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      leading: CircleAvatar(
        child: Icon(
          rule.kind == 'INCOME' ? Icons.south_west : Icons.north_east,
        ),
      ),
      title: Text(rule.name),
      subtitle: Text(
        '${rule.amount.toDisplayString()} · ${rule.frequency.toLowerCase()}\n'
        '${rule.isDue ? 'Due now' : 'Next ${_date(rule.nextDueAt)}'} · '
        '${rule.mode == 'AUTO_DRAFT' ? 'Reviewable draft' : 'Reminder'}',
      ),
      isThreeLine: true,
      trailing: PopupMenuButton<String>(
        enabled: !busy,
        onSelected: (value) => onStatus(rule, value),
        itemBuilder: (_) => <PopupMenuEntry<String>>[
          if (rule.status == 'ACTIVE')
            const PopupMenuItem(value: 'PAUSED', child: Text('Pause')),
          if (rule.status == 'PAUSED')
            const PopupMenuItem(value: 'ACTIVE', child: Text('Resume')),
          const PopupMenuItem(value: 'ARCHIVED', child: Text('Archive')),
        ],
      ),
    ),
  );
}

class _RecurringDialog extends StatefulWidget {
  const _RecurringDialog({required this.accounts, required this.timezone});
  final List<Account> accounts;
  final String timezone;
  @override
  State<_RecurringDialog> createState() => _RecurringDialogState();
}

class _RecurringDialogState extends State<_RecurringDialog> {
  final name = TextEditingController();
  final amount = TextEditingController();
  late Account account = widget.accounts.first;
  var kind = 'EXPENSE';
  var frequency = 'MONTHLY';
  var mode = 'REMINDER';
  DateTime due = DateTime.now().add(const Duration(days: 1));

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('New recurring commitment'),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          TextField(
            controller: name,
            decoration: const InputDecoration(labelText: 'Name'),
          ),
          TextField(
            controller: amount,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: 'Amount (${account.currency})',
            ),
          ),
          DropdownButtonFormField<Account>(
            initialValue: account,
            decoration: const InputDecoration(labelText: 'Account'),
            items: widget.accounts
                .map(
                  (item) =>
                      DropdownMenuItem(value: item, child: Text(item.name)),
                )
                .toList(),
            onChanged: (value) => setState(() => account = value!),
          ),
          DropdownButtonFormField<String>(
            initialValue: kind,
            decoration: const InputDecoration(labelText: 'Type'),
            items: const <DropdownMenuItem<String>>[
              DropdownMenuItem(
                value: 'EXPENSE',
                child: Text('Expense or bill'),
              ),
              DropdownMenuItem(
                value: 'INCOME',
                child: Text('Income or salary'),
              ),
            ],
            onChanged: (value) => setState(() => kind = value!),
          ),
          DropdownButtonFormField<String>(
            initialValue: frequency,
            decoration: const InputDecoration(labelText: 'Frequency'),
            items: const <DropdownMenuItem<String>>[
              DropdownMenuItem(value: 'WEEKLY', child: Text('Weekly')),
              DropdownMenuItem(value: 'MONTHLY', child: Text('Monthly')),
              DropdownMenuItem(value: 'QUARTERLY', child: Text('Quarterly')),
              DropdownMenuItem(value: 'YEARLY', child: Text('Yearly')),
            ],
            onChanged: (value) => setState(() => frequency = value!),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Create reviewable draft when due'),
            value: mode == 'AUTO_DRAFT',
            onChanged: (value) =>
                setState(() => mode = value ? 'AUTO_DRAFT' : 'REMINDER'),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('First due date'),
            subtitle: Text(_date(due)),
            trailing: const Icon(Icons.calendar_month_outlined),
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                firstDate: DateTime.now().subtract(const Duration(days: 1)),
                lastDate: DateTime.now().add(const Duration(days: 3650)),
                initialDate: due,
              );
              if (picked != null) setState(() => due = picked);
            },
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
        onPressed: () {
          final parsed = ExactDecimal.tryParse(
            amount.text,
            scale: 4,
            maximumDigits: 19,
          );
          if (name.text.trim().isEmpty ||
              parsed == null ||
              !parsed.isPositive) {
            return;
          }
          Navigator.pop(context, <String, Object?>{
            'id': const Uuid().v4(),
            'name': name.text.trim(),
            'kind': kind,
            'account_id': account.id,
            'amount': <String, Object?>{
              'amount': parsed.toFixedString(),
              'currency': account.currency,
            },
            'frequency': frequency,
            'timezone': widget.timezone,
            'next_due_at': DateTime(
              due.year,
              due.month,
              due.day,
              9,
            ).toUtc().toIso8601String(),
            'mode': mode,
          });
        },
        child: const Text('Save'),
      ),
    ],
  );

  @override
  void dispose() {
    name.dispose();
    amount.dispose();
    super.dispose();
  }
}

String _date(DateTime value) {
  final local = value.toLocal();
  return '${local.year}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')}';
}
