import 'package:flutter/material.dart';
import 'package:planit_mobile/core/design_system/tokens.dart';

class AddActionSheet extends StatelessWidget {
  const AddActionSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final actions = <({IconData icon, String title, String subtitle})>[
      (icon: Icons.arrow_upward_rounded, title: 'Expense', subtitle: 'Record money spent'),
      (icon: Icons.arrow_downward_rounded, title: 'Income', subtitle: 'Record genuine income'),
      (icon: Icons.swap_horiz_rounded, title: 'Transfer', subtitle: 'Move money between accounts'),
      (icon: Icons.people_alt_outlined, title: 'Debt', subtitle: 'Existing, lend now, or borrow now'),
      (icon: Icons.balance_rounded, title: 'Reconcile', subtitle: 'Match an account to its real balance'),
    ];

    return Padding(
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
          Text('Add financial activity', style: Theme.of(context).textTheme.headlineSmall),
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
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => Navigator.of(context).pop(),
            ),
        ],
      ),
    );
  }
}
