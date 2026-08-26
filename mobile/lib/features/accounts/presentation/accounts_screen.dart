import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:planit_mobile/core/auth/application/auth_controller.dart';
import 'package:planit_mobile/core/design_system/tokens.dart';
import 'package:planit_mobile/core/money/money_format.dart';
import 'package:planit_mobile/features/accounts/application/account_controller.dart';
import 'package:planit_mobile/features/accounts/application/providers.dart';
import 'package:planit_mobile/features/accounts/domain/account.dart';

class AccountsScreen extends ConsumerWidget {
  const AccountsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accounts = ref.watch(accountsProvider);
    final action = ref.watch(accountControllerProvider);
    final auth = ref.watch(authControllerProvider);
    final bootstrap = ref.watch(accountBootstrapProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Accounts'),
        actions: <Widget>[
          IconButton(
            tooltip: 'Keep Total Fixed',
            onPressed: () => context.push('/reallocations/new'),
            icon: const Icon(Icons.balance_rounded),
          ),
          IconButton(
            tooltip: 'Refresh accounts',
            onPressed: action.busy
                ? null
                : () => ref.read(accountControllerProvider.notifier).refresh(),
            icon: const Icon(Icons.sync_rounded),
          ),
        ],
        bottom: bootstrap.isLoading || action.busy
            ? const PreferredSize(
                preferredSize: Size.fromHeight(2),
                child: LinearProgressIndicator(minHeight: 2),
              )
            : null,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/accounts/new'),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add account'),
      ),
      body: accounts.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => _AccountLoadError(
          onRetry: () => ref.read(accountControllerProvider.notifier).refresh(),
        ),
        data: (items) => RefreshIndicator(
          onRefresh: () =>
              ref.read(accountControllerProvider.notifier).refresh(),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              PlanItSpacing.lg,
              PlanItSpacing.md,
              PlanItSpacing.lg,
              104,
            ),
            children: <Widget>[
              if (auth.offline)
                const _StatusBanner(
                  icon: Icons.cloud_off_outlined,
                  message: 'Offline: showing the latest account cache.',
                ),
              if (action.errorMessage != null)
                _StatusBanner(
                  icon: Icons.error_outline_rounded,
                  message: action.errorMessage!,
                  error: true,
                ),
              if (auth.offline || action.errorMessage != null)
                const SizedBox(height: PlanItSpacing.md),
              if (items.isEmpty)
                const _EmptyAccounts()
              else ...<Widget>[
                _AccountSection(
                  title: 'Active',
                  accounts: items
                      .where(
                        (account) => account.status == AccountStatus.active,
                      )
                      .toList(),
                ),
                _AccountSection(
                  title: 'Archived',
                  accounts: items
                      .where(
                        (account) => account.status == AccountStatus.archived,
                      )
                      .toList(),
                ),
                _AccountSection(
                  title: 'Closed',
                  accounts: items
                      .where(
                        (account) => account.status == AccountStatus.closed,
                      )
                      .toList(),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _AccountSection extends StatelessWidget {
  const _AccountSection({required this.title, required this.accounts});

  final String title;
  final List<Account> accounts;

  @override
  Widget build(BuildContext context) {
    if (accounts.isEmpty) {
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.only(
            top: PlanItSpacing.sm,
            bottom: PlanItSpacing.sm,
          ),
          child: Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
        ),
        for (final account in accounts) ...<Widget>[
          _AccountCard(account: account),
          const SizedBox(height: PlanItSpacing.sm),
        ],
        const SizedBox(height: PlanItSpacing.sm),
      ],
    );
  }
}

class _AccountCard extends StatelessWidget {
  const _AccountCard({required this.account});

  final Account account;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(PlanItRadius.md),
        onTap: () => context.push('/accounts/${account.id}/edit'),
        child: Padding(
          padding: const EdgeInsets.all(PlanItSpacing.md),
          child: Row(
            children: <Widget>[
              CircleAvatar(
                radius: 24,
                backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                child: Icon(
                  _iconFor(account.type),
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                ),
              ),
              const SizedBox(width: PlanItSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Flexible(
                          child: Text(
                            account.name,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                        ),
                        if (!account.includeInTotal) ...<Widget>[
                          const SizedBox(width: PlanItSpacing.xs),
                          const Icon(
                            Icons.visibility_off_outlined,
                            size: 16,
                            semanticLabel: 'Excluded from total',
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: PlanItSpacing.xxs),
                    Text('${account.type.label} · ${account.status.label}'),
                  ],
                ),
              ),
              const SizedBox(width: PlanItSpacing.sm),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: <Widget>[
                      Text(
                        account.calculatedBalance.toDisplayString(),
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: PlanItSpacing.xxs),
                      Text(
                        'v${account.version}',
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                    ],
                  ),
                  PopupMenuButton<_AccountMenuAction>(
                    tooltip: 'Account actions',
                    onSelected: (selected) {
                      switch (selected) {
                        case _AccountMenuAction.edit:
                          context.push('/accounts/${account.id}/edit');
                        case _AccountMenuAction.transfer:
                          context.push('/transfers/new');
                        case _AccountMenuAction.reconcile:
                          context.push(
                            '/reconciliations/new?accountId=${account.id}',
                          );
                      }
                    },
                    itemBuilder: (context) =>
                        const <PopupMenuEntry<_AccountMenuAction>>[
                          PopupMenuItem<_AccountMenuAction>(
                            value: _AccountMenuAction.transfer,
                            child: Text('Transfer'),
                          ),
                          PopupMenuItem<_AccountMenuAction>(
                            value: _AccountMenuAction.reconcile,
                            child: Text('Reconcile'),
                          ),
                          PopupMenuItem<_AccountMenuAction>(
                            value: _AccountMenuAction.edit,
                            child: Text('Edit account'),
                          ),
                        ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  static IconData _iconFor(AccountType type) => switch (type) {
    AccountType.bank => Icons.account_balance_rounded,
    AccountType.cash => Icons.payments_outlined,
    AccountType.savings => Icons.savings_outlined,
    AccountType.card => Icons.credit_card_rounded,
    AccountType.prepaid => Icons.wallet_outlined,
    AccountType.investment => Icons.trending_up_rounded,
    AccountType.other => Icons.account_balance_wallet_outlined,
  };
}

enum _AccountMenuAction { transfer, reconcile, edit }

class _EmptyAccounts extends StatelessWidget {
  const _EmptyAccounts();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: PlanItSpacing.xxl),
      child: Column(
        children: <Widget>[
          Icon(
            Icons.account_balance_wallet_outlined,
            size: 64,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: PlanItSpacing.md),
          Text(
            'Add where your money lives',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: PlanItSpacing.xs),
          const Text(
            'Bank accounts, cash, savings, and cards remain separate while PlanIT calculates trustworthy totals.',
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _AccountLoadError extends StatelessWidget {
  const _AccountLoadError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: FilledButton.icon(
        onPressed: onRetry,
        icon: const Icon(Icons.refresh_rounded),
        label: const Text('Reload accounts'),
      ),
    );
  }
}

class _StatusBanner extends StatelessWidget {
  const _StatusBanner({
    required this.icon,
    required this.message,
    this.error = false,
  });

  final IconData icon;
  final String message;
  final bool error;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final background = error
        ? scheme.errorContainer
        : scheme.secondaryContainer;
    final foreground = error
        ? scheme.onErrorContainer
        : scheme.onSecondaryContainer;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(PlanItRadius.sm),
      ),
      child: Padding(
        padding: const EdgeInsets.all(PlanItSpacing.sm),
        child: Row(
          children: <Widget>[
            Icon(icon, color: foreground),
            const SizedBox(width: PlanItSpacing.xs),
            Expanded(
              child: Text(message, style: TextStyle(color: foreground)),
            ),
          ],
        ),
      ),
    );
  }
}
