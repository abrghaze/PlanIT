import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:planit_mobile/core/auth/application/auth_controller.dart';
import 'package:planit_mobile/core/errors/app_exception.dart';
import 'package:planit_mobile/core/money/money.dart';
import 'package:planit_mobile/features/debts/application/providers.dart';
import 'package:planit_mobile/features/debts/domain/debt.dart';
import 'package:planit_mobile/features/transactions/application/providers.dart';
import 'package:planit_mobile/features/transactions/application/transaction_controller.dart';
import 'package:planit_mobile/features/transactions/data/transactions_repository.dart';
import 'package:planit_mobile/features/transactions/domain/outbox_operation.dart';
import 'package:uuid/uuid.dart';

final debtControllerProvider =
    NotifierProvider<DebtController, DebtActionState>(DebtController.new);

final class DebtActionState {
  const DebtActionState({this.busy = false, this.error, this.notice});
  final bool busy;
  final String? error;
  final String? notice;
}

final class DebtController extends Notifier<DebtActionState> {
  @override
  DebtActionState build() => const DebtActionState();

  Future<bool> createPerson({required String name, String? contact}) async {
    state = const DebtActionState(busy: true);
    try {
      final session = await ref
          .read(authControllerProvider.notifier)
          .requireFreshSession();
      await ref
          .read(debtsApiProvider)
          .createPerson(
            accessToken: session.accessToken,
            operationId: const Uuid().v4(),
            personId: const Uuid().v4(),
            name: name.trim(),
            contact: _optional(contact),
          );
      ref.invalidate(peopleProvider);
      state = const DebtActionState(notice: 'Person added.');
      return true;
    } on AppException catch (error) {
      state = DebtActionState(error: error.message);
      return false;
    } on Object {
      state = const DebtActionState(error: 'PlanIT could not add this person.');
      return false;
    }
  }

  Future<bool> queueDebt({
    required String personId,
    required DebtOrigin origin,
    required DebtDirection direction,
    required Money amount,
    required String? accountId,
    DateTime? dueDate,
    String? note,
  }) async {
    if (!_positive(amount)) return false;
    final operationId = const Uuid().v4();
    final debtId = const Uuid().v4();
    final cash = origin == DebtOrigin.lendNow || origin == DebtOrigin.borrowNow;
    return _queue(
      operationId: operationId,
      entityId: debtId,
      type: OutboxOperationType.debtCreate,
      payload: <String, Object?>{
        'id': debtId,
        'client_operation_id': operationId,
        'person_id': personId,
        'direction': direction.apiValue,
        'origin_type': origin.apiValue,
        'amount': _money(amount),
        if (dueDate != null) 'due_date': _date(dueDate),
        if (cash) 'account_id': accountId,
        if (cash) 'transaction_id': const Uuid().v4(),
        if (cash) 'occurred_at': DateTime.now().toUtc().toIso8601String(),
        if (_optional(note) != null) 'note': _optional(note),
      },
      notice: 'Debt queued for secure server posting.',
    );
  }

  Future<bool> queuePayment({
    required Debt debt,
    required String accountId,
    required Money amount,
    String? note,
  }) {
    if (!_positive(amount)) return Future<bool>.value(false);
    if (amount.currency != debt.remainingAmount.currency ||
        amount.scaledAmount > debt.remainingAmount.scaledAmount) {
      state = DebtActionState(
        error:
            'Repayment cannot exceed ${debt.remainingAmount.toApiString()} ${debt.remainingAmount.currency}.',
      );
      return Future<bool>.value(false);
    }
    final operationId = const Uuid().v4();
    final paymentId = const Uuid().v4();
    return _queue(
      operationId: operationId,
      entityId: paymentId,
      type: OutboxOperationType.debtPayment,
      payload: <String, Object?>{
        'id': paymentId,
        'client_operation_id': operationId,
        '_debt_id': debt.id,
        'transaction_id': const Uuid().v4(),
        'account_id': accountId,
        'amount': _money(amount),
        'paid_at': DateTime.now().toUtc().toIso8601String(),
        if (_optional(note) != null) 'note': _optional(note),
      },
      notice: 'Repayment queued.',
    );
  }

  Future<bool> queueShare({
    required String transactionId,
    required String personId,
    required Money amount,
    DateTime? dueDate,
    String? note,
  }) {
    if (!_positive(amount)) return Future<bool>.value(false);
    final operationId = const Uuid().v4();
    final shareId = const Uuid().v4();
    return _queue(
      operationId: operationId,
      entityId: shareId,
      type: OutboxOperationType.shareCreate,
      payload: <String, Object?>{
        'id': shareId,
        'debt_id': const Uuid().v4(),
        'client_operation_id': operationId,
        '_transaction_id': transactionId,
        'person_id': personId,
        'amount': _money(amount),
        if (dueDate != null) 'due_date': _date(dueDate),
        if (_optional(note) != null) 'note': _optional(note),
      },
      notice: 'Reimbursement share queued.',
    );
  }

  Future<bool> queueRefund({
    required String transactionId,
    required String accountId,
    required Money amount,
    String? note,
  }) {
    if (!_positive(amount)) return Future<bool>.value(false);
    final operationId = const Uuid().v4();
    final refundId = const Uuid().v4();
    return _queue(
      operationId: operationId,
      entityId: refundId,
      type: OutboxOperationType.refundCreate,
      payload: <String, Object?>{
        'id': refundId,
        'client_operation_id': operationId,
        '_transaction_id': transactionId,
        'account_id': accountId,
        'amount': _money(amount),
        'occurred_at': DateTime.now().toUtc().toIso8601String(),
        if (_optional(note) != null) 'note': _optional(note),
      },
      notice: 'Refund queued.',
    );
  }

  Future<bool> _queue({
    required String operationId,
    required String entityId,
    required OutboxOperationType type,
    required Map<String, Object?> payload,
    required String notice,
  }) async {
    final session = ref.read(authControllerProvider).session;
    if (session == null) return false;
    state = const DebtActionState(busy: true);
    try {
      await ref
          .read(transactionsRepositoryProvider)
          .queueFinancialOperation(
            ownerId: session.user.id,
            operationId: operationId,
            entityId: entityId,
            type: type,
            payload: payload,
          );
      await ref
          .read(transactionControllerProvider.notifier)
          .refresh(force: true, silent: true);
      ref.invalidate(debtsProvider);
      state = DebtActionState(notice: notice);
      return true;
    } on AppException catch (error) {
      state = DebtActionState(error: error.message);
      return false;
    } on Object {
      state = const DebtActionState(
        error: 'PlanIT could not queue this operation.',
      );
      return false;
    }
  }

  void clear() => state = const DebtActionState();
  bool _positive(Money value) {
    if (value.scaledAmount > BigInt.zero) return true;
    state = const DebtActionState(error: 'Amount must be greater than zero.');
    return false;
  }

  static Map<String, Object?> _money(Money value) => <String, Object?>{
    'amount': value.toApiString(),
    'currency': value.currency,
  };
  static String _date(DateTime value) =>
      value.toLocal().toIso8601String().split('T').first;
  static String? _optional(String? value) =>
      value?.trim().isEmpty ?? true ? null : value!.trim();
}
