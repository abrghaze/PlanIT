import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:planit_mobile/core/auth/application/auth_controller.dart';
import 'package:planit_mobile/core/errors/app_exception.dart';
import 'package:planit_mobile/features/financial_operations/application/financial_operation_state.dart';
import 'package:planit_mobile/features/financial_operations/application/providers.dart';
import 'package:planit_mobile/features/financial_operations/domain/financial_operation.dart';
import 'package:planit_mobile/features/transactions/application/providers.dart';
import 'package:planit_mobile/features/transactions/application/transaction_controller.dart';
import 'package:planit_mobile/features/transactions/data/transactions_repository.dart';
import 'package:planit_mobile/features/transactions/domain/outbox_operation.dart';
import 'package:uuid/uuid.dart';

final NotifierProvider<FinancialOperationController, FinancialOperationState>
financialOperationControllerProvider =
    NotifierProvider<FinancialOperationController, FinancialOperationState>(
      FinancialOperationController.new,
    );

final class FinancialOperationController
    extends Notifier<FinancialOperationState> {
  @override
  FinancialOperationState build() => const FinancialOperationState.idle();

  Future<bool> previewTransfer(TransferPreviewRequest request) async {
    state = state.copyWith(
      busy: true,
      clearPreviews: true,
      clearError: true,
      clearNotice: true,
    );
    try {
      final session = await ref
          .read(authControllerProvider.notifier)
          .requireFreshSession();
      final preview = await ref
          .read(financialOperationsRepositoryProvider)
          .previewTransfer(accessToken: session.accessToken, request: request);
      state = state.copyWith(busy: false, transferPreview: preview);
      return true;
    } on AppException catch (error) {
      state = state.copyWith(busy: false, errorMessage: error.message);
      return false;
    } on Object {
      state = state.copyWith(
        busy: false,
        errorMessage: 'PlanIT could not prepare this transfer.',
      );
      return false;
    }
  }

  Future<bool> queueTransfer({
    required TransferPreviewRequest request,
    required String? note,
  }) async {
    final preview = state.transferPreview;
    final session = ref.read(authControllerProvider).session;
    if (preview == null || session == null) {
      state = state.copyWith(errorMessage: 'Preview the transfer again.');
      return false;
    }
    state = state.copyWith(busy: true, clearError: true, clearNotice: true);
    try {
      final operationId = const Uuid().v4();
      await ref
          .read(financialOperationsRepositoryProvider)
          .queueTransfer(
            ownerId: session.user.id,
            operationId: operationId,
            transferId: const Uuid().v4(),
            sourceTransactionId: const Uuid().v4(),
            destinationTransactionId: const Uuid().v4(),
            feeTransactionId: request.fee == null ? null : const Uuid().v4(),
            request: request,
            preview: preview,
            note: _optionalText(note),
          );
      state = state.copyWith(
        busy: false,
        clearPreviews: true,
        noticeMessage: 'Transfer queued for authoritative server posting.',
      );
      await ref
          .read(transactionControllerProvider.notifier)
          .refresh(silent: true);
      return true;
    } on Object {
      state = state.copyWith(
        busy: false,
        errorMessage: 'PlanIT could not queue this transfer locally.',
      );
      return false;
    }
  }

  Future<bool> previewReconciliation(
    ReconciliationPreviewRequest request,
  ) async {
    state = state.copyWith(
      busy: true,
      clearPreviews: true,
      clearError: true,
      clearNotice: true,
    );
    try {
      final session = await ref
          .read(authControllerProvider.notifier)
          .requireFreshSession();
      final preview = await ref
          .read(financialOperationsRepositoryProvider)
          .previewReconciliation(
            accessToken: session.accessToken,
            request: request,
          );
      state = state.copyWith(busy: false, reconciliationPreview: preview);
      return true;
    } on AppException catch (error) {
      state = state.copyWith(busy: false, errorMessage: error.message);
      return false;
    } on Object {
      state = state.copyWith(
        busy: false,
        errorMessage: 'PlanIT could not prepare this reconciliation.',
      );
      return false;
    }
  }

  Future<bool> queueReconciliation({
    required ReconciliationPreviewRequest request,
    required String? reason,
  }) async {
    final preview = state.reconciliationPreview;
    final session = ref.read(authControllerProvider).session;
    if (preview == null || session == null) {
      state = state.copyWith(errorMessage: 'Preview the reconciliation again.');
      return false;
    }
    state = state.copyWith(busy: true, clearError: true, clearNotice: true);
    try {
      final operationId = const Uuid().v4();
      await ref
          .read(financialOperationsRepositoryProvider)
          .queueReconciliation(
            ownerId: session.user.id,
            operationId: operationId,
            reconciliationId: const Uuid().v4(),
            adjustmentTransactionId: const Uuid().v4(),
            request: request,
            preview: preview,
            reason: _optionalText(reason),
          );
      state = state.copyWith(
        busy: false,
        clearPreviews: true,
        noticeMessage: 'Reconciliation queued for server posting.',
      );
      await ref
          .read(transactionControllerProvider.notifier)
          .refresh(silent: true);
      return true;
    } on Object {
      state = state.copyWith(
        busy: false,
        errorMessage: 'PlanIT could not queue this reconciliation locally.',
      );
      return false;
    }
  }

  Future<bool> previewReallocation(ReallocationPreviewRequest request) async {
    state = state.copyWith(
      busy: true,
      clearPreviews: true,
      clearError: true,
      clearNotice: true,
    );
    try {
      final session = await ref
          .read(authControllerProvider.notifier)
          .requireFreshSession();
      final preview = await ref
          .read(financialOperationsRepositoryProvider)
          .previewReallocation(
            accessToken: session.accessToken,
            request: request,
          );
      state = state.copyWith(busy: false, reallocationPreview: preview);
      return true;
    } on AppException catch (error) {
      state = state.copyWith(busy: false, errorMessage: error.message);
      return false;
    } on Object {
      state = state.copyWith(
        busy: false,
        errorMessage: 'PlanIT could not prepare this fixed-total reallocation.',
      );
      return false;
    }
  }

  Future<bool> queueReallocation({
    required ReallocationPreviewRequest request,
    required String? note,
  }) async {
    final preview = state.reallocationPreview;
    final session = ref.read(authControllerProvider).session;
    if (preview == null || session == null) {
      state = state.copyWith(errorMessage: 'Preview the reallocation again.');
      return false;
    }
    state = state.copyWith(busy: true, clearError: true, clearNotice: true);
    try {
      final operationId = const Uuid().v4();
      await ref
          .read(financialOperationsRepositoryProvider)
          .queueReallocation(
            ownerId: session.user.id,
            operationId: operationId,
            reallocationId: const Uuid().v4(),
            request: request,
            preview: preview,
            note: _optionalText(note),
          );
      state = state.copyWith(
        busy: false,
        clearPreviews: true,
        noticeMessage: 'Reallocation queued as linked internal transfers.',
      );
      await ref
          .read(transactionControllerProvider.notifier)
          .refresh(silent: true);
      return true;
    } on Object {
      state = state.copyWith(
        busy: false,
        errorMessage: 'PlanIT could not queue this reallocation locally.',
      );
      return false;
    }
  }

  Future<void> retryPending() {
    return ref
        .read(transactionControllerProvider.notifier)
        .refresh(force: true);
  }

  Future<bool> discardPending(PendingOperation operation) async {
    try {
      await ref
          .read(transactionsRepositoryProvider)
          .discardPendingOperation(operation);
      return true;
    } on Object {
      state = state.copyWith(
        errorMessage: 'This pending operation could not be discarded.',
      );
      return false;
    }
  }

  void invalidatePreview() {
    if (state.transferPreview == null &&
        state.reconciliationPreview == null &&
        state.reallocationPreview == null) {
      return;
    }
    state = state.copyWith(clearPreviews: true, clearError: true);
  }

  void reset() {
    state = const FinancialOperationState.idle();
  }

  static String? _optionalText(String? value) {
    final normalized = value?.trim();
    return normalized == null || normalized.isEmpty ? null : normalized;
  }
}
