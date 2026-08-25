import 'package:drift/drift.dart';
import 'package:planit_mobile/core/database/database_connection.dart';

part 'app_database.g.dart';

class CachedAccounts extends Table {
  TextColumn get id => text()();
  TextColumn get ownerId => text()();
  TextColumn get name => text().withLength(min: 1, max: 120)();
  TextColumn get type => text().withLength(min: 1, max: 24)();
  TextColumn get currency => text().withLength(min: 3, max: 3)();
  TextColumn get openingBalanceAmount => text()();
  TextColumn get calculatedBalanceAmount => text()();
  DateTimeColumn get balanceAsOf => dateTime()();
  DateTimeColumn get openedAt => dateTime()();
  BoolColumn get includeInTotal => boolean()();
  BoolColumn get allowNegative => boolean()();
  TextColumn get status => text().withLength(min: 1, max: 16)();
  IntColumn get sortOrder =>
      integer().check(const CustomExpression<bool>('sort_order >= 0'))();
  DateTimeColumn get archivedAt => dateTime().nullable()();
  DateTimeColumn get closedAt => dateTime().nullable()();
  IntColumn get version =>
      integer().check(const CustomExpression<bool>('version > 0'))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get cachedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{id};
}

@DriftDatabase(tables: <Type>[CachedAccounts])
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor])
    : super(executor ?? openPlanItDatabase());

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (Migrator migrator) => migrator.createAll(),
    beforeOpen: (OpeningDetails details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );

  Stream<List<CachedAccount>> watchAccounts(String ownerId) {
    final query = select(cachedAccounts)
      ..where((row) => row.ownerId.equals(ownerId))
      ..orderBy(<OrderClauseGenerator<CachedAccounts>>[
        (row) => OrderingTerm.asc(row.sortOrder),
        (row) => OrderingTerm.asc(row.createdAt),
        (row) => OrderingTerm.asc(row.id),
      ]);
    return query.watch();
  }

  Future<List<CachedAccount>> readAccounts(String ownerId) {
    final query = select(cachedAccounts)
      ..where((row) => row.ownerId.equals(ownerId))
      ..orderBy(<OrderClauseGenerator<CachedAccounts>>[
        (row) => OrderingTerm.asc(row.sortOrder),
        (row) => OrderingTerm.asc(row.createdAt),
        (row) => OrderingTerm.asc(row.id),
      ]);
    return query.get();
  }

  Future<void> replaceAccounts(
    String ownerId,
    List<CachedAccountsCompanion> accounts,
  ) {
    return transaction(() async {
      await (delete(
        cachedAccounts,
      )..where((row) => row.ownerId.equals(ownerId))).go();
      if (accounts.isNotEmpty) {
        await batch((batch) {
          batch.insertAll(cachedAccounts, accounts);
        });
      }
    });
  }

  Future<void> upsertAccount(CachedAccountsCompanion account) {
    return into(cachedAccounts).insertOnConflictUpdate(account);
  }

  Future<void> clearOwnerData(String ownerId) {
    return (delete(
      cachedAccounts,
    )..where((row) => row.ownerId.equals(ownerId))).go();
  }
}
