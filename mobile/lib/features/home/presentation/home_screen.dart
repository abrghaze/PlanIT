import 'package:flutter/material.dart';
import 'package:planit_mobile/core/design_system/tokens.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: <Widget>[
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(
            PlanItSpacing.lg,
            PlanItSpacing.lg,
            PlanItSpacing.lg,
            PlanItSpacing.xxl,
          ),
          sliver: SliverList.list(
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text('Your financial picture', style: Theme.of(context).textTheme.labelLarge),
                        const SizedBox(height: PlanItSpacing.xxs),
                        Text('PlanIT', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800)),
                      ],
                    ),
                  ),
                  IconButton.filledTonal(
                    tooltip: 'Notifications',
                    onPressed: () {},
                    icon: const Icon(Icons.notifications_none_rounded),
                  ),
                ],
              ),
              const SizedBox(height: PlanItSpacing.lg),
              const _EmptyBalanceCard(),
              const SizedBox(height: PlanItSpacing.lg),
              Text('Start with the foundation', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: PlanItSpacing.sm),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(PlanItSpacing.lg),
                  child: Column(
                    children: <Widget>[
                      const Icon(Icons.account_balance_wallet_outlined, size: 42),
                      const SizedBox(height: PlanItSpacing.md),
                      Text('Add your first account', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                      const SizedBox(height: PlanItSpacing.xs),
                      Text(
                        'Bank accounts, savings, cards, and cash stay separate while PlanIT gives you one trustworthy total.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: PlanItSpacing.lg),
                      FilledButton.icon(
                        onPressed: () {},
                        icon: const Icon(Icons.add_rounded),
                        label: const Text('Add account'),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
class _EmptyBalanceCard extends StatelessWidget {
  const _EmptyBalanceCard();

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
          BoxShadow(color: Color(0x33315CF6), blurRadius: 24, offset: Offset(0, 12)),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(PlanItSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('MONEY IN ACCOUNTS', style: Theme.of(context).textTheme.labelMedium?.copyWith(color: Colors.white70, letterSpacing: 1.1)),
            const SizedBox(height: PlanItSpacing.sm),
            Text('—', style: Theme.of(context).textTheme.displaySmall?.copyWith(color: Colors.white, fontWeight: FontWeight.w800)),
            const SizedBox(height: PlanItSpacing.lg),
            const Row(
              children: <Widget>[
                Expanded(child: _BalanceCaption(label: 'People owe me', value: '—')),
                Expanded(child: _BalanceCaption(label: 'I owe people', value: '—')),
                Expanded(child: _BalanceCaption(label: 'Net position', value: '—')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _BalanceCaption extends StatelessWidget {
  const _BalanceCaption({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(label, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Colors.white70)),
        const SizedBox(height: PlanItSpacing.xxs),
        Text(value, style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.w700)),
      ],
    );
  }
}
