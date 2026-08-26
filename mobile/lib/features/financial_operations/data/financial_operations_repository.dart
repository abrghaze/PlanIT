import 'package:planit_mobile/features/financial_operations/data/financial_operations_remote_data_source.dart';
import 'package:planit_mobile/features/financial_operations/domain/financial_operation.dart';
import 'package:planit_mobile/features/transactions/data/transactions_repository.dart';
import 'package:planit_mobile/features/transactions/domain/outbox_operation.dart';

abstract interface class FinancialOperationsRepository {
  Future<TransferPreview> previewTransfer({
    required String accessToken,
    required TransferPreviewRequest request,
  });

  Future<void> queueTransfer({
    required String ownerId,
    required String operationId,
    required String transferId,
    required String sourceTransactionId,
    required String destinationTransactionId,
    required String? feeTransactionId,
    required TransferPreviewRequest request,
    required TransferPreview preview,
    required String? note,
  });

  Future<ReconciliationPreview> previewReconciliation({
    required String accessToken,
    required ReconciliationPreviewRequest request,
  });

  Future<void> queueReconciliation({
    required String ownerId,
    required String operationId,
    required String reconciliationId,
    required String adjustmentTransactionId,
    required ReconciliationPreviewRequest request,
    required ReconciliationPreview preview,
    required String? reason,
  });

  Future<ReallocationPreview> previewReallocation({
    required String accessToken,
    required ReallocationPreviewRequest request,
  });

  Future<void> queueReallocation({
    required String ownerId,
    required String operationId,
    required String reallocationId,
    required ReallocationPreviewRequest request,
    required ReallocationPreview preview,
    required String? note,
  });
}

final class DefaultFinancialOperationsRepository
    implements FinancialOperationsRepository {
  const DefaultFinancialOperationsRepository({
    required this.remote,
    required this.transactions,
  });

  final FinancialOperationsRemoteDataSource remote;
  final TransactionsRepository transactions;

  @override
  Future<TransferPreview> previewTransfer({
    required String accessToken,
    required TransferPreviewRequest request,
  }) {
    return remote.previewTransfer(accessToken: accessToken, request: request);
  }

  @override
  Future<void> queueTransfer({
    required String ownerId,
    required String operationId,
    required String transferId,
    required String sourceTransactionId,
    required String destinationTransactionId,
    required String? feeTransactionId,
    required TransferPreviewRequest request,
    required TransferPreview preview,
    required String? note,
  }) {
    return transactions.queueFinancialOperation(
      ownerId: ownerId,
      operationId: operationId,
      entityId: transferId,
      type: OutboxOperationType.transferCommit,
      payload: <String, Object?>{
        ...request.toJson(),
        'id': transferId,
        'client_operation_id': operationId,
        'source_transaction_id': sourceTransactionId,
        'destination_transaction_id': destinationTransactionId,
        'fee_transaction_id': ?feeTransactionId,
        'source_fingerprint': preview.sourceFingerprint,
        'note': note,
      },
    );
  }

  @override
  Future<ReconciliationPreview> previewReconciliation({
    required String accessToken,
    required ReconciliationPreviewRequest request,
  }) {
    return remote.previewReconciliation(
      accessToken: accessToken,
      request: request,
    );
  }

  @override
  Future<void> queueReconciliation({
    required String ownerId,
    required String operationId,
    required String reconciliationId,
    required String adjustmentTransactionId,
    required ReconciliationPreviewRequest request,
    required ReconciliationPreview preview,
    required String? reason,
  }) {
    return transactions.queueFinancialOperation(
      ownerId: ownerId,
      operationId: operationId,
      entityId: reconciliationId,
      type: OutboxOperationType.reconciliationCommit,
      payload: <String, Object?>{
        ...request.toJson(),
        '_account_id': request.accountId,
        'id': reconciliationId,
        'client_operation_id': operationId,
        'adjustment_transaction_id': adjustmentTransactionId,
        'source_fingerprint': preview.sourceFingerprint,
        'reason': reason,
      },
    );
  }

  @override
  Future<ReallocationPreview> previewReallocation({
    required String accessToken,
    required ReallocationPreviewRequest request,
  }) {
    return remote.previewReallocation(
      accessToken: accessToken,
      request: request,
    );
  }

  @override
  Future<void> queueReallocation({
    required String ownerId,
    required String operationId,
    required String reallocationId,
    required ReallocationPreviewRequest request,
    required ReallocationPreview preview,
    required String? note,
  }) {
    return transactions.queueFinancialOperation(
      ownerId: ownerId,
      operationId: operationId,
      entityId: reallocationId,
      type: OutboxOperationType.reallocationCommit,
      payload: <String, Object?>{
        ...request.toJson(),
        'id': reallocationId,
        'client_operation_id': operationId,
        'source_fingerprint': preview.sourceFingerprint,
        'note': note,
      },
    );
  }
}
