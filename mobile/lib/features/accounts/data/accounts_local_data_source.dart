import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:planit_mobile/core/database/app_database.dart';
import 'package:planit_mobile/core/money/money.dart';
import 'package:planit_mobile/features/accounts/domain/account.dart';
import 'package:planit_mobile/features/transactions/domain/outbox_operation.dart';

final class AccountsLocalDataSource {
  const AccountsLocalDataSource(this._database);

  final AppDatabase _database;

  Stream<List<Account>> watch(String ownerId) {
    return _database
        .watchAccounts(ownerId)
        .map((rows) => rows.map(_fromRow).toList(growable: false));
  }

  Future<List<Account>> read(String ownerId) async {
    final rows = await _database.readAccounts(ownerId);
    return rows.map(_fromRow).toList(growable: false);
  }

  Future<void> replace(String ownerId, List<Account> accounts) {
    if (accounts.any((account) => account.ownerId != ownerId)) {
      throw ArgumentError.value(
        accounts,
        'accounts',
        'Every cached account must belong to $ownerId.',
      );
    }
    final cachedAt = DateTime.now().toUtc();
    return _database.replaceAccounts(
      ownerId,
      accounts.map((account) => _toCompanion(account, cachedAt)).toList(),
    );
  }

  Future<void> upsert(Account account) {
    return _database.upsertAccount(
      _toCompanion(account, DateTime.now().toUtc()),
    );
  }

  Future<Account> queueCreate({
    required String ownerId,
    required AccountDraft draft,
    required String operationId,
  }) async {
    final now = DateTime.now().toUtc();
    final account = Account(
      id: draft.id,
      ownerId: ownerId,
      name: draft.name,
      type: draft.type,
      currency: draft.openingBalance.currency,
      openingBalance: draft.openingBalance,
      calculatedBalance: draft.openingBalance,
      balanceAsOf: now,
      openedAt: draft.openedAt.toUtc(),
      includeInTotal: draft.includeInTotal,
      allowNegative: draft.allowNegative,
      status: AccountStatus.active,
      sortOrder: draft.sortOrder,
      archivedAt: null,
      closedAt: null,
      version: 1,
      createdAt: now,
      updatedAt: now,
    );
    await _database.transaction(() async {
      await _database.upsertAccount(_toCompanion(account, now));
      await _database.queueOutboxOperation(
        _operation(
          id: operationId,
          ownerId: ownerId,
          entityId: account.id,
          type: OutboxOperationType.accountCreate,
          payload: draft.toJson(),
          now: now,
        ),
      );
    });
    return account;
  }

  Future<Account> queueUpdate({
    required Account current,
    required AccountPatch patch,
    required String operationId,
  }) async {
    final hasPendingUpdate = await _database.hasPendingEntityOperation(
      current.ownerId,
      current.id,
      types: <String>{OutboxOperationType.accountUpdate.storageValue},
    );
    if (hasPendingUpdate) {
      throw StateError(
        'Synchronize the previous account change before editing it again.',
      );
    }
    final now = DateTime.now().toUtc();
    final opening = patch.openingBalance ?? current.openingBalance;
    final calculated = patch.openingBalance == null
        ? current.calculatedBalance
        : current.calculatedBalance - current.openingBalance + opening;
    final status = patch.status ?? current.status;
    final account = Account(
      id: current.id,
      ownerId: current.ownerId,
      name: patch.name ?? current.name,
      type: patch.type ?? current.type,
      currency: opening.currency,
      openingBalance: opening,
      calculatedBalance: calculated,
      balanceAsOf: current.balanceAsOf,
      openedAt: patch.openedAt?.toUtc() ?? current.openedAt,
      includeInTotal: patch.includeInTotal ?? current.includeInTotal,
      allowNegative: patch.allowNegative ?? current.allowNegative,
      status: status,
      sortOrder: patch.sortOrder ?? current.sortOrder,
      archivedAt: status == AccountStatus.archived
          ? current.archivedAt ?? now
          : status == AccountStatus.active
          ? null
          : current.archivedAt,
      closedAt: status == AccountStatus.closed
          ? current.closedAt ?? now
          : status == AccountStatus.active
          ? null
          : current.closedAt,
      version: current.version,
      createdAt: current.createdAt,
      updatedAt: now,
    );
    await _database.transaction(() async {
      await _database.upsertAccount(_toCompanion(account, now));
      await _database.queueOutboxOperation(
        _operation(
          id: operationId,
          ownerId: current.ownerId,
          entityId: current.id,
          type: OutboxOperationType.accountUpdate,
          payload: <String, Object?>{
            ...patch.toJson(),
            '_local_before': _snapshot(current),
          },
          now: now,
        ),
      );
    });
    return account;
  }

  Account _fromRow(CachedAccount row) {
    return Account(
      id: row.id,
      ownerId: row.ownerId,
      name: row.name,
      type: AccountTypeContract.fromApi(row.type),
      currency: row.currency,
      openingBalance: Money.parse(row.openingBalanceAmount, row.currency),
      calculatedBalance: Money.parse(row.calculatedBalanceAmount, row.currency),
      balanceAsOf: row.balanceAsOf.toUtc(),
      openedAt: row.openedAt.toUtc(),
      includeInTotal: row.includeInTotal,
      allowNegative: row.allowNegative,
      status: AccountStatusContract.fromApi(row.status),
      sortOrder: row.sortOrder,
      archivedAt: row.archivedAt?.toUtc(),
      closedAt: row.closedAt?.toUtc(),
      version: row.version,
      createdAt: row.createdAt.toUtc(),
      updatedAt: row.updatedAt.toUtc(),
    );
  }

  CachedAccountsCompanion _toCompanion(Account account, DateTime cachedAt) {
    return CachedAccountsCompanion(
      id: Value(account.id),
      ownerId: Value(account.ownerId),
      name: Value(account.name),
      type: Value(account.type.apiValue),
      currency: Value(account.currency),
      openingBalanceAmount: Value(account.openingBalance.toApiString()),
      calculatedBalanceAmount: Value(account.calculatedBalance.toApiString()),
      balanceAsOf: Value(account.balanceAsOf.toUtc()),
      openedAt: Value(account.openedAt.toUtc()),
      includeInTotal: Value(account.includeInTotal),
      allowNegative: Value(account.allowNegative),
      status: Value(account.status.apiValue),
      sortOrder: Value(account.sortOrder),
      archivedAt: Value(account.archivedAt?.toUtc()),
      closedAt: Value(account.closedAt?.toUtc()),
      version: Value(account.version),
      createdAt: Value(account.createdAt.toUtc()),
      updatedAt: Value(account.updatedAt.toUtc()),
      cachedAt: Value(cachedAt),
    );
  }

  static OutboxOperationsCompanion _operation({
    required String id,
    required String ownerId,
    required String entityId,
    required OutboxOperationType type,
    required Map<String, Object?> payload,
    required DateTime now,
  }) => OutboxOperationsCompanion.insert(
    id: id,
    ownerId: ownerId,
    entityId: entityId,
    type: type.storageValue,
    payloadJson: jsonEncode(payload),
    state: 'PENDING',
    attemptCount: 0,
    nextAttemptAt: now,
    createdAt: now,
    updatedAt: now,
  );

  static Map<String, Object?> _snapshot(Account account) => <String, Object?>{
    'id': account.id,
    'name': account.name,
    'type': account.type.apiValue,
    'currency': account.currency,
    'opening_balance_amount': account.openingBalance.toApiString(),
    'calculated_balance_amount': account.calculatedBalance.toApiString(),
    'balance_as_of': account.balanceAsOf.toUtc().toIso8601String(),
    'opened_at': account.openedAt.toUtc().toIso8601String(),
    'include_in_total': account.includeInTotal,
    'allow_negative': account.allowNegative,
    'status': account.status.apiValue,
    'sort_order': account.sortOrder,
    'archived_at': account.archivedAt?.toUtc().toIso8601String(),
    'closed_at': account.closedAt?.toUtc().toIso8601String(),
    'version': account.version,
    'created_at': account.createdAt.toUtc().toIso8601String(),
    'updated_at': account.updatedAt.toUtc().toIso8601String(),
  };
}
