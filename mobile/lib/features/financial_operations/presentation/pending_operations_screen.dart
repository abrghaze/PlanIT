import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:planit_mobile/core/design_system/tokens.dart';
import 'package:planit_mobile/features/financial_operations/application/financial_operation_controller.dart';
import 'package:planit_mobile/features/financial_operations/application/providers.dart';
import 'package:planit_mobile/features/transactions/application/transaction_controller.dart';
import 'package:planit_mobile/features/transactions/domain/outbox_operation.dart';

class PendingOperationsScreen extends ConsumerWidget {
  const PendingOperationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final operations = ref.watch(pendingOperationsProvider);
    final sync = ref.watch(transactionControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pending operations'),
        actions: <Widget>[
          IconButton(
            tooltip: 'Retry eligible operations',
            onPressed: sync.syncing
                ? null
                : () => ref
                      .read(financialOperationControllerProvider.notifier)
                      .retryPending(),
            icon: sync.syncing
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.sync_rounded),
          ),
        ],
      ),
      body: operations.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => const Center(
          child: Text('Pending operations could not be loaded.'),
        ),
        data: (items) {
          if (items.isEmpty) {
            return const _EmptyPendingOperations();
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(
              PlanItSpacing.lg,
              PlanItSpacing.md,
              PlanItSpacing.lg,
              PlanItSpacing.xxl,
            ),
            children: <Widget>[
              const _QueueNotice(),
              if (sync.errorMessage != null) ...<Widget>[
                const SizedBox(height: PlanItSpacing.sm),
                _ErrorNotice(message: sync.errorMessage!),
              ],
              const SizedBox(height: PlanItSpacing.md),
              for (var index = 0; index < items.length; index += 1) ...<Widget>[
                _PendingOperationCard(
                  operation: items[index],
                  waitingBehindConflict:
                      index > 0 &&
                      items
                          .take(index)
                          .any(
                            (item) =>
                                item.state == OutboxOperationState.conflict,
                          ),
                  onRetry: () => ref
                      .read(financialOperationControllerProvider.notifier)
                      .retryPending(),
                  onReview: () => _review(context, ref, items[index]),
                  onDiscard: () => _discard(context, ref, items[index]),
                ),
                const SizedBox(height: PlanItSpacing.sm),
              ],
            ],
          );
        },
      ),
    );
  }

  static Future<void> _review(
    BuildContext context,
    WidgetRef ref,
    PendingOperation operation,
  ) async {
    if (!operation.type.isSpecializedFinancialCommit) {
      await context.push('/transactions/${operation.entityId}');
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create a fresh preview?'),
        content: const Text(
          'The saved fingerprint is stale or invalid. The conflicted operation will be removed, then you can review current server balances and confirm a new operation.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Re-preview'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) {
      return;
    }
    final discarded = await ref
        .read(financialOperationControllerProvider.notifier)
        .discardPending(operation);
    if (!discarded || !context.mounted) {
      return;
    }
    await context.push(_routeFor(operation.type));
  }

  static Future<void> _discard(
    BuildContext context,
    WidgetRef ref,
    PendingOperation operation,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Discard ${operation.label.toLowerCase()}?'),
        content: const Text(
          'Only the local pending work is removed. Server-acknowledged ledger rows are never deleted.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Keep'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
    if (confirmed != true) {
      return;
    }
    await ref
        .read(financialOperationControllerProvider.notifier)
        .discardPending(operation);
  }

  static String _routeFor(OutboxOperationType type) => switch (type) {
    OutboxOperationType.transferCommit => '/transfers/new',
    OutboxOperationType.reconciliationCommit => '/reconciliations/new',
    OutboxOperationType.reallocationCommit => '/reallocations/new',
    _ => '/activity',
  };
}

class _PendingOperationCard extends StatelessWidget {
  const _PendingOperationCard({
    required this.operation,
    required this.waitingBehindConflict,
    required this.onRetry,
    required this.onReview,
    required this.onDiscard,
  });

  final PendingOperation operation;
  final bool waitingBehindConflict;
  final VoidCallback onRetry;
  final VoidCallback onReview;
  final VoidCallback onDiscard;

  @override
  Widget build(BuildContext context) {
    final conflict = operation.state == OutboxOperationState.conflict;
    final retry = operation.state == OutboxOperationState.retry;
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(PlanItSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                CircleAvatar(
                  backgroundColor: conflict
                      ? scheme.errorContainer
                      : scheme.secondaryContainer,
                  child: Icon(_iconFor(operation.type)),
                ),
                const SizedBox(width: PlanItSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        operation.label,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      Text(
                        '${operation.stateLabel} · attempt ${operation.attemptCount + 1}',
                      ),
                    ],
                  ),
                ),
                Chip(label: Text(operation.stateLabel)),
              ],
            ),
            if (operation.lastError != null) ...<Widget>[
              const SizedBox(height: PlanItSpacing.sm),
              Text(
                operation.lastError!,
                style: TextStyle(color: conflict ? scheme.error : null),
              ),
            ],
            if (waitingBehindConflict) ...<Widget>[
              const SizedBox(height: PlanItSpacing.xs),
              const Text(
                'Waiting: an earlier conflict must be reviewed first.',
              ),
            ],
            const SizedBox(height: PlanItSpacing.sm),
            Wrap(
              spacing: PlanItSpacing.sm,
              runSpacing: PlanItSpacing.xs,
              children: <Widget>[
                if (conflict)
                  FilledButton.tonalIcon(
                    onPressed: onReview,
                    icon: const Icon(Icons.fact_check_outlined),
                    label: const Text('Review'),
                  )
                else if (retry ||
                    operation.state == OutboxOperationState.pending)
                  FilledButton.tonalIcon(
                    onPressed: waitingBehindConflict ? null : onRetry,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Retry now'),
                  ),
                OutlinedButton.icon(
                  onPressed: operation.state.canDiscard ? onDiscard : null,
                  icon: const Icon(Icons.delete_outline_rounded),
                  label: const Text('Discard'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static IconData _iconFor(OutboxOperationType type) => switch (type) {
    OutboxOperationType.transferCommit => Icons.swap_horiz_rounded,
    OutboxOperationType.reconciliationCommit => Icons.fact_check_outlined,
    OutboxOperationType.reallocationCommit => Icons.balance_rounded,
    OutboxOperationType.reverse => Icons.undo_rounded,
    OutboxOperationType.post => Icons.check_circle_outline,
    OutboxOperationType.createDraft ||
    OutboxOperationType.updateDraft => Icons.receipt_long_outlined,
  };
}

class _QueueNotice extends StatelessWidget {
  const _QueueNotice();

  @override
  Widget build(BuildContext context) {
    return const _NoticeShell(
      icon: Icons.lock_clock_outlined,
      message:
          'Operations are processed in order. Cached account balances remain unchanged until the server acknowledges canonical ledger rows.',
    );
  }
}

class _ErrorNotice extends StatelessWidget {
  const _ErrorNotice({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return _NoticeShell(
      icon: Icons.error_outline,
      message: message,
      error: true,
    );
  }
}

class _NoticeShell extends StatelessWidget {
  const _NoticeShell({
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
    return DecoratedBox(
      decoration: BoxDecoration(
        color: error ? scheme.errorContainer : scheme.secondaryContainer,
        borderRadius: BorderRadius.circular(PlanItRadius.sm),
      ),
      child: Padding(
        padding: const EdgeInsets.all(PlanItSpacing.sm),
        child: Row(
          children: <Widget>[
            Icon(icon),
            const SizedBox(width: PlanItSpacing.sm),
            Expanded(child: Text(message)),
          ],
        ),
      ),
    );
  }
}

class _EmptyPendingOperations extends StatelessWidget {
  const _EmptyPendingOperations();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(PlanItSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(Icons.cloud_done_outlined, size: 64),
            SizedBox(height: PlanItSpacing.md),
            Text('Everything is synchronized'),
            SizedBox(height: PlanItSpacing.xs),
            Text(
              'There are no local operations waiting for acknowledgment.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
