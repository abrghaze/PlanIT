import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:planit_mobile/core/design_system/tokens.dart';
import 'package:planit_mobile/core/money/money_format.dart';
import 'package:planit_mobile/features/accounts/application/providers.dart';
import 'package:planit_mobile/features/accounts/domain/account.dart';
import 'package:planit_mobile/features/transactions/application/providers.dart';
import 'package:planit_mobile/features/transactions/application/transaction_controller.dart';
import 'package:planit_mobile/features/transactions/domain/catalog.dart';
import 'package:planit_mobile/features/transactions/domain/transaction.dart';
import 'package:uuid/uuid.dart';

class TransactionDetailScreen extends ConsumerWidget {
  const TransactionDetailScreen({required this.transactionId, super.key});

  final String transactionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final values =
        ref.watch(transactionsProvider).value ?? const <LedgerTransaction>[];
    final transaction = values
        .where((value) => value.id == transactionId)
        .firstOrNull;
    if (transaction == null) {
      return const Scaffold(
        body: Center(child: Text('This transaction is not available locally.')),
      );
    }
    final accounts = ref.watch(accountsProvider).value ?? const <Account>[];
    final categories =
        ref.watch(transactionCategoriesProvider).value ??
        const <TransactionCategory>[];
    final tags =
        ref.watch(transactionTagsProvider).value ?? const <TransactionTag>[];
    final action = ref.watch(transactionControllerProvider);
    final account = accounts
        .where((value) => value.id == transaction.accountId)
        .firstOrNull;
    final category = categories
        .where((value) => value.id == transaction.categoryId)
        .firstOrNull;
    final transactionTags = tags
        .where((tag) => transaction.tagIds.contains(tag.id))
        .toList(growable: false);
    final synchronized =
        transaction.syncState == LocalTransactionSyncState.synced;
    final classificationReady =
        category?.active == true &&
        transactionTags.length == transaction.tagIds.length &&
        transactionTags.every((tag) => tag.active);

    return Scaffold(
      appBar: AppBar(title: const Text('Transaction')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          PlanItSpacing.lg,
          PlanItSpacing.md,
          PlanItSpacing.lg,
          PlanItSpacing.xxl,
        ),
        children: <Widget>[
          Card(
            child: Padding(
              padding: const EdgeInsets.all(PlanItSpacing.lg),
              child: Column(
                children: <Widget>[
                  Icon(
                    transaction.effect == TransactionEffect.inflow
                        ? Icons.arrow_downward_rounded
                        : Icons.arrow_upward_rounded,
                    size: 36,
                  ),
                  const SizedBox(height: PlanItSpacing.sm),
                  Text(
                    transaction.type.label,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: PlanItSpacing.xs),
                  Text(
                    transaction.amount.toDisplayString(),
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: PlanItSpacing.sm),
                  Wrap(
                    spacing: PlanItSpacing.xs,
                    children: <Widget>[
                      Chip(label: Text(transaction.status.label)),
                      Chip(
                        avatar: Icon(
                          synchronized
                              ? Icons.cloud_done_outlined
                              : Icons.cloud_upload_outlined,
                          size: 18,
                        ),
                        label: Text(transaction.syncState.label),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (!synchronized) ...<Widget>[
            const SizedBox(height: PlanItSpacing.sm),
            _Notice(
              message:
                  transaction.lastSyncError ??
                  'Pending server acknowledgment. Cached account balances are unchanged until posting succeeds.',
              error:
                  transaction.syncState == LocalTransactionSyncState.conflict,
            ),
          ],
          if (action.errorMessage != null) ...<Widget>[
            const SizedBox(height: PlanItSpacing.sm),
            _Notice(message: action.errorMessage!, error: true),
          ],
          const SizedBox(height: PlanItSpacing.lg),
          _DetailRow(
            label: 'Account',
            value: account?.name ?? 'Unknown account',
          ),
          if (transaction.type == TransactionType.expense ||
              transaction.type == TransactionType.income)
            _DetailRow(
              label: 'Category',
              value: category?.name ?? 'Uncategorized',
            )
          else
            _DetailRow(
              label: 'Impact',
              value: transaction.type.isSpending
                  ? 'Counts as spending'
                  : 'Balance movement (neutral to income and spending)',
            ),
          _DetailRow(
            label: _counterpartyLabel(transaction.type),
            value: transaction.counterparty ?? 'Not specified',
          ),
          _DetailRow(
            label: 'Occurred',
            value: _formatTimestamp(transaction.occurredAt),
          ),
          if (transaction.note != null)
            _DetailRow(label: 'Note', value: transaction.note!),
          if (transactionTags.isNotEmpty) ...<Widget>[
            const SizedBox(height: PlanItSpacing.sm),
            Text('Tags', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: PlanItSpacing.xs),
            Wrap(
              spacing: PlanItSpacing.xs,
              children: transactionTags
                  .map((tag) => Chip(label: Text(tag.name)))
                  .toList(growable: false),
            ),
          ],
          if (transaction.reversalOfId != null)
            _DetailRow(label: 'Reverses', value: transaction.reversalOfId!),
          const SizedBox(height: PlanItSpacing.xl),
          if (transaction.status == TransactionStatus.draft &&
              synchronized) ...<Widget>[
            if (!classificationReady) ...<Widget>[
              const _Notice(
                message:
                    'Choose an active category and remove archived tags before posting.',
                error: true,
              ),
              const SizedBox(height: PlanItSpacing.sm),
            ],
            OutlinedButton.icon(
              onPressed: action.busy
                  ? null
                  : () => context.push('/transactions/$transactionId/edit'),
              icon: const Icon(Icons.edit_outlined),
              label: const Text('Edit draft'),
            ),
            const SizedBox(height: PlanItSpacing.sm),
            FilledButton.icon(
              onPressed: action.busy || !classificationReady
                  ? null
                  : () => _post(context, ref, transaction),
              icon: const Icon(Icons.check_circle_outline),
              label: const Text('Post transaction'),
            ),
          ],
          if (transaction.status == TransactionStatus.posted &&
              synchronized &&
              transaction.type.supportsGenericReversal)
            OutlinedButton.icon(
              onPressed: action.busy
                  ? null
                  : () => _reverse(context, ref, transaction),
              icon: const Icon(Icons.undo_rounded),
              label: const Text('Reverse transaction'),
            ),
          if (transaction.status == TransactionStatus.posted &&
              synchronized &&
              !transaction.type.supportsGenericReversal)
            const _Notice(
              message:
                  'This movement belongs to a grouped financial operation and cannot be reversed by itself.',
            ),
          if (!synchronized)
            FilledButton.tonalIcon(
              onPressed: action.syncing
                  ? null
                  : () => ref
                        .read(transactionControllerProvider.notifier)
                        .refresh(force: true),
              icon: const Icon(Icons.sync_rounded),
              label: const Text('Retry synchronization'),
            ),
          if (transaction.syncState ==
              LocalTransactionSyncState.conflict) ...<Widget>[
            const SizedBox(height: PlanItSpacing.sm),
            OutlinedButton.icon(
              onPressed: action.busy
                  ? null
                  : () => _discardConflict(context, ref, transaction),
              icon: const Icon(Icons.delete_outline_rounded),
              label: const Text('Discard local change & reload'),
            ),
          ],
        ],
      ),
    );
  }

  static Future<void> _post(
    BuildContext context,
    WidgetRef ref,
    LedgerTransaction transaction,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Post this transaction?'),
        content: const Text(
          'Posting changes the account balance. Financial fields become immutable and corrections use a reversal.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Post'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) {
      return;
    }
    await ref
        .read(transactionControllerProvider.notifier)
        .post(current: transaction, operationId: const Uuid().v4());
  }

  static Future<void> _reverse(
    BuildContext context,
    WidgetRef ref,
    LedgerTransaction transaction,
  ) async {
    final noteController = TextEditingController();
    final note = await showDialog<String?>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reverse transaction?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Text(
              'The original remains in history and a linked opposite movement restores its effect.',
            ),
            const SizedBox(height: PlanItSpacing.md),
            TextField(
              controller: noteController,
              maxLength: 2000,
              decoration: const InputDecoration(labelText: 'Reason (optional)'),
            ),
          ],
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(noteController.text),
            child: const Text('Reverse'),
          ),
        ],
      ),
    );
    noteController.dispose();
    if (note == null || !context.mounted) {
      return;
    }
    final operationId = const Uuid().v4();
    await ref
        .read(transactionControllerProvider.notifier)
        .reverse(
          current: transaction,
          reversal: TransactionReversalDraft(
            id: const Uuid().v4(),
            clientOperationId: operationId,
            version: transaction.version,
            occurredAt: DateTime.now().toUtc(),
            note: note.trim().isEmpty ? null : note.trim(),
          ),
        );
  }

  static Future<void> _discardConflict(
    BuildContext context,
    WidgetRef ref,
    LedgerTransaction transaction,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Discard local change?'),
        content: const Text(
          'The pending local operation will be removed and the latest server state will be loaded. An unsynchronized new draft may be lost.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Discard & reload'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) {
      return;
    }
    await ref
        .read(transactionControllerProvider.notifier)
        .discardConflict(transaction);
  }

  static String _formatTimestamp(DateTime value) {
    final local = value.toLocal();
    return '${local.year}-${local.month.toString().padLeft(2, '0')}-'
        '${local.day.toString().padLeft(2, '0')} '
        '${local.hour.toString().padLeft(2, '0')}:'
        '${local.minute.toString().padLeft(2, '0')}';
  }

  static String _counterpartyLabel(TransactionType type) => switch (type) {
    TransactionType.expense => 'Merchant',
    TransactionType.income => 'Source',
    TransactionType.transferOut => 'Destination',
    TransactionType.transferIn => 'Source account',
    TransactionType.transferFee => 'Fee charged by',
    TransactionType.reconciliationAdjustment => 'Adjustment',
    _ => 'Counterparty',
  };
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: PlanItSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 96,
            child: Text(label, style: Theme.of(context).textTheme.labelLarge),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({required this.message, this.error = false});

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
        child: Text(message),
      ),
    );
  }
}
