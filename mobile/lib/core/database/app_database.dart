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

class CachedCategories extends Table {
  TextColumn get id => text()();
  TextColumn get ownerId => text()();
  TextColumn get name => text().withLength(min: 1, max: 80)();
  TextColumn get kind => text().withLength(min: 1, max: 16)();
  TextColumn get parentId => text().nullable()();
  BoolColumn get isSeeded => boolean()();
  DateTimeColumn get archivedAt => dateTime().nullable()();
  IntColumn get version =>
      integer().check(const CustomExpression<bool>('version > 0'))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get cachedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{id};
}

class CachedTags extends Table {
  TextColumn get id => text()();
  TextColumn get ownerId => text()();
  TextColumn get name => text().withLength(min: 1, max: 80)();
  TextColumn get color => text().withLength(min: 7, max: 7).nullable()();
  DateTimeColumn get archivedAt => dateTime().nullable()();
  IntColumn get version =>
      integer().check(const CustomExpression<bool>('version > 0'))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get cachedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{id};
}

class CachedTransactions extends Table {
  TextColumn get id => text()();
  TextColumn get ownerId => text()();
  TextColumn get accountId => text()();
  TextColumn get type => text().withLength(min: 1, max: 40)();
  TextColumn get effect => text().withLength(min: 1, max: 16)();
  TextColumn get amount => text()();
  TextColumn get currency => text().withLength(min: 3, max: 3)();
  DateTimeColumn get occurredAt => dateTime()();
  TextColumn get status => text().withLength(min: 1, max: 16)();
  TextColumn get categoryId => text().nullable()();
  TextColumn get merchantId => text().nullable()();
  TextColumn get merchantLocationId => text().nullable()();
  TextColumn get itemsJson =>
      text().withDefault(const Constant<String>('[]'))();
  TextColumn get counterparty =>
      text().withLength(min: 1, max: 160).nullable()();
  TextColumn get note => text().nullable()();
  TextColumn get parentTransactionId => text().nullable()();
  TextColumn get reversalOfId => text().nullable()();
  TextColumn get clientOperationId => text()();
  IntColumn get version =>
      integer().check(const CustomExpression<bool>('version > 0'))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get cachedAt => dateTime()();
  TextColumn get syncState => text().withLength(min: 1, max: 16)();
  TextColumn get pendingAction =>
      text().withLength(min: 1, max: 24).nullable()();
  TextColumn get lastSyncError => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{id};
}

class CachedTransactionItems extends Table {
  TextColumn get id => text()();
  TextColumn get ownerId => text()();
  TextColumn get transactionId => text()();
  TextColumn get productId => text().nullable()();
  TextColumn get description => text().withLength(min: 1, max: 240)();
  TextColumn get quantity => text()();
  TextColumn get unitPrice => text()();
  TextColumn get discount => text()();
  TextColumn get lineTotal => text()();
  IntColumn get position => integer()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{id};
}

class CachedMerchants extends Table {
  TextColumn get id => text()();
  TextColumn get ownerId => text()();
  TextColumn get name => text().withLength(min: 1, max: 160)();
  TextColumn get categoryId => text().nullable()();
  TextColumn get notes => text().nullable()();
  TextColumn get locationsJson => text()();
  BoolColumn get archived => boolean()();
  IntColumn get version => integer()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get cachedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{id};
}

class CachedProducts extends Table {
  TextColumn get id => text()();
  TextColumn get ownerId => text()();
  TextColumn get parentProductId => text().nullable()();
  TextColumn get name => text().withLength(min: 1, max: 160)();
  TextColumn get brand => text().nullable()();
  TextColumn get variantLabel => text().nullable()();
  TextColumn get sizeValue => text().nullable()();
  TextColumn get sizeUnit => text().nullable()();
  TextColumn get barcode => text().nullable()();
  TextColumn get categoryId => text().nullable()();
  TextColumn get defaultMerchantId => text().nullable()();
  TextColumn get notes => text().nullable()();
  BoolColumn get archived => boolean()();
  IntColumn get version => integer()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get cachedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{id};
}

class CachedTransactionTags extends Table {
  TextColumn get transactionId => text()();
  TextColumn get tagId => text()();
  TextColumn get ownerId => text()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{transactionId, tagId};
}

class OutboxOperations extends Table {
  TextColumn get id => text()();
  TextColumn get ownerId => text()();
  TextColumn get entityId => text()();
  TextColumn get type => text().withLength(min: 1, max: 24)();
  TextColumn get payloadJson => text()();
  TextColumn get state => text().withLength(min: 1, max: 16)();
  IntColumn get attemptCount =>
      integer().check(const CustomExpression<bool>('attempt_count >= 0'))();
  DateTimeColumn get nextAttemptAt => dateTime()();
  TextColumn get lastError => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{id};
}

class CachedAnalyticsDashboards extends Table {
  TextColumn get ownerId => text()();
  TextColumn get cacheKey => text()();
  TextColumn get payloadJson => text()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{ownerId, cacheKey};
}

class CachedPlanningSnapshots extends Table {
  TextColumn get ownerId => text()();
  TextColumn get payloadJson => text()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{ownerId};
}

@DriftDatabase(
  tables: <Type>[
    CachedAccounts,
    CachedCategories,
    CachedTags,
    CachedTransactions,
    CachedTransactionItems,
    CachedTransactionTags,
    CachedMerchants,
    CachedProducts,
    CachedAnalyticsDashboards,
    CachedPlanningSnapshots,
    OutboxOperations,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor])
    : super(executor ?? openPlanItDatabase());

  @override
  int get schemaVersion => 5;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (Migrator migrator) => migrator.createAll(),
    onUpgrade: (Migrator migrator, int from, int to) async {
      if (from < 2) {
        await migrator.createTable(cachedCategories);
        await migrator.createTable(cachedTags);
        await migrator.createTable(cachedTransactions);
        await migrator.createTable(cachedTransactionTags);
        await migrator.createTable(outboxOperations);
      }
      if (from < 3) {
        await migrator.addColumn(
          cachedTransactions,
          cachedTransactions.merchantId,
        );
        await migrator.addColumn(
          cachedTransactions,
          cachedTransactions.merchantLocationId,
        );
        await migrator.addColumn(
          cachedTransactions,
          cachedTransactions.itemsJson,
        );
        await migrator.createTable(cachedTransactionItems);
        await migrator.createTable(cachedMerchants);
        await migrator.createTable(cachedProducts);
      }
      if (from < 4) {
        await migrator.createTable(cachedAnalyticsDashboards);
      }
      if (from < 5) {
        await migrator.createTable(cachedPlanningSnapshots);
      }
    },
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

  Stream<List<CachedCategory>> watchCategories(String ownerId) {
    final query = select(cachedCategories)
      ..where((row) => row.ownerId.equals(ownerId))
      ..orderBy(<OrderClauseGenerator<CachedCategories>>[
        (row) => OrderingTerm.asc(row.kind),
        (row) => OrderingTerm.asc(row.name),
        (row) => OrderingTerm.asc(row.id),
      ]);
    return query.watch();
  }

  Future<void> replaceCategories(
    String ownerId,
    List<CachedCategoriesCompanion> categories,
  ) {
    return transaction(() async {
      await (delete(
        cachedCategories,
      )..where((row) => row.ownerId.equals(ownerId))).go();
      if (categories.isNotEmpty) {
        await batch((batch) => batch.insertAll(cachedCategories, categories));
      }
    });
  }

  Stream<List<CachedTag>> watchTags(String ownerId) {
    final query = select(cachedTags)
      ..where((row) => row.ownerId.equals(ownerId))
      ..orderBy(<OrderClauseGenerator<CachedTags>>[
        (row) => OrderingTerm.asc(row.name),
        (row) => OrderingTerm.asc(row.id),
      ]);
    return query.watch();
  }

  Future<void> replaceTags(String ownerId, List<CachedTagsCompanion> tags) {
    return transaction(() async {
      await (delete(
        cachedTags,
      )..where((row) => row.ownerId.equals(ownerId))).go();
      if (tags.isNotEmpty) {
        await batch((batch) => batch.insertAll(cachedTags, tags));
      }
    });
  }

  Future<void> upsertCategory(CachedCategoriesCompanion category) {
    return into(cachedCategories).insertOnConflictUpdate(category);
  }

  Future<void> upsertTag(CachedTagsCompanion tag) {
    return into(cachedTags).insertOnConflictUpdate(tag);
  }

  Stream<List<CachedMerchant>> watchMerchants(String ownerId) {
    final query = select(cachedMerchants)
      ..where((row) => row.ownerId.equals(ownerId))
      ..orderBy(<OrderClauseGenerator<CachedMerchants>>[
        (row) => OrderingTerm.asc(row.name),
      ]);
    return query.watch();
  }

  Future<void> replaceMerchants(
    String ownerId,
    List<CachedMerchantsCompanion> rows,
  ) => transaction(() async {
    await (delete(
      cachedMerchants,
    )..where((row) => row.ownerId.equals(ownerId))).go();
    if (rows.isNotEmpty) {
      await batch((batch) => batch.insertAll(cachedMerchants, rows));
    }
  });

  Future<void> upsertMerchant(CachedMerchantsCompanion row) =>
      into(cachedMerchants).insertOnConflictUpdate(row);

  Stream<List<CachedProduct>> watchProducts(String ownerId) {
    final query = select(cachedProducts)
      ..where((row) => row.ownerId.equals(ownerId))
      ..orderBy(<OrderClauseGenerator<CachedProducts>>[
        (row) => OrderingTerm.asc(row.name),
        (row) => OrderingTerm.asc(row.variantLabel),
      ]);
    return query.watch();
  }

  Future<void> replaceProducts(
    String ownerId,
    List<CachedProductsCompanion> rows,
  ) => transaction(() async {
    await (delete(
      cachedProducts,
    )..where((row) => row.ownerId.equals(ownerId))).go();
    if (rows.isNotEmpty) {
      await batch((batch) => batch.insertAll(cachedProducts, rows));
    }
  });

  Future<void> upsertProduct(CachedProductsCompanion row) =>
      into(cachedProducts).insertOnConflictUpdate(row);

  Stream<List<CachedTransaction>> watchTransactions(String ownerId) {
    final query = select(cachedTransactions)
      ..where((row) => row.ownerId.equals(ownerId))
      ..orderBy(<OrderClauseGenerator<CachedTransactions>>[
        (row) => OrderingTerm.desc(row.occurredAt),
        (row) => OrderingTerm.desc(row.createdAt),
        (row) => OrderingTerm.desc(row.id),
      ]);
    return query.watch();
  }

  Future<List<CachedTransactionTag>> readTransactionTags(
    String ownerId,
    Iterable<String> transactionIds,
  ) {
    final ids = transactionIds.toList(growable: false);
    if (ids.isEmpty) {
      return Future<List<CachedTransactionTag>>.value(
        const <CachedTransactionTag>[],
      );
    }
    final query = select(cachedTransactionTags)
      ..where(
        (row) => row.ownerId.equals(ownerId) & row.transactionId.isIn(ids),
      )
      ..orderBy(<OrderClauseGenerator<CachedTransactionTags>>[
        (row) => OrderingTerm.asc(row.transactionId),
        (row) => OrderingTerm.asc(row.tagId),
      ]);
    return query.get();
  }

  Future<void> saveTransactionWithOperations({
    required CachedTransactionsCompanion transactionRow,
    required String ownerId,
    required String transactionId,
    required List<String> tagIds,
    required List<OutboxOperationsCompanion> operations,
  }) {
    return transaction(() async {
      await into(cachedTransactions).insertOnConflictUpdate(transactionRow);
      await _replaceTransactionTags(ownerId, transactionId, tagIds);
      if (operations.isNotEmpty) {
        await batch((batch) => batch.insertAll(outboxOperations, operations));
      }
    });
  }

  Future<void> queueOutboxOperation(OutboxOperationsCompanion operation) {
    return into(outboxOperations).insert(operation);
  }

  Future<void> mergeRemoteTransactions({
    required String ownerId,
    required List<CachedTransactionsCompanion> transactionRows,
    required Map<String, List<String>> tagIdsByTransaction,
  }) {
    return transaction(() async {
      for (final row in transactionRows) {
        final transactionId = row.id.value;
        final pending = await _hasPendingOperation(ownerId, transactionId);
        if (pending) {
          continue;
        }
        await into(cachedTransactions).insertOnConflictUpdate(row);
        await _replaceTransactionTags(
          ownerId,
          transactionId,
          tagIdsByTransaction[transactionId] ?? const <String>[],
        );
      }
    });
  }

  Future<OutboxOperation?> readNextOperation(
    String ownerId, {
    required DateTime now,
    bool force = false,
  }) async {
    final query = select(outboxOperations)
      ..where((row) => row.ownerId.equals(ownerId))
      ..orderBy(<OrderClauseGenerator<OutboxOperations>>[
        (row) => OrderingTerm.asc(row.createdAt),
        (row) => OrderingTerm.asc(row.id),
      ])
      ..limit(1);
    final operation = await query.getSingleOrNull();
    if (operation == null ||
        (!force && operation.state == 'CONFLICT') ||
        (!force && operation.nextAttemptAt.isAfter(now))) {
      return null;
    }
    return operation;
  }

  Stream<int> watchPendingOperationCount(String ownerId) {
    final count = outboxOperations.id.count();
    final query = selectOnly(outboxOperations)
      ..addColumns(<Expression<Object>>[count])
      ..where(outboxOperations.ownerId.equals(ownerId));
    return query.watchSingle().map((row) => row.read(count) ?? 0);
  }

  Stream<List<OutboxOperation>> watchOutboxOperations(String ownerId) {
    final query = select(outboxOperations)
      ..where((row) => row.ownerId.equals(ownerId))
      ..orderBy(<OrderClauseGenerator<OutboxOperations>>[
        (row) => OrderingTerm.asc(row.createdAt),
        (row) => OrderingTerm.asc(row.id),
      ]);
    return query.watch();
  }

  Future<void> markOperationSending(OutboxOperation operation) {
    return transaction(() async {
      await (update(outboxOperations)..where(
            (row) =>
                row.id.equals(operation.id) &
                row.ownerId.equals(operation.ownerId),
          ))
          .write(
            OutboxOperationsCompanion(
              state: const Value('SENDING'),
              updatedAt: Value(DateTime.now().toUtc()),
            ),
          );
      await (update(cachedTransactions)..where(
            (row) =>
                row.id.equals(operation.entityId) &
                row.ownerId.equals(operation.ownerId),
          ))
          .write(
            const CachedTransactionsCompanion(
              syncState: Value('SENDING'),
              lastSyncError: Value(null),
            ),
          );
    });
  }

  Future<void> markOperationFailed({
    required OutboxOperation operation,
    required String error,
    required DateTime nextAttemptAt,
    required bool conflict,
  }) {
    return transaction(() async {
      await (update(outboxOperations)..where(
            (row) =>
                row.id.equals(operation.id) &
                row.ownerId.equals(operation.ownerId),
          ))
          .write(
            OutboxOperationsCompanion(
              state: Value(conflict ? 'CONFLICT' : 'RETRY'),
              attemptCount: Value(operation.attemptCount + 1),
              nextAttemptAt: Value(nextAttemptAt),
              lastError: Value(error),
              updatedAt: Value(DateTime.now().toUtc()),
            ),
          );
      await (update(cachedTransactions)..where(
            (row) =>
                row.id.equals(operation.entityId) &
                row.ownerId.equals(operation.ownerId),
          ))
          .write(
            CachedTransactionsCompanion(
              syncState: Value(conflict ? 'CONFLICT' : 'RETRY'),
              lastSyncError: Value(error),
            ),
          );
    });
  }

  Future<void> acknowledgeOperation({
    required OutboxOperation operation,
    required List<CachedTransactionsCompanion> canonicalRows,
    required Map<String, List<String>> tagIdsByTransaction,
  }) {
    return transaction(() async {
      final deleted =
          await (delete(outboxOperations)..where(
                (row) =>
                    row.id.equals(operation.id) &
                    row.ownerId.equals(operation.ownerId) &
                    row.entityId.equals(operation.entityId),
              ))
              .go();
      if (deleted != 1) {
        throw StateError('The acknowledged outbox operation no longer exists.');
      }
      for (final row in canonicalRows) {
        if (!row.id.present || !row.ownerId.present) {
          throw ArgumentError(
            'Canonical transaction rows must include an ID and owner.',
          );
        }
        final transactionId = row.id.value;
        if (row.ownerId.value != operation.ownerId) {
          throw ArgumentError(
            'Canonical transactions must belong to the operation owner.',
          );
        }
        await into(cachedTransactions).insertOnConflictUpdate(row);
        await _replaceTransactionTags(
          operation.ownerId,
          transactionId,
          tagIdsByTransaction[transactionId] ?? const <String>[],
        );
      }
      final next = await _nextEntityOperation(
        operation.ownerId,
        operation.entityId,
      );
      if (next != null) {
        await (update(cachedTransactions)..where(
              (row) =>
                  row.id.equals(operation.entityId) &
                  row.ownerId.equals(operation.ownerId),
            ))
            .write(
              CachedTransactionsCompanion(
                syncState: const Value('PENDING'),
                pendingAction: Value(next.type),
                lastSyncError: const Value(null),
              ),
            );
      }
    });
  }

  Future<void> discardOutboxOperation({
    required String ownerId,
    required String operationId,
    required String entityId,
  }) async {
    await (delete(outboxOperations)..where(
          (row) =>
              row.id.equals(operationId) &
              row.ownerId.equals(ownerId) &
              row.entityId.equals(entityId),
        ))
        .go();
  }

  Future<void> discardEntityOperations({
    required String ownerId,
    required String entityId,
  }) {
    return transaction(() async {
      await (delete(outboxOperations)..where(
            (row) =>
                row.ownerId.equals(ownerId) & row.entityId.equals(entityId),
          ))
          .go();
      await (delete(cachedTransactionTags)..where(
            (row) =>
                row.ownerId.equals(ownerId) &
                row.transactionId.equals(entityId),
          ))
          .go();
      await (delete(cachedTransactions)..where(
            (row) => row.ownerId.equals(ownerId) & row.id.equals(entityId),
          ))
          .go();
    });
  }

  Future<void> _replaceTransactionTags(
    String ownerId,
    String transactionId,
    List<String> tagIds,
  ) async {
    await (delete(cachedTransactionTags)..where(
          (row) =>
              row.ownerId.equals(ownerId) &
              row.transactionId.equals(transactionId),
        ))
        .go();
    if (tagIds.isEmpty) {
      return;
    }
    await batch(
      (batch) => batch.insertAll(
        cachedTransactionTags,
        tagIds
            .map(
              (tagId) => CachedTransactionTagsCompanion.insert(
                transactionId: transactionId,
                tagId: tagId,
                ownerId: ownerId,
              ),
            )
            .toList(growable: false),
      ),
    );
  }

  Future<bool> _hasPendingOperation(
    String ownerId,
    String transactionId,
  ) async {
    final query = selectOnly(outboxOperations)
      ..addColumns(<Expression<Object>>[outboxOperations.id])
      ..where(
        outboxOperations.ownerId.equals(ownerId) &
            outboxOperations.entityId.equals(transactionId),
      )
      ..limit(1);
    return (await query.getSingleOrNull()) != null;
  }

  Future<OutboxOperation?> _nextEntityOperation(
    String ownerId,
    String transactionId,
  ) {
    final query = select(outboxOperations)
      ..where(
        (row) =>
            row.ownerId.equals(ownerId) & row.entityId.equals(transactionId),
      )
      ..orderBy(<OrderClauseGenerator<OutboxOperations>>[
        (row) => OrderingTerm.asc(row.createdAt),
        (row) => OrderingTerm.asc(row.id),
      ])
      ..limit(1);
    return query.getSingleOrNull();
  }

  Future<CachedAnalyticsDashboard?> readAnalyticsDashboard(
    String ownerId,
    String cacheKey,
  ) {
    final query = select(cachedAnalyticsDashboards)
      ..where(
        (row) => row.ownerId.equals(ownerId) & row.cacheKey.equals(cacheKey),
      );
    return query.getSingleOrNull();
  }

  Future<void> saveAnalyticsDashboard({
    required String ownerId,
    required String cacheKey,
    required String payloadJson,
  }) {
    return into(cachedAnalyticsDashboards).insertOnConflictUpdate(
      CachedAnalyticsDashboardsCompanion.insert(
        ownerId: ownerId,
        cacheKey: cacheKey,
        payloadJson: payloadJson,
        updatedAt: DateTime.now().toUtc(),
      ),
    );
  }

  Future<CachedPlanningSnapshot?> readPlanningSnapshot(String ownerId) {
    final query = select(cachedPlanningSnapshots)
      ..where((row) => row.ownerId.equals(ownerId));
    return query.getSingleOrNull();
  }

  Future<void> savePlanningSnapshot({
    required String ownerId,
    required String payloadJson,
  }) {
    return into(cachedPlanningSnapshots).insertOnConflictUpdate(
      CachedPlanningSnapshotsCompanion.insert(
        ownerId: ownerId,
        payloadJson: payloadJson,
        updatedAt: DateTime.now().toUtc(),
      ),
    );
  }

  Future<void> clearOwnerData(String ownerId) {
    return transaction(() async {
      await (delete(
        cachedPlanningSnapshots,
      )..where((row) => row.ownerId.equals(ownerId))).go();
      await (delete(
        cachedAnalyticsDashboards,
      )..where((row) => row.ownerId.equals(ownerId))).go();
      await (delete(
        outboxOperations,
      )..where((row) => row.ownerId.equals(ownerId))).go();
      await (delete(
        cachedTransactionTags,
      )..where((row) => row.ownerId.equals(ownerId))).go();
      await (delete(
        cachedTransactions,
      )..where((row) => row.ownerId.equals(ownerId))).go();
      await (delete(
        cachedCategories,
      )..where((row) => row.ownerId.equals(ownerId))).go();
      await (delete(
        cachedTags,
      )..where((row) => row.ownerId.equals(ownerId))).go();
      await (delete(
        cachedAccounts,
      )..where((row) => row.ownerId.equals(ownerId))).go();
      await (delete(
        cachedTransactionItems,
      )..where((row) => row.ownerId.equals(ownerId))).go();
      await (delete(
        cachedMerchants,
      )..where((row) => row.ownerId.equals(ownerId))).go();
      await (delete(
        cachedProducts,
      )..where((row) => row.ownerId.equals(ownerId))).go();
    });
  }
}
