import 'package:drift/drift.dart';
import 'package:planit_mobile/core/database/app_database.dart';
import 'package:planit_mobile/core/money/money.dart';
import 'package:planit_mobile/features/accounts/domain/account.dart';

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
}
