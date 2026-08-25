enum OutboxOperationType { createDraft, updateDraft, post, reverse }

extension OutboxOperationTypeContract on OutboxOperationType {
  String get storageValue => switch (this) {
    OutboxOperationType.createDraft => 'CREATE_DRAFT',
    OutboxOperationType.updateDraft => 'UPDATE_DRAFT',
    OutboxOperationType.post => 'POST',
    OutboxOperationType.reverse => 'REVERSE',
  };

  static OutboxOperationType fromStorage(String value) {
    return OutboxOperationType.values.firstWhere(
      (type) => type.storageValue == value,
      orElse: () => throw FormatException('Unknown outbox operation: $value'),
    );
  }
}

final class PendingOperation {
  const PendingOperation({
    required this.id,
    required this.ownerId,
    required this.entityId,
    required this.type,
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
  final Map<String, Object?> payload;
  final int attemptCount;
  final DateTime nextAttemptAt;
  final String? lastError;
  final DateTime createdAt;
}
