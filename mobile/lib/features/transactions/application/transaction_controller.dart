import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:planit_mobile/core/auth/application/auth_controller.dart';
import 'package:planit_mobile/core/errors/app_exception.dart';
import 'package:planit_mobile/features/accounts/application/providers.dart';
import 'package:planit_mobile/features/transactions/application/providers.dart';
import 'package:planit_mobile/features/transactions/application/transaction_action_state.dart';
import 'package:planit_mobile/features/transactions/domain/transaction.dart';

final NotifierProvider<TransactionController, TransactionActionState>
transactionControllerProvider =
    NotifierProvider<TransactionController, TransactionActionState>(
      TransactionController.new,
    );

final FutureProvider<void> ledgerBootstrapProvider = FutureProvider<void>((
  ref,
) async {
  final ownerId = ref.watch(
    authControllerProvider.select((state) => state.session?.user.id),
  );
  if (ownerId == null) {
    return;
  }
  await ref.read(transactionControllerProvider.notifier).refresh(silent: true);
});

final class TransactionController extends Notifier<TransactionActionState> {
  @override
  TransactionActionState build() => const TransactionActionState.idle();

  Future<void> refresh({bool silent = false, bool force = false}) async {
    if (!silent) {
      state = state.copyWith(
        syncing: true,
        clearError: true,
        clearNotice: true,
      );
    }
    try {
      final session = await ref
          .read(authControllerProvider.notifier)
          .requireFreshSession();
      final sync = await ref
          .read(transactionsRepositoryProvider)
          .synchronize(
            ownerId: session.user.id,
            accessToken: session.accessToken,
            force: force,
          );
      if (!sync.blocked) {
        await Future.wait<void>(<Future<void>>[
          ref
              .read(transactionsRepositoryProvider)
              .refresh(
                ownerId: session.user.id,
                accessToken: session.accessToken,
              ),
          ref
              .read(catalogRepositoryProvider)
              .refresh(
                ownerId: session.user.id,
                accessToken: session.accessToken,
              ),
          ref
              .read(accountsRepositoryProvider)
              .refresh(
                ownerId: session.user.id,
                accessToken: session.accessToken,
              ),
        ]);
      }
      state = state.copyWith(
        syncing: false,
        clearError: true,
        noticeMessage: sync.message,
        clearNotice: sync.message == null,
        lastSyncedAt: sync.blocked ? null : DateTime.now().toUtc(),
      );
    } on AppException catch (error) {
      state = state.copyWith(syncing: false, errorMessage: error.message);
    } on Object {
      state = state.copyWith(
        syncing: false,
        errorMessage: 'PlanIT could not refresh transaction activity.',
      );
    }
  }

  Future<bool> create({
    required TransactionDraft draft,
    required bool postAfterCreate,
    required String? postOperationId,
  }) async {
    final session = ref.read(authControllerProvider).session;
    if (session == null) {
      state = state.copyWith(errorMessage: 'Sign in to record a transaction.');
      return false;
    }
    state = state.copyWith(busy: true, clearError: true, clearNotice: true);
    try {
      await ref
          .read(transactionsRepositoryProvider)
          .queueCreate(
            ownerId: session.user.id,
            draft: draft,
            postAfterCreate: postAfterCreate,
            postOperationId: postOperationId,
          );
      state = state.copyWith(
        busy: false,
        noticeMessage: 'Saved locally. Synchronization is pending.',
      );
      await refresh(silent: true);
      return true;
    } on Object {
      state = state.copyWith(
        busy: false,
        errorMessage: 'PlanIT could not save this transaction locally.',
      );
      return false;
    }
  }

  Future<bool> update({
    required LedgerTransaction current,
    required TransactionEdit edit,
    required String operationId,
  }) async {
    state = state.copyWith(busy: true, clearError: true, clearNotice: true);
    try {
      await ref
          .read(transactionsRepositoryProvider)
          .queueUpdate(current: current, edit: edit, operationId: operationId);
      state = state.copyWith(
        busy: false,
        noticeMessage: 'Draft update queued.',
      );
      await refresh(silent: true);
      return true;
    } on Object {
      state = state.copyWith(
        busy: false,
        errorMessage: 'Only a synchronized draft can be edited.',
      );
      return false;
    }
  }

  Future<bool> post({
    required LedgerTransaction current,
    required String operationId,
  }) async {
    state = state.copyWith(busy: true, clearError: true, clearNotice: true);
    try {
      await ref
          .read(transactionsRepositoryProvider)
          .queuePost(current: current, operationId: operationId);
      state = state.copyWith(busy: false, noticeMessage: 'Posting queued.');
      await refresh(silent: true);
      return true;
    } on Object {
      state = state.copyWith(
        busy: false,
        errorMessage: 'Only a synchronized draft can be posted.',
      );
      return false;
    }
  }

  Future<bool> reverse({
    required LedgerTransaction current,
    required TransactionReversalDraft reversal,
  }) async {
    state = state.copyWith(busy: true, clearError: true, clearNotice: true);
    try {
      await ref
          .read(transactionsRepositoryProvider)
          .queueReversal(current: current, reversal: reversal);
      state = state.copyWith(busy: false, noticeMessage: 'Reversal queued.');
      await refresh(silent: true);
      return true;
    } on Object {
      state = state.copyWith(
        busy: false,
        errorMessage: 'Only a synchronized posted transaction can be reversed.',
      );
      return false;
    }
  }

  Future<bool> discardConflict(LedgerTransaction transaction) async {
    state = state.copyWith(busy: true, clearError: true, clearNotice: true);
    try {
      await ref
          .read(transactionsRepositoryProvider)
          .discardPending(transaction);
      state = state.copyWith(
        busy: false,
        noticeMessage: 'Local conflict discarded. Reloading server state.',
      );
      await refresh(silent: true, force: true);
      return true;
    } on Object {
      state = state.copyWith(
        busy: false,
        errorMessage: 'Only a conflicted local operation can be discarded.',
      );
      return false;
    }
  }

  void clearMessages() {
    state = state.copyWith(clearError: true, clearNotice: true);
  }
}
