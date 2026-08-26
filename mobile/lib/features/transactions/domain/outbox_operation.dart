enum OutboxOperationType {
  createDraft,
  updateDraft,
  post,
  reverse,
  transferCommit,
  reconciliationCommit,
  reallocationCommit,
}

extension OutboxOperationTypeContract on OutboxOperationType {
  String get storageValue => switch (this) {
    OutboxOperationType.createDraft => 'CREATE_DRAFT',
    OutboxOperationType.updateDraft => 'UPDATE_DRAFT',
    OutboxOperationType.post => 'POST',
    OutboxOperationType.reverse => 'REVERSE',
    OutboxOperationType.transferCommit => 'TRANSFER_COMMIT',
    OutboxOperationType.reconciliationCommit => 'RECONCILIATION_COMMIT',
    OutboxOperationType.reallocationCommit => 'REALLOCATION_COMMIT',
  };

  String get label => switch (this) {
    OutboxOperationType.createDraft => 'Create transaction',
    OutboxOperationType.updateDraft => 'Update transaction',
    OutboxOperationType.post => 'Post transaction',
    OutboxOperationType.reverse => 'Reverse transaction',
    OutboxOperationType.transferCommit => 'Transfer',
    OutboxOperationType.reconciliationCommit => 'Balance reconciliation',
    OutboxOperationType.reallocationCommit => 'Balance reallocation',
  };

  bool get isSpecializedFinancialCommit => switch (this) {
    OutboxOperationType.transferCommit ||
    OutboxOperationType.reconciliationCommit ||
    OutboxOperationType.reallocationCommit => true,
    _ => false,
  };

  static OutboxOperationType fromStorage(String value) {
    return OutboxOperationType.values.firstWhere(
      (type) => type.storageValue == value,
      orElse: () => throw FormatException('Unknown outbox operation: $value'),
    );
  }
}

enum OutboxOperationState { pending, sending, retry, conflict }

extension OutboxOperationStateContract on OutboxOperationState {
  String get storageValue => switch (this) {
    OutboxOperationState.pending => 'PENDING',
    OutboxOperationState.sending => 'SENDING',
    OutboxOperationState.retry => 'RETRY',
    OutboxOperationState.conflict => 'CONFLICT',
  };

  String get label => switch (this) {
    OutboxOperationState.pending => 'Pending',
    OutboxOperationState.sending => 'Syncing',
    OutboxOperationState.retry => 'Will retry',
    OutboxOperationState.conflict => 'Needs review',
  };

  bool get canDiscard => this != OutboxOperationState.sending;

  static OutboxOperationState fromStorage(String value) {
    return switch (value) {
      'PENDING' => OutboxOperationState.pending,
      'SENDING' => OutboxOperationState.sending,
      'RETRY' => OutboxOperationState.retry,
      'CONFLICT' => OutboxOperationState.conflict,
      _ => throw FormatException('Unknown outbox operation state: $value'),
    };
  }
}

final class PendingOperation {
  const PendingOperation({
    required this.id,
    required this.ownerId,
    required this.entityId,
    required this.type,
    required this.state,
    required this.payload,
    required this.attemptCount,
    required this.nextAttemptAt,
    required this.lastError,
    required this.createdAt,
  });

  final String id;
  final String ownerId;
  final String entityId;
  final OutboxOperationType type;
  final OutboxOperationState state;
  final Map<String, Object?> payload;
  final int attemptCount;
  final DateTime nextAttemptAt;
  final String? lastError;
  final DateTime createdAt;

  String get label => type.label;

  String get stateLabel => state.label;
}
