import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:planit_mobile/core/auth/application/auth_controller.dart';
import 'package:planit_mobile/core/design_system/tokens.dart';
import 'package:planit_mobile/core/money/money_format.dart';
import 'package:planit_mobile/features/accounts/application/providers.dart';
import 'package:planit_mobile/features/accounts/domain/account.dart';
import 'package:planit_mobile/features/planning/application/providers.dart';
import 'package:planit_mobile/features/planning/domain/planning.dart';
import 'package:uuid/uuid.dart';

class GoalsScreen extends ConsumerStatefulWidget {
  const GoalsScreen({super.key});
  @override
  ConsumerState<GoalsScreen> createState() => _GoalsScreenState();
}

class _GoalsScreenState extends ConsumerState<GoalsScreen> {
  var _busy = false;

  @override
  Widget build(BuildContext context) {
    final dashboard = ref.watch(planningDashboardProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Savings goals')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _busy ? null : _create,
        icon: const Icon(Icons.add),
        label: const Text('New goal'),
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.refresh(planningDashboardProvider.future),
        child: dashboard.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => ListView(
            children: const <Widget>[
              SizedBox(height: 240),
              Center(child: Text('Savings goals could not be loaded.')),
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
              const Card(
                child: ListTile(
                  leading: Icon(Icons.savings_outlined),
                  title: Text('Saving is not spending'),
                  subtitle: Text(
                    'Manual allocations only track progress. Linked goals read the account balance. Neither creates an expense.',
                  ),
                ),
              ),
              if (value.offline)
                const Card(
                  child: ListTile(
                    leading: Icon(Icons.cloud_off_outlined),
                    title: Text('Showing saved goal progress'),
                  ),
                ),
              if (value.goals.isEmpty)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(PlanItSpacing.lg),
                    child: Text(
                      'Create a goal for an emergency fund, trip, or major purchase.',
                    ),
                  ),
                ),
              for (final goal in value.goals)
                _GoalCard(
                  goal: goal,
                  busy: _busy,
                  onAllocate: goal.manual ? () => _allocate(goal) : null,
                  onArchive: () => _archive(goal),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _create() async {
    final accounts = await ref.read(accountsProvider.future);
    if (!mounted) return;
    final session = ref.read(authControllerProvider).session;
    if (session == null) return;
    final payload = await showDialog<Map<String, Object?>>(
      context: context,
      builder: (_) => _GoalDialog(
        accounts: accounts
            .where((item) => item.status == AccountStatus.active)
            .toList(),
        baseCurrency: session.user.baseCurrency,
      ),
    );
    if (payload == null) return;
    await _run(() async {
      final fresh = await ref
          .read(authControllerProvider.notifier)
          .requireFreshSession();
      await ref
          .read(planningApiProvider)
          .createGoal(fresh.accessToken, const Uuid().v4(), payload);
    }, 'Savings goal created.');
  }

  Future<void> _allocate(SavingsGoal goal) async {
    final controller = TextEditingController();
    final amount = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Adjust ${goal.name}'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(
            decimal: true,
            signed: true,
          ),
          decoration: InputDecoration(
            labelText: 'Allocation (${goal.target.currency})',
            helperText: 'Use a negative amount to correct progress.',
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
    final parsed = amount == null ? null : double.tryParse(amount);
    if (parsed == null || parsed == 0) return;
    final operation = const Uuid().v4();
    await _run(() async {
      final session = await ref
          .read(authControllerProvider.notifier)
          .requireFreshSession();
      await ref.read(planningApiProvider).allocate(
        session.accessToken,
        operation,
        goal.id,
        <String, Object?>{
          'id': const Uuid().v4(),
          'client_operation_id': operation,
          'amount': <String, Object?>{
            'amount': parsed.toStringAsFixed(4),
            'currency': goal.target.currency,
          },
        },
      );
    }, 'Goal progress updated without creating spending.');
  }

  Future<void> _archive(SavingsGoal goal) => _run(() async {
    final session = await ref
        .read(authControllerProvider.notifier)
        .requireFreshSession();
    await ref.read(planningApiProvider).updateGoal(
      session.accessToken,
      const Uuid().v4(),
      goal.id,
      <String, Object?>{'version': goal.version, 'status': 'ARCHIVED'},
    );
  }, 'Goal archived.');

  Future<void> _run(Future<void> Function() action, String success) async {
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

class _GoalCard extends StatelessWidget {
  const _GoalCard({
    required this.goal,
    required this.busy,
    required this.onAllocate,
    required this.onArchive,
  });
  final SavingsGoal goal;
  final bool busy;
  final VoidCallback? onAllocate;
  final VoidCallback onArchive;
  @override
  Widget build(BuildContext context) {
    final pace = GoalPace.fromGoal(goal);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(PlanItSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    goal.name,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                PopupMenuButton<String>(
                  enabled: !busy,
                  onSelected: (_) => onArchive(),
                  itemBuilder: (_) => const <PopupMenuEntry<String>>[
                    PopupMenuItem(value: 'archive', child: Text('Archive')),
                  ],
                ),
              ],
            ),
            Text(
              '${goal.progress.toDisplayString()} of ${goal.target.toDisplayString()}',
            ),
            const SizedBox(height: PlanItSpacing.sm),
            LinearProgressIndicator(value: (goal.percent / 100).clamp(0, 1)),
            const SizedBox(height: PlanItSpacing.xs),
            Text(
              '${goal.percent.toStringAsFixed(0)}% · ${goal.remaining.toDisplayString()} remaining'
              '${goal.linkedAccountId == null ? ' · Manual' : ' · Linked account'}',
            ),
            if (goal.targetDate != null)
              Text('Target ${_date(goal.targetDate!)}'),
            if (pace.overdue)
              Text(
                'Deadline passed. Review the target or add the remaining amount.',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              )
            else if (pace.monthlyRequired != null)
              Text(
                '${pace.monthlyRequired!.toDisplayString()} per month needed '
                '(${pace.daysRemaining} days left)',
              ),
            if (onAllocate != null)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: busy ? null : onAllocate,
                  icon: const Icon(Icons.add_circle_outline),
                  label: const Text('Adjust progress'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _GoalDialog extends StatefulWidget {
  const _GoalDialog({required this.accounts, required this.baseCurrency});
  final List<Account> accounts;
  final String baseCurrency;
  @override
  State<_GoalDialog> createState() => _GoalDialogState();
}

class _GoalDialogState extends State<_GoalDialog> {
  final name = TextEditingController();
  final amount = TextEditingController();
  Account? linked;
  DateTime? targetDate;

  @override
  Widget build(BuildContext context) {
    final currency = linked?.currency ?? widget.baseCurrency;
    return AlertDialog(
      title: const Text('New savings goal'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            TextField(
              controller: name,
              decoration: const InputDecoration(labelText: 'Goal name'),
            ),
            TextField(
              controller: amount,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(labelText: 'Target ($currency)'),
            ),
            DropdownButtonFormField<Account?>(
              initialValue: linked,
              decoration: const InputDecoration(labelText: 'Progress source'),
              items: <DropdownMenuItem<Account?>>[
                const DropdownMenuItem(
                  value: null,
                  child: Text('Manual allocations'),
                ),
                ...widget.accounts.map(
                  (account) => DropdownMenuItem(
                    value: account,
                    child: Text(account.name),
                  ),
                ),
              ],
              onChanged: (value) => setState(() => linked = value),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Target date (optional)'),
              subtitle: Text(
                targetDate == null ? 'No deadline' : _date(targetDate!),
              ),
              onTap: () async {
                final now = DateTime.now();
                final picked = await showDatePicker(
                  context: context,
                  firstDate: now,
                  lastDate: DateTime(now.year + 20),
                  initialDate: targetDate ?? now.add(const Duration(days: 365)),
                );
                if (picked != null) setState(() => targetDate = picked);
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
            final parsed = double.tryParse(amount.text);
            if (name.text.trim().isEmpty || parsed == null || parsed <= 0) {
              return;
            }
            Navigator.pop(context, <String, Object?>{
              'id': const Uuid().v4(),
              'name': name.text.trim(),
              'target_amount': <String, Object?>{
                'amount': parsed.toStringAsFixed(4),
                'currency': currency,
              },
              if (targetDate != null)
                'target_date':
                    '${targetDate!.year}-${targetDate!.month.toString().padLeft(2, '0')}-${targetDate!.day.toString().padLeft(2, '0')}',
              if (linked != null) 'linked_account_id': linked!.id,
            });
          },
          child: const Text('Create'),
        ),
      ],
    );
  }

  @override
  void dispose() {
    name.dispose();
    amount.dispose();
    super.dispose();
  }
}

String _date(DateTime value) =>
    '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
