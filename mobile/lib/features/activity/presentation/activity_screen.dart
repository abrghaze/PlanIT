import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:planit_mobile/core/design_system/tokens.dart';
import 'package:planit_mobile/core/money/money_format.dart';
import 'package:planit_mobile/features/transactions/application/providers.dart';
import 'package:planit_mobile/features/transactions/application/transaction_controller.dart';
import 'package:planit_mobile/features/transactions/domain/catalog.dart';
import 'package:planit_mobile/features/transactions/domain/transaction.dart';

enum _ActivityFilter { all, expenses, income, transfers, drafts }

class ActivityScreen extends ConsumerStatefulWidget {
  const ActivityScreen({super.key});

  @override
  ConsumerState<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends ConsumerState<ActivityScreen> {
  _ActivityFilter _filter = _ActivityFilter.all;
  String _query = '';

  @override
  Widget build(BuildContext context) {
    ref.watch(ledgerBootstrapProvider);
    final transactions = ref.watch(transactionsProvider);
    final categories =
        ref.watch(transactionCategoriesProvider).value ??
        const <TransactionCategory>[];
    final pending = ref.watch(pendingTransactionCountProvider).value ?? 0;
    final action = ref.watch(transactionControllerProvider);

    return RefreshIndicator(
      onRefresh: () =>
          ref.read(transactionControllerProvider.notifier).refresh(force: true),
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: <Widget>[
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              PlanItSpacing.lg,
              PlanItSpacing.lg,
              PlanItSpacing.lg,
              PlanItSpacing.sm,
            ),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          'Activity',
                          style: Theme.of(context).textTheme.headlineMedium
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                      ),
                      if (pending > 0)
                        Badge(
                          label: Text('$pending'),
                          child: IconButton(
                            tooltip: 'Review pending operations',
                            onPressed: () =>
                                context.push('/pending-operations'),
                            icon: const Icon(Icons.cloud_upload_outlined),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: PlanItSpacing.md),
                  SearchBar(
                    leading: const Icon(Icons.search),
                    hintText: 'Search transactions',
                    onChanged: (value) => setState(() => _query = value),
                  ),
                  const SizedBox(height: PlanItSpacing.sm),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: SegmentedButton<_ActivityFilter>(
                      showSelectedIcon: false,
                      segments: const <ButtonSegment<_ActivityFilter>>[
                        ButtonSegment<_ActivityFilter>(
                          value: _ActivityFilter.all,
                          label: Text('All'),
                        ),
                        ButtonSegment<_ActivityFilter>(
                          value: _ActivityFilter.expenses,
                          label: Text('Expenses'),
                        ),
                        ButtonSegment<_ActivityFilter>(
                          value: _ActivityFilter.income,
                          label: Text('Income'),
                        ),
                        ButtonSegment<_ActivityFilter>(
                          value: _ActivityFilter.transfers,
                          label: Text('Transfers'),
                        ),
                        ButtonSegment<_ActivityFilter>(
                          value: _ActivityFilter.drafts,
                          label: Text('Drafts'),
                        ),
                      ],
                      selected: <_ActivityFilter>{_filter},
                      onSelectionChanged: (value) {
                        setState(() => _filter = value.single);
                      },
                    ),
                  ),
                  if (action.errorMessage != null) ...<Widget>[
                    const SizedBox(height: PlanItSpacing.sm),
                    _SyncBanner(message: action.errorMessage!, error: true),
                  ] else if (action.noticeMessage != null) ...<Widget>[
                    const SizedBox(height: PlanItSpacing.sm),
                    _SyncBanner(message: action.noticeMessage!),
                  ],
                ],
              ),
            ),
          ),
          transactions.when(
            loading: () => const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (_, _) => const SliverFillRemaining(
              child: Center(child: Text('Local activity could not be loaded.')),
            ),
            data: (values) {
              final filtered = _filterValues(values, categories);
              if (filtered.isEmpty) {
                return SliverFillRemaining(
                  hasScrollBody: false,
                  child: _EmptyActivity(hasTransactions: values.isNotEmpty),
                );
              }
              return SliverPadding(
                padding: const EdgeInsets.fromLTRB(
                  PlanItSpacing.lg,
                  PlanItSpacing.sm,
                  PlanItSpacing.lg,
                  104,
                ),
                sliver: SliverList.builder(
                  itemCount: filtered.length,
                  itemBuilder: (context, index) => _TransactionCard(
                    transaction: filtered[index],
                    category: _categoryFor(
                      categories,
                      filtered[index].categoryId,
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  List<LedgerTransaction> _filterValues(
    List<LedgerTransaction> values,
    List<TransactionCategory> categories,
  ) {
    final normalizedQuery = _query.trim().toLowerCase();
    return values
        .where((value) {
          final matchesFilter = switch (_filter) {
            _ActivityFilter.all => true,
            _ActivityFilter.expenses => value.type == TransactionType.expense,
            _ActivityFilter.income => value.type == TransactionType.income,
            _ActivityFilter.transfers => value.type.isTransfer,
            _ActivityFilter.drafts => value.status == TransactionStatus.draft,
          };
          if (!matchesFilter || normalizedQuery.isEmpty) {
            return matchesFilter;
          }
          final category = _categoryFor(categories, value.categoryId);
          return <String>[
            value.counterparty ?? '',
            value.note ?? '',
            category?.name ?? '',
            value.type.label,
          ].any((text) => text.toLowerCase().contains(normalizedQuery));
        })
        .toList(growable: false);
  }

  static TransactionCategory? _categoryFor(
    List<TransactionCategory> categories,
    String? id,
  ) {
    for (final category in categories) {
      if (category.id == id) {
        return category;
      }
    }
    return null;
  }
}

class _TransactionCard extends StatelessWidget {
  const _TransactionCard({required this.transaction, required this.category});

  final LedgerTransaction transaction;
  final TransactionCategory? category;

  @override
  Widget build(BuildContext context) {
    final inflow = transaction.effect == TransactionEffect.inflow;
    final neutral = !transaction.type.isSpending && !transaction.type.isIncome;
    final color = neutral
        ? Theme.of(context).colorScheme.primary
        : inflow
        ? Colors.green.shade700
        : Theme.of(context).colorScheme.error;
    return Card(
      margin: const EdgeInsets.only(bottom: PlanItSpacing.sm),
      child: InkWell(
        borderRadius: BorderRadius.circular(PlanItRadius.md),
        onTap: () => context.push('/transactions/${transaction.id}'),
        child: Padding(
          padding: const EdgeInsets.all(PlanItSpacing.md),
          child: Row(
            children: <Widget>[
              CircleAvatar(
                backgroundColor: color.withValues(alpha: 0.12),
                child: Icon(_iconFor(transaction), color: color),
              ),
              const SizedBox(width: PlanItSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      transaction.counterparty ??
                          category?.name ??
                          transaction.type.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: PlanItSpacing.xxs),
                    Wrap(
                      spacing: PlanItSpacing.xs,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: <Widget>[
                        Text(_formatDate(transaction.occurredAt)),
                        _CompactStatus(transaction: transaction),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: PlanItSpacing.sm),
              Text(
                '${inflow ? '+' : '-'}${transaction.amount.toDisplayString()}',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _formatDate(DateTime value) {
    final local = value.toLocal();
    return '${local.year}-${local.month.toString().padLeft(2, '0')}-'
        '${local.day.toString().padLeft(2, '0')}';
  }

  static IconData _iconFor(LedgerTransaction transaction) {
    return switch (transaction.type) {
      TransactionType.transferOut ||
      TransactionType.transferIn => Icons.swap_horiz_rounded,
      TransactionType.transferFee => Icons.receipt_long_outlined,
      TransactionType.reconciliationAdjustment => Icons.fact_check_outlined,
      TransactionType.reversal => Icons.undo_rounded,
      _ =>
        transaction.effect == TransactionEffect.inflow
            ? Icons.arrow_downward_rounded
            : Icons.arrow_upward_rounded,
    };
  }
}

class _CompactStatus extends StatelessWidget {
  const _CompactStatus({required this.transaction});

  final LedgerTransaction transaction;

  @override
  Widget build(BuildContext context) {
    final pending = transaction.syncState != LocalTransactionSyncState.synced;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: pending
            ? Theme.of(context).colorScheme.secondaryContainer
            : Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        child: Text(
          pending ? transaction.syncState.label : transaction.status.label,
          style: Theme.of(context).textTheme.labelSmall,
        ),
      ),
    );
  }
}

class _EmptyActivity extends StatelessWidget {
  const _EmptyActivity({required this.hasTransactions});

  final bool hasTransactions;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(PlanItSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(Icons.receipt_long_outlined, size: 64),
            const SizedBox(height: PlanItSpacing.md),
            Text(
              hasTransactions ? 'No matching activity' : 'No transactions yet',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: PlanItSpacing.xs),
            Text(
              hasTransactions
                  ? 'Try another filter or search.'
                  : 'Use the Add button to record an expense or income.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _SyncBanner extends StatelessWidget {
  const _SyncBanner({required this.message, this.error = false});

  final String message;
  final bool error;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: error ? scheme.errorContainer : scheme.secondaryContainer,
        borderRadius: BorderRadius.circular(PlanItRadius.sm),
      ),
      child: Padding(
        padding: const EdgeInsets.all(PlanItSpacing.sm),
        child: Row(
          children: <Widget>[
            Icon(error ? Icons.error_outline : Icons.cloud_sync_outlined),
            const SizedBox(width: PlanItSpacing.xs),
            Expanded(child: Text(message)),
          ],
        ),
      ),
    );
  }
}
