import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:planit_mobile/core/auth/application/auth_controller.dart';
import 'package:planit_mobile/core/design_system/tokens.dart';
import 'package:planit_mobile/core/money/money.dart';
import 'package:planit_mobile/core/money/money_format.dart';
import 'package:planit_mobile/features/accounts/application/account_controller.dart';
import 'package:planit_mobile/features/accounts/application/providers.dart';
import 'package:planit_mobile/features/accounts/domain/account.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);
    final accounts = ref.watch(accountsProvider);
    ref.watch(accountBootstrapProvider);
    final firstName =
        auth.session?.user.displayName.split(' ').first ?? 'there';

    return RefreshIndicator(
      onRefresh: () => ref.read(accountControllerProvider.notifier).refresh(),
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: <Widget>[
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              PlanItSpacing.lg,
              PlanItSpacing.lg,
              PlanItSpacing.lg,
              104,
            ),
            sliver: SliverList.list(
              children: <Widget>[
                _Header(firstName: firstName),
                if (auth.offline) ...<Widget>[
                  const SizedBox(height: PlanItSpacing.md),
                  const _OfflineBanner(),
                ],
                const SizedBox(height: PlanItSpacing.lg),
                accounts.when(
                  loading: () => const _BalanceCardLoading(),
                  error: (error, stackTrace) => const _BalanceCardLoading(),
                  data: (items) => _HomeAccountContent(
                    accounts: items,
                    baseCurrency: auth.session?.user.baseCurrency ?? 'MAD',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.firstName});

  final String firstName;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'Good to see you, $firstName',
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const SizedBox(height: PlanItSpacing.xxs),
              Text(
                'Your financial picture',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
        IconButton.filledTonal(
          tooltip: 'Notifications',
          onPressed: () {},
          icon: const Icon(Icons.notifications_none_rounded),
        ),
      ],
    );
  }
}

class _HomeAccountContent extends StatelessWidget {
  const _HomeAccountContent({
    required this.accounts,
    required this.baseCurrency,
  });

  final List<Account> accounts;
  final String baseCurrency;

  @override
  Widget build(BuildContext context) {
    final active = accounts
        .where((account) => account.status == AccountStatus.active)
        .toList(growable: false);
    var baseTotal = Money.zero(baseCurrency);
    var hasUnconvertedAccounts = false;
    for (final account in active) {
      if (!account.includeInTotal) {
        continue;
      }
      if (account.currency == baseCurrency) {
        baseTotal += account.calculatedBalance;
      } else {
        hasUnconvertedAccounts = true;
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _BalanceCard(
          total: baseTotal,
          activeCount: active.length,
          partial: hasUnconvertedAccounts,
        ),
        const SizedBox(height: PlanItSpacing.lg),
        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                'Accounts',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
            ),
            TextButton(
              onPressed: () => context.push('/accounts'),
              child: const Text('See all'),
            ),
          ],
        ),
        const SizedBox(height: PlanItSpacing.sm),
        if (active.isEmpty)
          _EmptyAccountCard(onAdd: () => context.push('/accounts/new'))
        else
          SizedBox(
            height: 132,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: active.length,
              separatorBuilder: (context, index) =>
                  const SizedBox(width: PlanItSpacing.sm),
              itemBuilder: (context, index) =>
                  _AccountMiniCard(account: active[index]),
            ),
          ),
        const SizedBox(height: PlanItSpacing.lg),
        Text(
          'This month',
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: PlanItSpacing.sm),
        const Card(
          child: Padding(
            padding: EdgeInsets.all(PlanItSpacing.lg),
            child: Row(
              children: <Widget>[
                CircleAvatar(child: Icon(Icons.insights_outlined)),
                SizedBox(width: PlanItSpacing.md),
                Expanded(
                  child: Text(
                    'Posted expenses and transfer fees count as spending. Internal transfers and balance corrections remain neutral.',
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _BalanceCard extends StatelessWidget {
  const _BalanceCard({
    required this.total,
    required this.activeCount,
    required this.partial,
  });

  final Money total;
  final int activeCount;
  final bool partial;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[Color(0xFF172554), Color(0xFF315CF6)],
        ),
        borderRadius: BorderRadius.circular(PlanItRadius.lg),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x33315CF6),
            blurRadius: 24,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(PlanItSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              partial ? 'BASE-CURRENCY SUBTOTAL' : 'MONEY IN ACCOUNTS',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: Colors.white70,
                letterSpacing: 1.1,
              ),
            ),
            const SizedBox(height: PlanItSpacing.sm),
            Text(
              total.toDisplayString(),
              style: Theme.of(context).textTheme.displaySmall?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: PlanItSpacing.lg),
            Row(
              children: <Widget>[
                const Icon(
                  Icons.account_balance_wallet_outlined,
                  color: Colors.white70,
                ),
                const SizedBox(width: PlanItSpacing.xs),
                Text(
                  '$activeCount active ${activeCount == 1 ? 'account' : 'accounts'}',
                  style: const TextStyle(color: Colors.white),
                ),
              ],
            ),
            if (partial) ...<Widget>[
              const SizedBox(height: PlanItSpacing.sm),
              const Text(
                'Accounts in other currencies are excluded until an approved exchange rate exists.',
                style: TextStyle(color: Colors.white70),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _BalanceCardLoading extends StatelessWidget {
  const _BalanceCardLoading();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: 190,
      child: Card(child: Center(child: CircularProgressIndicator())),
    );
  }
}

class _AccountMiniCard extends StatelessWidget {
  const _AccountMiniCard({required this.account});

  final Account account;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 220,
      child: Card(
        child: InkWell(
          borderRadius: BorderRadius.circular(PlanItRadius.md),
          onTap: () => context.push('/accounts/${account.id}/edit'),
          child: Padding(
            padding: const EdgeInsets.all(PlanItSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    const Icon(Icons.account_balance_wallet_outlined),
                    const Spacer(),
                    if (!account.includeInTotal)
                      const Icon(Icons.visibility_off_outlined, size: 18),
                  ],
                ),
                const Spacer(),
                Text(
                  account.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: PlanItSpacing.xxs),
                Text(
                  account.calculatedBalance.toDisplayString(),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyAccountCard extends StatelessWidget {
  const _EmptyAccountCard({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(PlanItSpacing.lg),
        child: Column(
          children: <Widget>[
            const Icon(Icons.account_balance_wallet_outlined, size: 42),
            const SizedBox(height: PlanItSpacing.md),
            Text(
              'Add your first account',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: PlanItSpacing.xs),
            const Text(
              'Bank accounts, savings, cards, and cash stay separate while PlanIT gives you one trustworthy total.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: PlanItSpacing.lg),
            FilledButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add account'),
            ),
          ],
        ),
      ),
    );
  }
}

class _OfflineBanner extends StatelessWidget {
  const _OfflineBanner();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(PlanItRadius.sm),
      ),
      child: const Padding(
        padding: EdgeInsets.all(PlanItSpacing.sm),
        child: Row(
          children: <Widget>[
            Icon(Icons.cloud_off_outlined),
            SizedBox(width: PlanItSpacing.xs),
            Expanded(
              child: Text(
                'Offline: cached account balances are still available.',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
