enum SyncState {
  pending,
  sending,
  acknowledged,
  retryableFailure,
  conflict,
}

extension SyncStateLabel on SyncState {
  String get label => switch (this) {
        SyncState.pending => 'Pending',
        SyncState.sending => 'Syncing',
        SyncState.acknowledged => 'Synced',
        SyncState.retryableFailure => 'Will retry',
        SyncState.conflict => 'Needs review',
      };
}
