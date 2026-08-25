import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:planit_mobile/core/auth/application/auth_controller.dart';
import 'package:planit_mobile/core/errors/app_exception.dart';
import 'package:planit_mobile/features/transactions/application/providers.dart';
import 'package:planit_mobile/features/transactions/application/transaction_action_state.dart';
import 'package:planit_mobile/features/transactions/domain/catalog.dart';

final NotifierProvider<CatalogController, TransactionActionState>
catalogControllerProvider =
    NotifierProvider<CatalogController, TransactionActionState>(
      CatalogController.new,
    );

final class CatalogController extends Notifier<TransactionActionState> {
  @override
  TransactionActionState build() => const TransactionActionState.idle();

  Future<bool> createCategory({
    required CategoryDraft draft,
    required String operationId,
  }) async {
    return _perform((ownerId, token) async {
      await ref
          .read(catalogRepositoryProvider)
          .createCategory(
            ownerId: ownerId,
            accessToken: token,
            operationId: operationId,
            draft: draft,
          );
    });
  }

  Future<bool> createTag({
    required TagDraft draft,
    required String operationId,
  }) async {
    return _perform((ownerId, token) async {
      await ref
          .read(catalogRepositoryProvider)
          .createTag(
            ownerId: ownerId,
            accessToken: token,
            operationId: operationId,
            draft: draft,
          );
    });
  }

  Future<bool> setCategoryArchived(
    TransactionCategory category,
    bool archived,
    String operationId,
  ) async {
    return _perform((ownerId, token) async {
      await ref
          .read(catalogRepositoryProvider)
          .setCategoryArchived(
            ownerId: ownerId,
            accessToken: token,
            operationId: operationId,
            category: category,
            archived: archived,
          );
    });
  }

  Future<bool> setTagArchived(
    TransactionTag tag,
    bool archived,
    String operationId,
  ) async {
    return _perform((ownerId, token) async {
      await ref
          .read(catalogRepositoryProvider)
          .setTagArchived(
            ownerId: ownerId,
            accessToken: token,
            operationId: operationId,
            tag: tag,
            archived: archived,
          );
    });
  }

  Future<bool> _perform(
    Future<void> Function(String ownerId, String token) operation,
  ) async {
    state = state.copyWith(busy: true, clearError: true);
    try {
      final session = await ref
          .read(authControllerProvider.notifier)
          .requireFreshSession();
      await operation(session.user.id, session.accessToken);
      state = state.copyWith(busy: false, clearError: true);
      return true;
    } on AppException catch (error) {
      state = state.copyWith(busy: false, errorMessage: error.message);
      return false;
    } on Object {
      state = state.copyWith(
        busy: false,
        errorMessage: 'PlanIT could not save this catalog entry.',
      );
      return false;
    }
  }
}
