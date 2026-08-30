import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:planit_mobile/core/database/app_database.dart';
import 'package:planit_mobile/core/money/money.dart';
import 'package:planit_mobile/features/transactions/domain/outbox_operation.dart';
import 'package:planit_mobile/features/transactions/domain/transaction.dart';

final class TransactionsLocalDataSource {
  const TransactionsLocalDataSource(this._database);

  final AppDatabase _database;

  Stream<List<LedgerTransaction>> watch(String ownerId) {
    return _database.watchTransactions(ownerId).asyncMap((rows) async {
      final tagRows = await _database.readTransactionTags(
        ownerId,
        rows.map((row) => row.id),
      );
      final tags = <String, List<String>>{};
      for (final row in tagRows) {
        tags.putIfAbsent(row.transactionId, () => <String>[]).add(row.tagId);
      }
      return rows
          .map((row) => _fromRow(row, tags[row.id] ?? const <String>[]))
          .toList(growable: false);
    });
  }

  Stream<List<PendingOperation>> watchPendingOperations(String ownerId) {
    return _database
        .watchOutboxOperations(ownerId)
        .map((rows) => rows.map(_fromOperationRow).toList(growable: false));
  }

  Future<void> queueCreate({
    required String ownerId,
    required TransactionDraft draft,
    required bool postAfterCreate,
    required String? postOperationId,
  }) {
    if (postAfterCreate && postOperationId == null) {
      throw ArgumentError.notNull('postOperationId');
    }
    var pending = draft.toPendingTransaction(ownerId: ownerId);
    if (postAfterCreate) {
      pending = pending.copyWith(pendingAction: 'POST');
    }
    final now = DateTime.now().toUtc();
    final operations = <OutboxOperationsCompanion>[
      _operationCompanion(
        id: draft.clientOperationId,
        ownerId: ownerId,
        entityId: draft.id,
        type: OutboxOperationType.createDraft,
        payload: draft.toJson(),
        createdAt: now,
      ),
      if (postAfterCreate)
        _operationCompanion(
          id: postOperationId!,
          ownerId: ownerId,
          entityId: draft.id,
          type: OutboxOperationType.post,
          payload: const <String, Object?>{'version': 1},
          createdAt: now.add(const Duration(microseconds: 1)),
        ),
    ];
    return _database.saveTransactionWithOperations(
      transactionRow: _toCompanion(pending, now),
      ownerId: ownerId,
      transactionId: pending.id,
      tagIds: pending.tagIds,
      operations: operations,
    );
  }

  Future<void> queueUpdate({
    required LedgerTransaction current,
    required TransactionEdit edit,
    required String operationId,
  }) {
    _requireSyncedDraft(current);
    final pending = edit.applyTo(current, pendingAction: 'UPDATE_DRAFT');
    final now = DateTime.now().toUtc();
    return _database.saveTransactionWithOperations(
      transactionRow: _toCompanion(pending, now),
      ownerId: current.ownerId,
      transactionId: current.id,
      tagIds: pending.tagIds,
      operations: <OutboxOperationsCompanion>[
        _operationCompanion(
          id: operationId,
          ownerId: current.ownerId,
          entityId: current.id,
          type: OutboxOperationType.updateDraft,
          payload: edit.toJson(),
          createdAt: now,
        ),
      ],
    );
  }

  Future<void> queuePost({
    required LedgerTransaction current,
    required String operationId,
  }) {
    _requireSyncedDraft(current);
    final now = DateTime.now().toUtc();
    final pending = current.copyWith(
      syncState: LocalTransactionSyncState.pending,
      pendingAction: 'POST',
      clearSyncError: true,
    );
    return _database.saveTransactionWithOperations(
      transactionRow: _toCompanion(pending, now),
      ownerId: current.ownerId,
      transactionId: current.id,
      tagIds: current.tagIds,
      operations: <OutboxOperationsCompanion>[
        _operationCompanion(
          id: operationId,
          ownerId: current.ownerId,
          entityId: current.id,
          type: OutboxOperationType.post,
          payload: <String, Object?>{'version': current.version},
          createdAt: now,
        ),
      ],
    );
  }

  Future<void> queueReversal({
    required LedgerTransaction current,
    required TransactionReversalDraft reversal,
  }) {
    if (current.syncState != LocalTransactionSyncState.synced ||
        current.status != TransactionStatus.posted ||
        !current.type.supportsGenericReversal) {
      throw StateError(
        'Only a synchronized posted expense or income can use generic reversal.',
      );
    }
    final now = DateTime.now().toUtc();
    final pending = current.copyWith(
      syncState: LocalTransactionSyncState.pending,
      pendingAction: 'REVERSE',
      clearSyncError: true,
    );
    return _database.saveTransactionWithOperations(
      transactionRow: _toCompanion(pending, now),
      ownerId: current.ownerId,
      transactionId: current.id,
      tagIds: current.tagIds,
      operations: <OutboxOperationsCompanion>[
        _operationCompanion(
          id: reversal.clientOperationId,
          ownerId: current.ownerId,
          entityId: current.id,
          type: OutboxOperationType.reverse,
          payload: reversal.toJson(),
          createdAt: now,
        ),
      ],
    );
  }

  Future<void> queueFinancialOperation({
    required String ownerId,
    required String operationId,
    required String entityId,
    required OutboxOperationType type,
    required Map<String, Object?> payload,
  }) {
    if (!type.isSpecializedFinancialCommit) {
      throw ArgumentError.value(
        type,
        'type',
        'Only specialized financial commits can use this queue.',
      );
    }
    if (ownerId.isEmpty || operationId.isEmpty || entityId.isEmpty) {
      throw ArgumentError('Owner, operation, and entity IDs are required.');
    }
    if (payload['client_operation_id'] != operationId) {
      throw ArgumentError(
        'Payload client_operation_id must match the outbox operation ID.',
      );
    }
    if (payload['id'] != entityId) {
      throw ArgumentError('Payload id must match the outbox entity ID.');
    }
    final now = DateTime.now().toUtc();
    return _database.queueOutboxOperation(
      _operationCompanion(
        id: operationId,
        ownerId: ownerId,
        entityId: entityId,
        type: type,
        payload: Map<String, Object?>.from(payload),
        createdAt: now,
      ),
    );
  }

  Future<void> mergeRemote(
    String ownerId,
    List<LedgerTransaction> transactions,
  ) {
    if (transactions.any((value) => value.ownerId != ownerId)) {
      throw ArgumentError('Remote transactions belong to another owner.');
    }
    final now = DateTime.now().toUtc();
    return _database.mergeRemoteTransactions(
      ownerId: ownerId,
      transactionRows: transactions
          .map((value) => _toCompanion(value, now))
          .toList(growable: false),
      tagIdsByTransaction: <String, List<String>>{
        for (final value in transactions) value.id: value.tagIds,
      },
    );
  }

  Future<PendingOperation?> readNextOperation(
    String ownerId, {
    bool force = false,
  }) async {
    final row = await _database.readNextOperation(
      ownerId,
      now: DateTime.now().toUtc(),
      force: force,
    );
    if (row == null) {
      return null;
    }
    return _fromOperationRow(row);
  }

  Stream<int> watchPendingCount(String ownerId) {
    return _database.watchPendingOperationCount(ownerId);
  }

  Future<void> markSending(PendingOperation operation) {
    return _database.markOperationSending(_operationRow(operation));
  }

  Future<void> markFailure({
    required PendingOperation operation,
    required String error,
    required bool conflict,
  }) {
    final exponent = operation.attemptCount.clamp(0, 8);
    final delaySeconds = 1 << exponent;
    return _database.markOperationFailed(
      operation: _operationRow(operation),
      error: error,
      nextAttemptAt: DateTime.now().toUtc().add(
        Duration(seconds: delaySeconds),
      ),
      conflict: conflict,
    );
  }

  Future<void> acknowledge({
    required PendingOperation operation,
    required List<LedgerTransaction> transactions,
  }) {
    if (transactions.any((value) => value.ownerId != operation.ownerId)) {
      throw ArgumentError(
        'Canonical transactions must belong to the operation owner.',
      );
    }
    final now = DateTime.now().toUtc();
    return _database.acknowledgeOperation(
      operation: _operationRow(operation),
      canonicalRows: transactions
          .map((value) => _toCompanion(value, now))
          .toList(growable: false),
      tagIdsByTransaction: <String, List<String>>{
        for (final value in transactions) value.id: value.tagIds,
      },
    );
  }

  Future<void> discardPendingOperation(PendingOperation operation) {
    if (!operation.state.canDiscard) {
      throw StateError('An operation cannot be discarded while it is syncing.');
    }
    if (operation.type.isSpecializedFinancialCommit) {
      return _database.discardOutboxOperation(
        ownerId: operation.ownerId,
        operationId: operation.id,
        entityId: operation.entityId,
      );
    }
    return _database.discardEntityOperations(
      ownerId: operation.ownerId,
      entityId: operation.entityId,
    );
  }

  Future<void> discardPending(LedgerTransaction transaction) {
    if (transaction.syncState != LocalTransactionSyncState.conflict) {
      throw StateError('Only a conflicted transaction can be discarded.');
    }
    return _database.discardEntityOperations(
      ownerId: transaction.ownerId,
      entityId: transaction.id,
    );
  }

  static CachedTransactionsCompanion _toCompanion(
    LedgerTransaction value,
    DateTime cachedAt,
  ) {
    return CachedTransactionsCompanion(
      id: Value(value.id),
      ownerId: Value(value.ownerId),
      accountId: Value(value.accountId),
      type: Value(value.type.apiValue),
      effect: Value(value.effect.apiValue),
      amount: Value(value.amount.toApiString()),
      currency: Value(value.amount.currency),
      occurredAt: Value(value.occurredAt.toUtc()),
      status: Value(value.status.apiValue),
      categoryId: Value(value.categoryId),
      merchantId: Value(value.merchantId),
      merchantLocationId: Value(value.merchantLocationId),
      itemsJson: Value(
        jsonEncode(value.items.map((item) => item.toCacheJson()).toList()),
      ),
      counterparty: Value(value.counterparty),
      note: Value(value.note),
      parentTransactionId: Value(value.parentTransactionId),
      reversalOfId: Value(value.reversalOfId),
      clientOperationId: Value(value.clientOperationId),
      version: Value(value.version),
      createdAt: Value(value.createdAt.toUtc()),
      updatedAt: Value(value.updatedAt.toUtc()),
      cachedAt: Value(cachedAt),
      syncState: Value(value.syncState.storageValue),
      pendingAction: Value(value.pendingAction),
      lastSyncError: Value(value.lastSyncError),
    );
  }

  static LedgerTransaction _fromRow(
    CachedTransaction row,
    List<String> tagIds,
  ) {
    return LedgerTransaction(
      id: row.id,
      ownerId: row.ownerId,
      accountId: row.accountId,
      type: TransactionTypeContract.fromApi(row.type),
      effect: TransactionEffectContract.fromApi(row.effect),
      amount: Money.parse(row.amount, row.currency),
      occurredAt: row.occurredAt.toUtc(),
      status: TransactionStatusContract.fromApi(row.status),
      categoryId: row.categoryId,
      merchantId: row.merchantId,
      merchantLocationId: row.merchantLocationId,
      counterparty: row.counterparty,
      note: row.note,
      tagIds: List<String>.unmodifiable(tagIds),
      items: (jsonDecode(row.itemsJson) as List)
          .asMap()
          .entries
          .map((entry) {
            final json = Map<String, Object?>.from(entry.value as Map);
            final quantity = '${json['quantity']}';
            final unitPrice = '${json['unit_price']}';
            final discount = '${json['discount']}';
            final lineTotal =
                (double.parse(quantity) * double.parse(unitPrice) -
                        double.parse(discount))
                    .toStringAsFixed(4);
            return PurchaseItem(
              id: json['id']! as String,
              productId: json['product_id'] as String?,
              description: json['description']! as String,
              quantity: quantity,
              unitPrice: unitPrice,
              discount: discount,
              lineTotal: '${json['line_total'] ?? lineTotal}',
              position: json['position'] as int? ?? entry.key,
            );
          })
          .toList(growable: false),
      parentTransactionId: row.parentTransactionId,
      reversalOfId: row.reversalOfId,
      clientOperationId: row.clientOperationId,
      version: row.version,
      createdAt: row.createdAt.toUtc(),
      updatedAt: row.updatedAt.toUtc(),
      syncState: LocalTransactionSyncStateContract.fromStorage(row.syncState),
      pendingAction: row.pendingAction,
      lastSyncError: row.lastSyncError,
    );
  }

  static OutboxOperationsCompanion _operationCompanion({
    required String id,
    required String ownerId,
    required String entityId,
    required OutboxOperationType type,
    required Map<String, Object?> payload,
    required DateTime createdAt,
  }) {
    return OutboxOperationsCompanion.insert(
      id: id,
      ownerId: ownerId,
      entityId: entityId,
      type: type.storageValue,
      payloadJson: jsonEncode(payload),
      state: 'PENDING',
      attemptCount: 0,
      nextAttemptAt: createdAt,
      createdAt: createdAt,
      updatedAt: createdAt,
    );
  }

  static OutboxOperation _operationRow(PendingOperation value) {
    return OutboxOperation(
      id: value.id,
      ownerId: value.ownerId,
      entityId: value.entityId,
      type: value.type.storageValue,
      payloadJson: jsonEncode(value.payload),
      state: value.state.storageValue,
      attemptCount: value.attemptCount,
      nextAttemptAt: value.nextAttemptAt,
      lastError: value.lastError,
      createdAt: value.createdAt,
      updatedAt: value.createdAt,
    );
  }

  static void _requireSyncedDraft(LedgerTransaction current) {
    if (current.syncState != LocalTransactionSyncState.synced ||
        current.status != TransactionStatus.draft) {
      throw StateError('Only a synchronized draft can be changed.');
    }
  }

  static PendingOperation _fromOperationRow(OutboxOperation row) {
    final decoded = jsonDecode(row.payloadJson);
    if (decoded is! Map) {
      throw const FormatException('Outbox payload must be a JSON object.');
    }
    return PendingOperation(
      id: row.id,
      ownerId: row.ownerId,
      entityId: row.entityId,
      type: OutboxOperationTypeContract.fromStorage(row.type),
      state: OutboxOperationStateContract.fromStorage(row.state),
      payload: Map<String, Object?>.unmodifiable(
        Map<String, Object?>.from(decoded),
      ),
      attemptCount: row.attemptCount,
      nextAttemptAt: row.nextAttemptAt.toUtc(),
      lastError: row.lastError,
      createdAt: row.createdAt.toUtc(),
    );
  }
}
