import 'package:planit_mobile/features/transactions/data/catalog_local_data_source.dart';
import 'package:planit_mobile/features/transactions/data/catalog_remote_data_source.dart';
import 'package:planit_mobile/features/transactions/domain/catalog.dart';

abstract interface class CatalogRepository {
  Stream<List<TransactionCategory>> watchCategories(String ownerId);

  Stream<List<TransactionTag>> watchTags(String ownerId);

  Future<void> refresh({required String ownerId, required String accessToken});

  Future<TransactionCategory> createCategory({
    required String ownerId,
    required String accessToken,
    required String operationId,
    required CategoryDraft draft,
  });

  Future<TransactionTag> createTag({
    required String ownerId,
    required String accessToken,
    required String operationId,
    required TagDraft draft,
  });

  Future<void> setCategoryArchived({
    required String ownerId,
    required String accessToken,
    required String operationId,
    required TransactionCategory category,
    required bool archived,
  });

  Future<void> setTagArchived({
    required String ownerId,
    required String accessToken,
    required String operationId,
    required TransactionTag tag,
    required bool archived,
  });
}

final class DefaultCatalogRepository implements CatalogRepository {
  const DefaultCatalogRepository({required this.remote, required this.local});

  final CatalogRemoteDataSource remote;
  final CatalogLocalDataSource local;

  @override
  Stream<List<TransactionCategory>> watchCategories(String ownerId) {
    return local.watchCategories(ownerId);
  }

  @override
  Stream<List<TransactionTag>> watchTags(String ownerId) {
    return local.watchTags(ownerId);
  }

  @override
  Future<void> refresh({
    required String ownerId,
    required String accessToken,
  }) async {
    final results = await Future.wait<Object>(<Future<Object>>[
      remote.fetchCategories(ownerId: ownerId, accessToken: accessToken),
      remote.fetchTags(ownerId: ownerId, accessToken: accessToken),
    ]);
    await local.replaceCategories(
      ownerId,
      results[0] as List<TransactionCategory>,
    );
    await local.replaceTags(ownerId, results[1] as List<TransactionTag>);
  }

  @override
  Future<TransactionCategory> createCategory({
    required String ownerId,
    required String accessToken,
    required String operationId,
    required CategoryDraft draft,
  }) async {
    final value = await remote.createCategory(
      ownerId: ownerId,
      accessToken: accessToken,
      operationId: operationId,
      draft: draft,
    );
    await local.upsertCategory(value);
    return value;
  }

  @override
  Future<TransactionTag> createTag({
    required String ownerId,
    required String accessToken,
    required String operationId,
    required TagDraft draft,
  }) async {
    final value = await remote.createTag(
      ownerId: ownerId,
      accessToken: accessToken,
      operationId: operationId,
      draft: draft,
    );
    await local.upsertTag(value);
    return value;
  }

  @override
  Future<void> setCategoryArchived({
    required String ownerId,
    required String accessToken,
    required String operationId,
    required TransactionCategory category,
    required bool archived,
  }) async {
    final value = await remote.setCategoryArchived(
      ownerId: ownerId,
      accessToken: accessToken,
      operationId: operationId,
      category: category,
      archived: archived,
    );
    await local.upsertCategory(value);
  }

  @override
  Future<void> setTagArchived({
    required String ownerId,
    required String accessToken,
    required String operationId,
    required TransactionTag tag,
    required bool archived,
  }) async {
    final value = await remote.setTagArchived(
      ownerId: ownerId,
      accessToken: accessToken,
      operationId: operationId,
      tag: tag,
      archived: archived,
    );
    await local.upsertTag(value);
  }
}
