import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:planit_mobile/core/auth/application/auth_controller.dart';
import 'package:planit_mobile/core/errors/app_exception.dart';
import 'package:planit_mobile/features/accounts/application/account_action_state.dart';
import 'package:planit_mobile/features/accounts/application/providers.dart';
import 'package:planit_mobile/features/accounts/domain/account.dart';

final NotifierProvider<AccountController, AccountActionState>
accountControllerProvider =
    NotifierProvider<AccountController, AccountActionState>(
      AccountController.new,
    );

final FutureProvider<void> accountBootstrapProvider = FutureProvider<void>((
  ref,
) async {
  final ownerId = ref.watch(
    authControllerProvider.select((state) => state.session?.user.id),
  );
  if (ownerId == null) {
    return;
  }
  await ref.read(accountControllerProvider.notifier).refresh(silent: true);
});

final class AccountController extends Notifier<AccountActionState> {
  @override
  AccountActionState build() => const AccountActionState.idle();

  Future<void> refresh({bool silent = false}) async {
    if (!silent) {
      state = state.copyWith(busy: true, clearError: true);
    }
    try {
      final session = await ref
          .read(authControllerProvider.notifier)
          .requireFreshSession();
      await ref
          .read(accountsRepositoryProvider)
          .refresh(ownerId: session.user.id, accessToken: session.accessToken);
      state = state.copyWith(
        busy: false,
        clearError: true,
        lastSyncedAt: DateTime.now().toUtc(),
      );
    } on AppException catch (error) {
      state = state.copyWith(busy: false, errorMessage: error.message);
    } on Object {
      state = state.copyWith(
        busy: false,
        errorMessage: 'PlanIT could not update the local account cache.',
      );
    }
  }

  Future<bool> create({
    required AccountDraft draft,
    required String idempotencyKey,
  }) async {
    state = state.copyWith(busy: true, clearError: true);
    try {
      final session = await ref
          .read(authControllerProvider.notifier)
          .requireFreshSession();
      await ref
          .read(accountsRepositoryProvider)
          .create(
            ownerId: session.user.id,
            accessToken: session.accessToken,
            idempotencyKey: idempotencyKey,
            draft: draft,
          );
      state = state.copyWith(
        busy: false,
        clearError: true,
        lastSyncedAt: DateTime.now().toUtc(),
      );
      return true;
    } on AppException catch (error) {
      state = state.copyWith(busy: false, errorMessage: error.message);
      return false;
    } on Object {
      state = state.copyWith(
        busy: false,
        errorMessage: 'PlanIT could not save this account locally.',
      );
      return false;
    }
  }

  Future<bool> update({
    required String accountId,
    required AccountPatch patch,
  }) async {
    state = state.copyWith(busy: true, clearError: true);
    try {
      final session = await ref
          .read(authControllerProvider.notifier)
          .requireFreshSession();
      await ref
          .read(accountsRepositoryProvider)
          .update(
            ownerId: session.user.id,
            accessToken: session.accessToken,
            accountId: accountId,
            patch: patch,
          );
      state = state.copyWith(
        busy: false,
        clearError: true,
        lastSyncedAt: DateTime.now().toUtc(),
      );
      return true;
    } on AppException catch (error) {
      state = state.copyWith(busy: false, errorMessage: error.message);
      return false;
    } on Object {
      state = state.copyWith(
        busy: false,
        errorMessage: 'PlanIT could not save this account locally.',
      );
      return false;
    }
  }

  void clearError() => state = state.copyWith(clearError: true);
}
