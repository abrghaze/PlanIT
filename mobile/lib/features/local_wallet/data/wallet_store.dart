import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:planit_mobile/core/database/app_database.dart';
import 'package:planit_mobile/core/database/providers.dart';
import 'package:planit_mobile/features/local_wallet/domain/wallet.dart';
import 'package:planit_mobile/features/offline_finance/application/providers.dart';
import 'package:planit_mobile/features/offline_finance/data/local_write_queue.dart';

final walletStoreProvider = Provider(
  (ref) => WalletStore(ref.watch(appDatabaseProvider)),
);
final walletProvider = StreamProvider(
  (ref) => ref.watch(walletStoreProvider).watch().map((wallet) {
    ref.invalidate(localClockProvider);
    return wallet;
  }),
);
final localModeProvider = AsyncNotifierProvider<LocalModeController, bool>(
  LocalModeController.new,
);

class LocalModeController extends AsyncNotifier<bool> {
  static const _key = 'planit.local.workspace.selected.v1';
  static const _storage = FlutterSecureStorage();
  @override
  Future<bool> build() async => await _storage.read(key: _key) == 'true';
  Future<void> select(bool local) async {
    await _storage.write(key: _key, value: local.toString());
    if (ref.mounted) state = AsyncData(local);
  }
}

final class WalletStore {
  WalletStore(this.database);
  final AppDatabase database;
  final _queue = LocalWriteQueue();
  static const id = 'personal';
  Future<Wallet> read() async {
    final row = await (database.select(
      database.localWalletSnapshots,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    return row == null
        ? Wallet.empty()
        : Wallet.fromJson(walletMap(jsonDecode(row.payloadJson)));
  }

  Stream<Wallet> watch() =>
      (database.select(
        database.localWalletSnapshots,
      )..where((t) => t.id.equals(id))).watchSingleOrNull().map(
        (row) => row == null
            ? Wallet.empty()
            : Wallet.fromJson(walletMap(jsonDecode(row.payloadJson))),
      );
  Future<void> _write(Wallet value) async {
    // Round-trip validation applies equally to UI edits and imported files.
    final json = jsonEncode(value.toJson());
    if (utf8.encode(json).length > 12 * 1024 * 1024) {
      throw const FormatException(
        'Local wallet exceeds the backup size limit.',
      );
    }
    Wallet.fromJson(walletMap(jsonDecode(json)));
    await database
        .into(database.localWalletSnapshots)
        .insertOnConflictUpdate(
          LocalWalletSnapshotsCompanion.insert(id: id, payloadJson: json),
        );
  }

  Future<void> change(Wallet Function(Wallet) action) => _queue.run(
    () => database.transaction(() async {
      await _write(action(await read()));
    }),
  );
  Future<void> saveAccount(WalletAccount account) => change(
    (w) => w.copyWith(
      accounts: [
        for (final a in w.accounts)
          if (a.id != account.id) a,
        account,
      ],
    ),
  );
  Future<void> saveEntry(WalletEntry entry) => change(
    (w) => w.copyWith(
      entries: [
        for (final e in w.entries)
          if (e.id != entry.id) e,
        entry,
      ],
    ),
  );
  Future<void> setDeleted(String entryId, bool deleted) => change((w) {
    final entry = w.entries.firstWhere((e) => e.id == entryId);
    return w.copyWith(
      entries: [
        for (final e in w.entries)
          if (e.id == entryId ||
              (entry.transferId != null && e.transferId == entry.transferId))
            e.withDeleted(deleted)
          else
            e,
      ],
    );
  });
  Future<void> restore(Wallet incoming, {required bool replace}) => _queue.run(
    () => database.transaction(() async {
      // A replacement can also recover an unreadable snapshot. No online owner is touched.
      if (replace) {
        await _write(incoming);
        return;
      }
      final current = await read();
      List<T> merge<T>(
        List<T> old,
        List<T> added,
        Map<String, Object?> Function(T) json,
      ) {
        final byId = {for (final v in old) json(v)['id']! as String: v};
        for (final v in added) {
          final key = json(v)['id']! as String;
          if (byId.containsKey(key) &&
              jsonEncode(json(byId[key] as T)) != jsonEncode(json(v))) {
            throw const FormatException(
              'A backup record conflicts with a newer local record. Choose replace only if you want the backup version.',
            );
          }
          byId[key] = v;
        }
        return byId.values.toList();
      }

      final categories = Map<String, String>.from(current.categories);
      for (final e in incoming.categories.entries) {
        if (categories.containsKey(e.key) && categories[e.key] != e.value) {
          throw const FormatException('A category conflicts with this backup.');
        }
        categories[e.key] = e.value;
      }
      await _write(
        current.copyWith(
          accounts: merge(
            current.accounts,
            incoming.accounts,
            (v) => v.toJson(),
          ),
          entries: merge(current.entries, incoming.entries, (v) => v.toJson()),
          categories: categories,
          budgets: merge(current.budgets, incoming.budgets, (v) => v.toJson()),
          goals: merge(current.goals, incoming.goals, (v) => v.toJson()),
        ),
      );
    }),
  );
}
