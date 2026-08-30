import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:planit_mobile/core/auth/application/auth_controller.dart';
import 'package:planit_mobile/core/design_system/tokens.dart';

class MoreScreen extends ConsumerWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);
    final user = auth.session?.user;
    final entries = <({IconData icon, String label, VoidCallback? onTap})>[
      (
        icon: Icons.account_balance_wallet_outlined,
        label: 'Accounts',
        onTap: () => context.push('/accounts'),
      ),
      (
        icon: Icons.category_outlined,
        label: 'Categories & tags',
        onTap: () => context.push('/catalog'),
      ),
      (
        icon: Icons.people_alt_outlined,
        label: 'People & debts',
        onTap: () => context.push('/debts'),
      ),
      (
        icon: Icons.storefront_outlined,
        label: 'Shops',
        onTap: () => context.push('/merchants'),
      ),
      (
        icon: Icons.inventory_2_outlined,
        label: 'Products',
        onTap: () => context.push('/products'),
      ),
      (icon: Icons.repeat_rounded, label: 'Recurring', onTap: null),
      (icon: Icons.savings_outlined, label: 'Savings goals', onTap: null),
      (icon: Icons.settings_outlined, label: 'Settings', onTap: null),
    ];

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        PlanItSpacing.lg,
        PlanItSpacing.lg,
        PlanItSpacing.lg,
        104,
      ),
      children: <Widget>[
        Text(
          'More',
          style: Theme.of(
            context,
          ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: PlanItSpacing.lg),
        Card(
          child: ListTile(
            leading: CircleAvatar(
              child: Text(
                (user?.displayName.isNotEmpty ?? false)
                    ? user!.displayName[0].toUpperCase()
                    : 'P',
              ),
            ),
            title: Text(user?.displayName ?? 'PlanIT user'),
            subtitle: Text(user?.email ?? ''),
            trailing: auth.offline
                ? const Tooltip(
                    message: 'Offline session',
                    child: Icon(Icons.cloud_off_outlined),
                  )
                : const Icon(Icons.verified_user_outlined),
          ),
        ),
        const SizedBox(height: PlanItSpacing.lg),
        for (final entry in entries)
          Card(
            margin: const EdgeInsets.only(bottom: PlanItSpacing.sm),
            child: ListTile(
              leading: Icon(entry.icon),
              title: Text(entry.label),
              subtitle: entry.onTap == null
                  ? const Text('Coming in a later milestone')
                  : null,
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: entry.onTap,
            ),
          ),
        const SizedBox(height: PlanItSpacing.md),
        OutlinedButton.icon(
          onPressed: auth.busy
              ? null
              : () async {
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Sign out?'),
                      content: const Text(
                        "Secure tokens and this user's local financial cache will be removed from this device.",
                      ),
                      actions: <Widget>[
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(false),
                          child: const Text('Cancel'),
                        ),
                        FilledButton(
                          onPressed: () => Navigator.of(context).pop(true),
                          child: const Text('Sign out'),
                        ),
                      ],
                    ),
                  );
                  if (confirmed == true) {
                    await ref.read(authControllerProvider.notifier).logout();
                  }
                },
          icon: const Icon(Icons.logout_rounded),
          label: const Text('Sign out'),
        ),
      ],
    );
  }
}
