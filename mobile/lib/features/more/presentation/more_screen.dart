import 'package:flutter/material.dart';
import 'package:planit_mobile/core/design_system/tokens.dart';

class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final entries = <({IconData icon, String label})>[
      (icon: Icons.account_balance_wallet_outlined, label: 'Accounts'),
      (icon: Icons.people_alt_outlined, label: 'People & debts'),
      (icon: Icons.storefront_outlined, label: 'Shops'),
      (icon: Icons.inventory_2_outlined, label: 'Products'),
      (icon: Icons.repeat_rounded, label: 'Recurring'),
      (icon: Icons.savings_outlined, label: 'Savings goals'),
      (icon: Icons.settings_outlined, label: 'Settings'),
    ];

    return ListView(
      padding: const EdgeInsets.all(PlanItSpacing.lg),
      children: <Widget>[
        Text(
          'More',
          style: Theme.of(
            context,
          ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: PlanItSpacing.lg),
        for (final entry in entries)
          Card(
            margin: const EdgeInsets.only(bottom: PlanItSpacing.sm),
            child: ListTile(
              leading: Icon(entry.icon),
              title: Text(entry.label),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () {},
            ),
          ),
      ],
    );
  }
}
