import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:planit_mobile/core/design_system/tokens.dart';

class AddActionSheet extends StatelessWidget {
  const AddActionSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final actions =
        <({IconData icon, String title, String subtitle, String? route})>[
          (
            icon: Icons.arrow_upward_rounded,
            title: 'Expense',
            subtitle: 'Record money spent',
            route: '/transactions/new?type=EXPENSE',
          ),
          (
            icon: Icons.arrow_downward_rounded,
            title: 'Income',
            subtitle: 'Record genuine income',
            route: '/transactions/new?type=INCOME',
          ),
          (
            icon: Icons.swap_horiz_rounded,
            title: 'Transfer',
            subtitle: 'Move money between accounts',
            route: '/transfers/new',
          ),
          (
            icon: Icons.people_alt_outlined,
            title: 'Debt',
            subtitle: 'Existing, lend now, or borrow now',
            route: '/debts/new',
          ),
          (
            icon: Icons.balance_rounded,
            title: 'Reconcile',
            subtitle: 'Match an account to its real balance',
            route: '/reconciliations/new',
          ),
          (
            icon: Icons.lock_outline_rounded,
            title: 'Keep Total Fixed',
            subtitle: 'Reallocate balances without changing the total',
            route: '/reallocations/new',
          ),
        ];

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          PlanItSpacing.lg,
          PlanItSpacing.sm,
          PlanItSpacing.lg,
          PlanItSpacing.xl,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Add financial activity',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: PlanItSpacing.xs),
            Text(
              'Each action has its own review step so the balance and dashboard impact are clear.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: PlanItSpacing.lg),
            for (final action in actions)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(child: Icon(action.icon)),
                title: Text(action.title),
                subtitle: Text(action.subtitle),
                trailing: action.route == null
                    ? const Text('Later')
                    : const Icon(Icons.chevron_right_rounded),
                enabled: action.route != null,
                onTap: action.route == null
                    ? null
                    : () {
                        final router = GoRouter.of(context);
                        Navigator.of(context).pop();
                        router.push(action.route!);
                      },
              ),
          ],
        ),
      ),
    );
  }
}
