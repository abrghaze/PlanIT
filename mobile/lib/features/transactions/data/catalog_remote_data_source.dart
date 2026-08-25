import 'package:planit_mobile/features/transactions/domain/catalog.dart';

abstract interface class CatalogRemoteDataSource {
  Future<List<TransactionCategory>> fetchCategories({
    required String ownerId,
    required String accessToken,
  });

  Future<List<TransactionTag>> fetchTags({
    required String ownerId,
    required String accessToken,
  });

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

  Future<TransactionCategory> setCategoryArchived({
    required String ownerId,
    required String accessToken,
    required String operationId,
    required TransactionCategory category,
    required bool archived,
  });

  Future<TransactionTag> setTagArchived({
    required String ownerId,
    required String accessToken,
    required String operationId,
    required TransactionTag tag,
    required bool archived,
  });
}
