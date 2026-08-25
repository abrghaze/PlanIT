import 'package:drift/drift.dart';
import 'package:planit_mobile/core/database/app_database.dart';
import 'package:planit_mobile/features/transactions/domain/catalog.dart';

final class CatalogLocalDataSource {
  const CatalogLocalDataSource(this._database);

  final AppDatabase _database;

  Stream<List<TransactionCategory>> watchCategories(String ownerId) {
    return _database
        .watchCategories(ownerId)
        .map((rows) => rows.map(_categoryFromRow).toList(growable: false));
  }

  Stream<List<TransactionTag>> watchTags(String ownerId) {
    return _database
        .watchTags(ownerId)
        .map((rows) => rows.map(_tagFromRow).toList(growable: false));
  }

  Future<void> replaceCategories(
    String ownerId,
    List<TransactionCategory> categories,
  ) {
    _requireOwner(categories.map((value) => value.ownerId), ownerId);
    final now = DateTime.now().toUtc();
    return _database.replaceCategories(
      ownerId,
      categories
          .map((value) => _categoryCompanion(value, now))
          .toList(growable: false),
    );
  }

  Future<void> replaceTags(String ownerId, List<TransactionTag> tags) {
    _requireOwner(tags.map((value) => value.ownerId), ownerId);
    final now = DateTime.now().toUtc();
    return _database.replaceTags(
      ownerId,
      tags.map((value) => _tagCompanion(value, now)).toList(growable: false),
    );
  }

  Future<void> upsertCategory(TransactionCategory category) {
    return _database.upsertCategory(
      _categoryCompanion(category, DateTime.now().toUtc()),
    );
  }

  Future<void> upsertTag(TransactionTag tag) {
    return _database.upsertTag(_tagCompanion(tag, DateTime.now().toUtc()));
  }

  static TransactionCategory _categoryFromRow(CachedCategory row) {
    return TransactionCategory(
      id: row.id,
      ownerId: row.ownerId,
      name: row.name,
      kind: CategoryKindContract.fromApi(row.kind),
      parentId: row.parentId,
      isSeeded: row.isSeeded,
      archivedAt: row.archivedAt?.toUtc(),
      version: row.version,
      createdAt: row.createdAt.toUtc(),
      updatedAt: row.updatedAt.toUtc(),
    );
  }

  static TransactionTag _tagFromRow(CachedTag row) {
    return TransactionTag(
      id: row.id,
      ownerId: row.ownerId,
      name: row.name,
      color: row.color,
      archivedAt: row.archivedAt?.toUtc(),
      version: row.version,
      createdAt: row.createdAt.toUtc(),
      updatedAt: row.updatedAt.toUtc(),
    );
  }

  static CachedCategoriesCompanion _categoryCompanion(
    TransactionCategory value,
    DateTime cachedAt,
  ) {
    return CachedCategoriesCompanion(
      id: Value(value.id),
      ownerId: Value(value.ownerId),
      name: Value(value.name),
      kind: Value(value.kind.apiValue),
      parentId: Value(value.parentId),
      isSeeded: Value(value.isSeeded),
      archivedAt: Value(value.archivedAt),
      version: Value(value.version),
      createdAt: Value(value.createdAt),
      updatedAt: Value(value.updatedAt),
      cachedAt: Value(cachedAt),
    );
  }

  static CachedTagsCompanion _tagCompanion(
    TransactionTag value,
    DateTime cachedAt,
  ) {
    return CachedTagsCompanion(
      id: Value(value.id),
      ownerId: Value(value.ownerId),
      name: Value(value.name),
      color: Value(value.color),
      archivedAt: Value(value.archivedAt),
      version: Value(value.version),
      createdAt: Value(value.createdAt),
      updatedAt: Value(value.updatedAt),
      cachedAt: Value(cachedAt),
    );
  }

  static void _requireOwner(Iterable<String> owners, String ownerId) {
    if (owners.any((value) => value != ownerId)) {
      throw ArgumentError('Cached catalog data belongs to another owner.');
    }
  }
}
