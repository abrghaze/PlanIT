final class TransactionActionState {
  const TransactionActionState({
    required this.busy,
    required this.syncing,
    this.errorMessage,
    this.noticeMessage,
    this.lastSyncedAt,
  });

  const TransactionActionState.idle()
    : busy = false,
      syncing = false,
      errorMessage = null,
      noticeMessage = null,
      lastSyncedAt = null;

  final bool busy;
  final bool syncing;
  final String? errorMessage;
  final String? noticeMessage;
  final DateTime? lastSyncedAt;

  TransactionActionState copyWith({
    bool? busy,
    bool? syncing,
    String? errorMessage,
    bool clearError = false,
    String? noticeMessage,
    bool clearNotice = false,
    DateTime? lastSyncedAt,
  }) {
    return TransactionActionState(
      busy: busy ?? this.busy,
      syncing: syncing ?? this.syncing,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
      noticeMessage: clearNotice ? null : noticeMessage ?? this.noticeMessage,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
    );
  }
}
