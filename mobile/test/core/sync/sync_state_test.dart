import 'package:flutter_test/flutter_test.dart';
import 'package:planit_mobile/core/sync/sync_state.dart';

void main() {
  test('every synchronization state has a user-facing label', () {
    expect(SyncState.values.map((state) => state.label), <String>[
      'Pending',
      'Syncing',
      'Synced',
      'Will retry',
      'Needs review',
    ]);
  });
}
