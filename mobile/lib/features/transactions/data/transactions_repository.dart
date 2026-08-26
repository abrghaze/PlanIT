import 'package:planit_mobile/core/errors/app_exception.dart';
import 'package:planit_mobile/features/transactions/data/transactions_local_data_source.dart';
import 'package:planit_mobile/features/transactions/data/transactions_remote_data_source.dart';
import 'package:planit_mobile/features/transactions/domain/outbox_operation.dart';
import 'package:planit_mobile/features/transactions/domain/transaction.dart';

final class TransactionSyncResult {
  const TransactionSyncResult({
    required this.processed,
    required this.blocked,
    this.message,
  });

  final int processed;
  final bool blocked;
  final String? message;
}

abstract interface class TransactionsRepository {
  Stream<List<LedgerTransaction>> watch(String ownerId);

  Stream<int> watchPendingCount(String ownerId);

  Future<void> refresh({required String ownerId, required String accessToken});

  Future<void> queueCreate({
    required String ownerId,
    required TransactionDraft draft,
    required bool postAfterCreate,
    required String? postOperationId,
  });

  Future<void> queueUpdate({
    required LedgerTransaction current,
    required TransactionEdit edit,
    required String operationId,
  });

  Future<void> queuePost({
    required LedgerTransaction current,
    required String operationId,
  });

  Future<void> queueReversal({
    required LedgerTransaction current,
    required TransactionReversalDraft reversal,
  });

  Future<void> discardPending(LedgerTransaction transaction);

  Future<TransactionSyncResult> synchronize({
    required String ownerId,
    required String accessToken,
    bool force,
  });
}

abstract interface class FinancialOperationsOutboxRepository {
  Stream<List<PendingOperation>> watchPendingOperations(String ownerId);

  Future<void> queueFinancialOperation({
    required String ownerId,
    required String operationId,
    required String entityId,
    required OutboxOperationType type,
    required Map<String, Object?> payload,
  });

  Future<void> discardPendingOperation(PendingOperation operation);
}

extension TransactionsRepositoryFinancialOperations on TransactionsRepository {
  Stream<List<PendingOperation>> watchPendingOperations(String ownerId) {
    return _financialOperations.watchPendingOperations(ownerId);
  }

  Future<void> queueFinancialOperation({
    required String ownerId,
    required String operationId,
    required String entityId,
    required OutboxOperationType type,
    required Map<String, Object?> payload,
  }) {
    return _financialOperations.queueFinancialOperation(
      ownerId: ownerId,
      operationId: operationId,
      entityId: entityId,
      type: type,
      payload: payload,
    );
  }

  Future<void> discardPendingOperation(PendingOperation operation) {
    return _financialOperations.discardPendingOperation(operation);
  }

  FinancialOperationsOutboxRepository get _financialOperations {
    final repository = this;
    if (repository is FinancialOperationsOutboxRepository) {
      return repository as FinancialOperationsOutboxRepository;
    }
    throw UnsupportedError(
      'This transactions repository does not support financial operations.',
    );
  }
}

final class DefaultTransactionsRepository
    implements TransactionsRepository, FinancialOperationsOutboxRepository {
  DefaultTransactionsRepository({required this.remote, required this.local});

  final TransactionsRemoteDataSource remote;
  final TransactionsLocalDataSource local;
  Future<TransactionSyncResult>? _activeSynchronization;

  @override
  Stream<List<LedgerTransaction>> watch(String ownerId) => local.watch(ownerId);

  @override
  Stream<int> watchPendingCount(String ownerId) =>
      local.watchPendingCount(ownerId);

  @override
  Stream<List<PendingOperation>> watchPendingOperations(String ownerId) {
    return local.watchPendingOperations(ownerId);
  }

  @override
  Future<void> refresh({
    required String ownerId,
    required String accessToken,
  }) async {
    final values = await remote.fetchTransactions(
      ownerId: ownerId,
      accessToken: accessToken,
    );
    await local.mergeRemote(ownerId, values);
  }

  @override
  Future<void> queueCreate({
    required String ownerId,
    required TransactionDraft draft,
    required bool postAfterCreate,
    required String? postOperationId,
  }) {
    return local.queueCreate(
      ownerId: ownerId,
      draft: draft,
      postAfterCreate: postAfterCreate,
      postOperationId: postOperationId,
    );
  }

  @override
  Future<void> queueUpdate({
    required LedgerTransaction current,
    required TransactionEdit edit,
    required String operationId,
  }) {
    return local.queueUpdate(
      current: current,
      edit: edit,
      operationId: operationId,
    );
  }

  @override
  Future<void> queuePost({
    required LedgerTransaction current,
    required String operationId,
  }) {
    return local.queuePost(current: current, operationId: operationId);
  }

  @override
  Future<void> queueReversal({
    required LedgerTransaction current,
    required TransactionReversalDraft reversal,
  }) {
    return local.queueReversal(current: current, reversal: reversal);
  }

  @override
  Future<void> queueFinancialOperation({
    required String ownerId,
    required String operationId,
    required String entityId,
    required OutboxOperationType type,
    required Map<String, Object?> payload,
  }) {
    return local.queueFinancialOperation(
      ownerId: ownerId,
      operationId: operationId,
      entityId: entityId,
      type: type,
      payload: payload,
    );
  }

  @override
  Future<void> discardPending(LedgerTransaction transaction) {
    return local.discardPending(transaction);
  }

  @override
  Future<void> discardPendingOperation(PendingOperation operation) {
    return local.discardPendingOperation(operation);
  }

  @override
  Future<TransactionSyncResult> synchronize({
    required String ownerId,
    required String accessToken,
    bool force = false,
  }) {
    final active = _activeSynchronization;
    if (active != null) {
      return active;
    }
    final future = _synchronize(
      ownerId: ownerId,
      accessToken: accessToken,
      force: force,
    );
    _activeSynchronization = future;
    return future.whenComplete(() {
      if (identical(_activeSynchronization, future)) {
        _activeSynchronization = null;
      }
    });
  }

  Future<TransactionSyncResult> _synchronize({
    required String ownerId,
    required String accessToken,
    required bool force,
  }) async {
    var processed = 0;
    for (var index = 0; index < 50; index += 1) {
      final operation = await local.readNextOperation(ownerId, force: force);
      if (operation == null) {
        return TransactionSyncResult(processed: processed, blocked: false);
      }
      await local.markSending(operation);
      try {
        final result = await remote.execute(
          accessToken: accessToken,
          operation: operation,
        );
        await local.acknowledge(
          operation: operation,
          transactions: result.transactions,
        );
        processed += 1;
      } on AppException catch (error) {
        if (error.isAuthenticationFailure) {
          await local.markFailure(
            operation: operation,
            error: error.message,
            conflict: false,
          );
          rethrow;
        }
        final conflict =
            !error.isNetworkFailure &&
            (error.statusCode == 404 ||
                error.statusCode == 409 ||
                error.statusCode == 422);
        await local.markFailure(
          operation: operation,
          error: error.message,
          conflict: conflict,
        );
        return TransactionSyncResult(
          processed: processed,
          blocked: true,
          message: error.message,
        );
      } on Object {
        const message = 'PlanIT could not synchronize this operation.';
        await local.markFailure(
          operation: operation,
          error: message,
          conflict: false,
        );
        return TransactionSyncResult(
          processed: processed,
          blocked: true,
          message: message,
        );
      }
    }
    return TransactionSyncResult(
      processed: processed,
      blocked: true,
      message: 'Synchronization paused after 50 operations.',
    );
  }
}
