final class AccountActionState {
  const AccountActionState({
    required this.busy,
    this.errorMessage,
    this.lastSyncedAt,
  });

  const AccountActionState.idle()
    : busy = false,
      errorMessage = null,
      lastSyncedAt = null;

  final bool busy;
  final String? errorMessage;
  final DateTime? lastSyncedAt;

  AccountActionState copyWith({
    bool? busy,
    String? errorMessage,
    bool clearError = false,
    DateTime? lastSyncedAt,
  }) {
    return AccountActionState(
      busy: busy ?? this.busy,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
    );
  }
}
