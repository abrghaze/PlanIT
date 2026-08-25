import 'package:planit_mobile/core/money/money.dart';

enum TransactionType { expense, income, reversal }

extension TransactionTypeContract on TransactionType {
  String get apiValue => name.toUpperCase();

  String get label => switch (this) {
    TransactionType.expense => 'Expense',
    TransactionType.income => 'Income',
    TransactionType.reversal => 'Reversal',
  };

  static TransactionType fromApi(String value) {
    return TransactionType.values.firstWhere(
      (type) => type.apiValue == value,
      orElse: () => TransactionType.reversal,
    );
  }
}

enum TransactionEffect { inflow, outflow }

extension TransactionEffectContract on TransactionEffect {
  String get apiValue => name.toUpperCase();

  static TransactionEffect fromApi(String value) {
    return value == 'INFLOW'
        ? TransactionEffect.inflow
        : TransactionEffect.outflow;
  }
}

enum TransactionStatus { draft, posted, reversed, voided }

extension TransactionStatusContract on TransactionStatus {
  String get apiValue => name.toUpperCase();

  String get label => switch (this) {
    TransactionStatus.draft => 'Draft',
    TransactionStatus.posted => 'Posted',
    TransactionStatus.reversed => 'Reversed',
    TransactionStatus.voided => 'Voided',
  };

  static TransactionStatus fromApi(String value) {
    return TransactionStatus.values.firstWhere(
      (status) => status.apiValue == value,
      orElse: () => TransactionStatus.draft,
    );
  }
}

enum LocalTransactionSyncState { synced, pending, sending, retry, conflict }

extension LocalTransactionSyncStateContract on LocalTransactionSyncState {
  String get storageValue => name.toUpperCase();

  String get label => switch (this) {
    LocalTransactionSyncState.synced => 'Synced',
    LocalTransactionSyncState.pending => 'Pending',
    LocalTransactionSyncState.sending => 'Syncing',
    LocalTransactionSyncState.retry => 'Will retry',
    LocalTransactionSyncState.conflict => 'Needs review',
  };

  static LocalTransactionSyncState fromStorage(String value) {
    return LocalTransactionSyncState.values.firstWhere(
      (state) => state.storageValue == value,
      orElse: () => LocalTransactionSyncState.conflict,
    );
  }
}

final class LedgerTransaction {
  const LedgerTransaction({
    required this.id,
    required this.ownerId,
    required this.accountId,
    required this.type,
    required this.effect,
    required this.amount,
    required this.occurredAt,
    required this.status,
    required this.categoryId,
    required this.counterparty,
    required this.note,
    required this.tagIds,
    required this.parentTransactionId,
    required this.reversalOfId,
    required this.clientOperationId,
    required this.version,
    required this.createdAt,
    required this.updatedAt,
    required this.syncState,
    required this.pendingAction,
    required this.lastSyncError,
  });

  final String id;
  final String ownerId;
  final String accountId;
  final TransactionType type;
  final TransactionEffect effect;
  final Money amount;
  final DateTime occurredAt;
  final TransactionStatus status;
  final String? categoryId;
  final String? counterparty;
  final String? note;
  final List<String> tagIds;
  final String? parentTransactionId;
  final String? reversalOfId;
  final String clientOperationId;
  final int version;
  final DateTime createdAt;
  final DateTime updatedAt;
  final LocalTransactionSyncState syncState;
  final String? pendingAction;
  final String? lastSyncError;

  bool get hasPendingWork => syncState != LocalTransactionSyncState.synced;

  factory LedgerTransaction.fromJson(
    Map<String, Object?> json, {
    required String ownerId,
  }) {
    final money = Map<String, Object?>.from(json['amount']! as Map);
    return LedgerTransaction(
      id: json['id']! as String,
      ownerId: ownerId,
      accountId: json['account_id']! as String,
      type: TransactionTypeContract.fromApi(json['type']! as String),
      effect: TransactionEffectContract.fromApi(json['effect']! as String),
      amount: Money.parse(
        money['amount']! as String,
        money['currency']! as String,
      ),
      occurredAt: DateTime.parse(json['occurred_at']! as String).toUtc(),
      status: TransactionStatusContract.fromApi(json['status']! as String),
      categoryId: json['category_id'] as String?,
      counterparty: json['counterparty'] as String?,
      note: json['note'] as String?,
      tagIds: (json['tag_ids']! as List)
          .map((value) => value as String)
          .toList(growable: false),
      parentTransactionId: json['parent_transaction_id'] as String?,
      reversalOfId: json['reversal_of_id'] as String?,
      clientOperationId: json['client_operation_id']! as String,
      version: json['version']! as int,
      createdAt: DateTime.parse(json['created_at']! as String).toUtc(),
      updatedAt: DateTime.parse(json['updated_at']! as String).toUtc(),
      syncState: LocalTransactionSyncState.synced,
      pendingAction: null,
      lastSyncError: null,
    );
  }

  LedgerTransaction copyWith({
    TransactionStatus? status,
    int? version,
    DateTime? updatedAt,
    LocalTransactionSyncState? syncState,
    String? pendingAction,
    bool clearPendingAction = false,
    String? lastSyncError,
    bool clearSyncError = false,
  }) {
    return LedgerTransaction(
      id: id,
      ownerId: ownerId,
      accountId: accountId,
      type: type,
      effect: effect,
      amount: amount,
      occurredAt: occurredAt,
      status: status ?? this.status,
      categoryId: categoryId,
      counterparty: counterparty,
      note: note,
      tagIds: tagIds,
      parentTransactionId: parentTransactionId,
      reversalOfId: reversalOfId,
      clientOperationId: clientOperationId,
      version: version ?? this.version,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      syncState: syncState ?? this.syncState,
      pendingAction: clearPendingAction
          ? null
          : pendingAction ?? this.pendingAction,
      lastSyncError: clearSyncError
          ? null
          : lastSyncError ?? this.lastSyncError,
    );
  }
}

final class TransactionDraft {
  const TransactionDraft({
    required this.id,
    required this.clientOperationId,
    required this.accountId,
    required this.type,
    required this.amount,
    required this.occurredAt,
    required this.categoryId,
    required this.counterparty,
    required this.note,
    required this.tagIds,
  });

  final String id;
  final String clientOperationId;
  final String accountId;
  final TransactionType type;
  final Money amount;
  final DateTime occurredAt;
  final String? categoryId;
  final String? counterparty;
  final String? note;
  final List<String> tagIds;

  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'client_operation_id': clientOperationId,
    'account_id': accountId,
    'type': type.apiValue,
    'amount': <String, Object?>{
      'amount': amount.toApiString(),
      'currency': amount.currency,
    },
    'occurred_at': occurredAt.toUtc().toIso8601String(),
    'category_id': categoryId,
    'counterparty': counterparty,
    'note': note,
    'tag_ids': tagIds,
  };

  LedgerTransaction toPendingTransaction({required String ownerId}) {
    final now = DateTime.now().toUtc();
    return LedgerTransaction(
      id: id,
      ownerId: ownerId,
      accountId: accountId,
      type: type,
      effect: type == TransactionType.expense
          ? TransactionEffect.outflow
          : TransactionEffect.inflow,
      amount: amount,
      occurredAt: occurredAt.toUtc(),
      status: TransactionStatus.draft,
      categoryId: categoryId,
      counterparty: counterparty,
      note: note,
      tagIds: List<String>.unmodifiable(tagIds),
      parentTransactionId: null,
      reversalOfId: null,
      clientOperationId: clientOperationId,
      version: 1,
      createdAt: now,
      updatedAt: now,
      syncState: LocalTransactionSyncState.pending,
      pendingAction: 'CREATE_DRAFT',
      lastSyncError: null,
    );
  }
}

final class TransactionEdit {
  const TransactionEdit({
    required this.version,
    required this.accountId,
    required this.type,
    required this.amount,
    required this.occurredAt,
    required this.categoryId,
    required this.counterparty,
    required this.note,
    required this.tagIds,
  });

  final int version;
  final String accountId;
  final TransactionType type;
  final Money amount;
  final DateTime occurredAt;
  final String? categoryId;
  final String? counterparty;
  final String? note;
  final List<String> tagIds;

  Map<String, Object?> toJson() => <String, Object?>{
    'version': version,
    'account_id': accountId,
    'type': type.apiValue,
    'amount': <String, Object?>{
      'amount': amount.toApiString(),
      'currency': amount.currency,
    },
    'occurred_at': occurredAt.toUtc().toIso8601String(),
    'category_id': categoryId,
    'counterparty': counterparty,
    'note': note,
    'tag_ids': tagIds,
  };

  LedgerTransaction applyTo(
    LedgerTransaction current, {
    required String pendingAction,
  }) {
    final now = DateTime.now().toUtc();
    return LedgerTransaction(
      id: current.id,
      ownerId: current.ownerId,
      accountId: accountId,
      type: type,
      effect: type == TransactionType.expense
          ? TransactionEffect.outflow
          : TransactionEffect.inflow,
      amount: amount,
      occurredAt: occurredAt.toUtc(),
      status: TransactionStatus.draft,
      categoryId: categoryId,
      counterparty: counterparty,
      note: note,
      tagIds: List<String>.unmodifiable(tagIds),
      parentTransactionId: current.parentTransactionId,
      reversalOfId: current.reversalOfId,
      clientOperationId: current.clientOperationId,
      version: version,
      createdAt: current.createdAt,
      updatedAt: now,
      syncState: LocalTransactionSyncState.pending,
      pendingAction: pendingAction,
      lastSyncError: null,
    );
  }
}

final class TransactionReversalDraft {
  const TransactionReversalDraft({
    required this.id,
    required this.clientOperationId,
    required this.version,
    required this.occurredAt,
    required this.note,
  });

  final String id;
  final String clientOperationId;
  final int version;
  final DateTime occurredAt;
  final String? note;

  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'client_operation_id': clientOperationId,
    'version': version,
    'occurred_at': occurredAt.toUtc().toIso8601String(),
    'note': note,
  };
}
